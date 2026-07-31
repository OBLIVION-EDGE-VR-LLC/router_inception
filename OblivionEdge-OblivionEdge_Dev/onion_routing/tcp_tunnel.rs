// UDP-over-TCP Tunnel Implementation
// Encapsulates WireGuard UDP packets into TCP for onion routing
// Copyright © OBLIVION EDGE LLC, 2026. All rights reserved.

use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use anyhow::{Result, Context};
use tokio::net::{TcpListener, TcpStream, UdpSocket};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::sync::mpsc;
use tracing::{info, debug, error};
use serde::{Deserialize, Serialize};

/// UDP packet wrapped for TCP transmission
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TcpWrappedUdpPacket {
    /// Original UDP source address
    pub udp_source: SocketAddr,
    /// Original UDP destination address
    pub udp_dest: SocketAddr,
    /// UDP payload
    pub payload: Vec<u8>,
    /// Timestamp for packet ordering
    pub timestamp: u64,
    /// Packet sequence number
    pub sequence: u32,
}

impl TcpWrappedUdpPacket {
    /// Create new wrapped UDP packet
    pub fn new(udp_source: SocketAddr, udp_dest: SocketAddr, payload: Vec<u8>) -> Self {
        use std::time::{SystemTime, UNIX_EPOCH};

        Self {
            udp_source,
            udp_dest,
            payload,
            timestamp: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as u64,
            sequence: 0, // Will be set by sender
        }
    }

    /// Serialize to bytes for TCP transmission
    pub fn to_bytes(&self) -> Result<Vec<u8>> {
        bincode::serialize(self).context("Failed to serialize wrapped UDP packet")
    }

    /// Deserialize from TCP bytes
    pub fn from_bytes(data: &[u8]) -> Result<Self> {
        bincode::deserialize(data).context("Failed to deserialize wrapped UDP packet")
    }

    /// Get payload size
    pub fn payload_size(&self) -> usize {
        self.payload.len()
    }
}

/// UDP-to-TCP tunnel that captures UDP packets and sends them over TCP
pub struct UdpToTcpTunnel {
    /// Local UDP socket for WireGuard
    udp_socket: Arc<UdpSocket>,
    /// TCP stream for onion routing
    tcp_stream: Option<TcpStream>,
    /// Local UDP port
    udp_port: u16,
    /// TCP port for onion routing
    tcp_port: u16,
    /// Packet sequence counter
    sequence_counter: Arc<Mutex<u32>>,
    /// Statistics
    stats: Arc<Mutex<TunnelStats>>,
}

#[derive(Debug, Default, Clone)]
pub struct TunnelStats {
    pub udp_packets_received: u64,
    pub tcp_packets_sent: u64,
    pub bytes_tunneled: u64,
    pub errors: u64,
}

impl UdpToTcpTunnel {
    /// Create new UDP-to-TCP tunnel
    pub async fn new(udp_port: u16, tcp_port: u16) -> Result<Self> {
        let udp_socket = UdpSocket::bind(format!("127.0.0.1:{}", udp_port))
            .await
            .context("Failed to bind UDP socket")?;

        info!("UDP-to-TCP tunnel listening on UDP port {}", udp_port);

        Ok(Self {
            udp_socket: Arc::new(udp_socket),
            tcp_stream: None,
            udp_port,
            tcp_port,
            sequence_counter: Arc::new(Mutex::new(0)),
            stats: Arc::new(Mutex::new(TunnelStats::default())),
        })
    }

    /// Connect to TCP endpoint for onion routing
    pub async fn connect_tcp(&mut self, tcp_endpoint: SocketAddr) -> Result<()> {
        let stream = TcpStream::connect(tcp_endpoint)
            .await
            .context("Failed to connect to TCP endpoint")?;

        self.tcp_stream = Some(stream);
        info!("Connected to TCP endpoint: {}", tcp_endpoint);
        Ok(())
    }

    /// Start the UDP-to-TCP tunnel
    pub async fn start(&mut self) -> Result<()> {
        info!("Starting UDP-to-TCP tunnel");

        let udp_socket = self.udp_socket.clone();
        let sequence_counter = self.sequence_counter.clone();
        let stats = self.stats.clone();

        // Channel for UDP packets
        let (udp_tx, mut udp_rx) = mpsc::channel::<TcpWrappedUdpPacket>(1000);

        // Spawn UDP receiver task
        let udp_task = {
            let udp_tx = udp_tx.clone();
            tokio::spawn(async move {
                let mut buffer = vec![0u8; 2048]; // Standard MTU size

                loop {
                    match udp_socket.recv_from(&mut buffer).await {
                        Ok((n, addr)) => {
                            debug!("Received {} bytes from UDP {}", n, addr);

                            // Create wrapped packet
                            let wrapped_packet = TcpWrappedUdpPacket::new(
                                addr,
                                format!("127.0.0.1:{}", 51820).parse().unwrap(), // WireGuard dest
                                buffer[..n].to_vec(),
                            );

                            // Update sequence number
                            let sequence = {
                                let mut seq = sequence_counter.lock().unwrap();
                                let current = *seq;
                                *seq += 1;
                                current
                            };
                            let mut packet_with_seq = wrapped_packet;
                            packet_with_seq.sequence = sequence;

                            // Update stats
                            {
                                let mut stats_guard = stats.lock().unwrap();
                                stats_guard.udp_packets_received += 1;
                                stats_guard.bytes_tunneled += n as u64;
                            }

                            if let Err(e) = udp_tx.send(packet_with_seq).await {
                                error!("Failed to send UDP packet to channel: {}", e);
                                stats.lock().unwrap().errors += 1;
                            }
                        }
                        Err(e) => {
                            error!("UDP receive error: {}", e);
                            stats.lock().unwrap().errors += 1;
                        }
                    }
                }
            })
        };

        // Main tunnel loop - forward UDP packets over TCP
        if let Some(ref mut tcp_stream) = self.tcp_stream {
            let stats = self.stats.clone();
            while let Some(wrapped_packet) = udp_rx.recv().await {
                match Self::send_tcp_packet_internal_static(tcp_stream, &wrapped_packet).await {
                    Ok(_) => {
                        debug!("Forwarded UDP packet {} over TCP", wrapped_packet.sequence);
                        stats.lock().unwrap().tcp_packets_sent += 1;
                    }
                    Err(e) => {
                        error!("Failed to forward packet over TCP: {}", e);
                        stats.lock().unwrap().errors += 1;
                    }
                }
            }
        }

        udp_task.abort();
        Ok(())
    }

    /// Send a packet over TCP (public interface)
    pub async fn send_tcp_packet(&mut self, data: &[u8]) -> Result<()> {
        // Create a simple wrapped packet for raw data
        let wrapped_packet = TcpWrappedUdpPacket::new(
            "127.0.0.1:0".parse().unwrap(),
            "127.0.0.1:0".parse().unwrap(),
            data.to_vec(),
        );

        if let Some(ref mut tcp_stream) = self.tcp_stream {
            Self::send_tcp_packet_internal_static(tcp_stream, &wrapped_packet).await
        } else {
            Err(anyhow::anyhow!("TCP connection not established"))
        }
    }

    /// Internal method to send wrapped packet over TCP
    async fn send_tcp_packet_internal(
        &self,
        tcp_stream: &mut TcpStream,
        wrapped_packet: &TcpWrappedUdpPacket,
    ) -> Result<()> {
        Self::send_tcp_packet_internal_static(tcp_stream, wrapped_packet).await
    }

    /// Static version of send_tcp_packet_internal for use in async contexts
    async fn send_tcp_packet_internal_static(
        tcp_stream: &mut TcpStream,
        wrapped_packet: &TcpWrappedUdpPacket,
    ) -> Result<()> {
        let serialized = wrapped_packet.to_bytes()?;

        // Send packet length first (4 bytes, big-endian)
        let length = serialized.len() as u32;
        tcp_stream.write_all(&length.to_be_bytes()).await?;

        // Send packet data
        tcp_stream.write_all(&serialized).await?;
        tcp_stream.flush().await?;

        Ok(())
    }

    /// Get tunnel statistics
    pub fn get_stats(&self) -> TunnelStats {
        self.stats.lock().unwrap().clone()
    }
}

/// TCP-to-UDP tunnel that receives TCP packets and forwards to local UDP
pub struct TcpToUdpTunnel {
    /// TCP listener for incoming connections
    tcp_listener: TcpListener,
    /// Local UDP socket to forward to
    udp_socket: Arc<UdpSocket>,
    /// Target UDP address (usually local WireGuard)
    udp_target: SocketAddr,
    /// Statistics
    stats: Arc<Mutex<TunnelStats>>,
}

impl TcpToUdpTunnel {
    /// Create new TCP-to-UDP tunnel
    pub async fn new(tcp_port: u16, udp_target_port: u16) -> Result<Self> {
        let tcp_listener = TcpListener::bind(format!("127.0.0.1:{}", tcp_port))
            .await
            .context("Failed to bind TCP listener")?;

        let udp_socket = UdpSocket::bind("127.0.0.1:0")
            .await
            .context("Failed to bind UDP socket for forwarding")?;

        let udp_target: SocketAddr = format!("127.0.0.1:{}", udp_target_port)
            .parse()
            .context("Invalid UDP target address")?;

        info!("TCP-to-UDP tunnel listening on TCP port {}, forwarding to UDP {}",
              tcp_port, udp_target);

        Ok(Self {
            tcp_listener,
            udp_socket: Arc::new(udp_socket),
            udp_target,
            stats: Arc::new(Mutex::new(TunnelStats::default())),
        })
    }

    /// Start the TCP-to-UDP tunnel
    pub async fn start(&self) -> Result<()> {
        info!("Starting TCP-to-UDP tunnel");

        loop {
            let (tcp_stream, addr) = self.tcp_listener.accept().await?;
            info!("Accepted TCP connection from {}", addr);

            let udp_socket = self.udp_socket.clone();
            let udp_target = self.udp_target;
            let stats = self.stats.clone();

            // Handle connection in separate task
            tokio::spawn(async move {
                if let Err(e) = Self::handle_tcp_connection(tcp_stream, udp_socket, udp_target, stats).await {
                    error!("Error handling TCP connection: {}", e);
                }
            });
        }
    }

    /// Handle incoming TCP connection
    async fn handle_tcp_connection(
        mut tcp_stream: TcpStream,
        udp_socket: Arc<UdpSocket>,
        udp_target: SocketAddr,
        stats: Arc<Mutex<TunnelStats>>,
    ) -> Result<()> {
        let mut buffer = vec![0u8; 4096];

        loop {
            // Read packet length (4 bytes)
            let mut length_bytes = [0u8; 4];
            match tcp_stream.read_exact(&mut length_bytes).await {
                Ok(_) => {},
                Err(e) if e.kind() == std::io::ErrorKind::UnexpectedEof => {
                    debug!("TCP connection closed");
                    break;
                }
                Err(e) => return Err(e.into()),
            }

            let packet_length = u32::from_be_bytes(length_bytes) as usize;
            if packet_length > buffer.len() {
                buffer.resize(packet_length, 0);
            }

            // Read packet data
            tcp_stream.read_exact(&mut buffer[..packet_length]).await?;

            // Deserialize wrapped UDP packet
            match TcpWrappedUdpPacket::from_bytes(&buffer[..packet_length]) {
                Ok(wrapped_packet) => {
                    debug!("Received wrapped UDP packet, sequence: {}", wrapped_packet.sequence);

                    // Forward to UDP
                    if let Err(e) = udp_socket.send_to(&wrapped_packet.payload, udp_target).await {
                        error!("Failed to forward to UDP: {}", e);
                        stats.lock().unwrap().errors += 1;
                    } else {
                        debug!("Forwarded packet to UDP {}", udp_target);
                        let mut stats_guard = stats.lock().unwrap();
                        stats_guard.tcp_packets_sent += 1;
                        stats_guard.bytes_tunneled += wrapped_packet.payload.len() as u64;
                    }
                }
                Err(e) => {
                    error!("Failed to deserialize wrapped packet: {}", e);
                    stats.lock().unwrap().errors += 1;
                }
            }
        }

        Ok(())
    }

    /// Get tunnel statistics
    pub fn get_stats(&self) -> TunnelStats {
        self.stats.lock().unwrap().clone()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::time::{sleep, Duration};

    #[test]
    fn test_tcp_wrapped_udp_packet() {
        let source = "192.168.1.1:12345".parse().unwrap();
        let dest = "192.168.1.2:54321".parse().unwrap();
        let payload = vec![1, 2, 3, 4, 5];

        let packet = TcpWrappedUdpPacket::new(source, dest, payload.clone());

        assert_eq!(packet.udp_source, source);
        assert_eq!(packet.udp_dest, dest);
        assert_eq!(packet.payload, payload);
        assert!(packet.timestamp > 0);
        assert_eq!(packet.sequence, 0);
    }

    #[test]
    fn test_packet_serialization() {
        let source = "127.0.0.1:8080".parse().unwrap();
        let dest = "127.0.0.1:9090".parse().unwrap();
        let payload = vec![10, 20, 30, 40];

        let packet = TcpWrappedUdpPacket::new(source, dest, payload);

        let bytes = packet.to_bytes().unwrap();
        assert!(!bytes.is_empty());

        let deserialized = TcpWrappedUdpPacket::from_bytes(&bytes).unwrap();
        assert_eq!(deserialized.udp_source, packet.udp_source);
        assert_eq!(deserialized.udp_dest, packet.udp_dest);
        assert_eq!(deserialized.payload, packet.payload);
    }

    #[tokio::test]
    async fn test_udp_to_tcp_tunnel_creation() {
        let tunnel = UdpToTcpTunnel::new(0, 0).await; // Use port 0 for random assignment
        assert!(tunnel.is_ok());

        let tunnel = tunnel.unwrap();
        assert_eq!(tunnel.sequence_counter.lock().unwrap().clone(), 0);

        let stats = tunnel.get_stats();
        assert_eq!(stats.udp_packets_received, 0);
        assert_eq!(stats.tcp_packets_sent, 0);
    }

    #[tokio::test]
    async fn test_tcp_to_udp_tunnel_creation() {
        let tunnel = TcpToUdpTunnel::new(0, 51820).await; // Use port 0 for random assignment
        assert!(tunnel.is_ok());

        let tunnel = tunnel.unwrap();
        assert_eq!(tunnel.udp_target.port(), 51820);

        let stats = tunnel.get_stats();
        assert_eq!(stats.tcp_packets_sent, 0);
        assert_eq!(stats.bytes_tunneled, 0);
    }

    #[tokio::test]
    async fn test_tunnel_stats() {
        let tunnel = UdpToTcpTunnel::new(0, 0).await.unwrap();

        // Simulate some stats
        {
            let mut stats = tunnel.stats.lock().unwrap();
            stats.udp_packets_received = 100;
            stats.tcp_packets_sent = 95;
            stats.bytes_tunneled = 1000;
            stats.errors = 5;
        }

        let stats = tunnel.get_stats();
        assert_eq!(stats.udp_packets_received, 100);
        assert_eq!(stats.tcp_packets_sent, 95);
        assert_eq!(stats.bytes_tunneled, 1000);
        assert_eq!(stats.errors, 5);
    }

    #[tokio::test]
    async fn test_sequence_counter() {
        let tunnel = UdpToTcpTunnel::new(0, 0).await.unwrap();

        // Test sequence counter increment
        let mut seq = tunnel.sequence_counter.lock().unwrap();
        assert_eq!(*seq, 0);

        *seq += 1;
        assert_eq!(*seq, 1);

        *seq += 1;
        assert_eq!(*seq, 2);
    }
}