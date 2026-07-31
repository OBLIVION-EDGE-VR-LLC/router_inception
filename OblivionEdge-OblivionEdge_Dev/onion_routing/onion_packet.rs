// Onion Packet Structure
// Defines the packet format for onion routing
// Copyright © OBLIVION EDGE LLC, 2026. All rights reserved.

use std::net::SocketAddr;
use anyhow::{Result, Context};
use serde::{Deserialize, Serialize};

/// A single hop in the onion route
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RouteHop {
    /// Identifier for this hop
    pub hop_id: String,
    /// Network address of this hop
    pub address: SocketAddr,
    /// Public key for this hop (for key exchange)
    pub public_key: Vec<u8>,
}

/// Header for onion packets
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OnionHeader {
    /// Version of the onion routing protocol
    pub version: u8,
    /// Total length of the packet
    pub length: u32,
    /// Number of hops remaining
    pub hops_remaining: u8,
    /// Circuit ID for this packet stream
    pub circuit_id: u32,
    /// Packet sequence number
    pub sequence: u32,
    /// Flags for packet handling
    pub flags: OnionFlags,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OnionFlags {
    /// Is this the last packet in a stream?
    pub is_last: bool,
    /// Is this a control packet?
    pub is_control: bool,
    /// Should this packet be fragmented?
    pub allow_fragmentation: bool,
    /// Priority level (0=low, 255=high)
    pub priority: u8,
}

impl Default for OnionFlags {
    fn default() -> Self {
        Self {
            is_last: false,
            is_control: false,
            allow_fragmentation: true,
            priority: 128, // Medium priority
        }
    }
}

/// Complete onion packet structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OnionPacket {
    /// Packet header
    pub header: OnionHeader,
    /// Destination address (next hop)
    pub destination: SocketAddr,
    /// Encrypted payload containing layers
    pub payload: Vec<u8>,
}

impl OnionPacket {
    /// Create a new onion packet
    pub fn new(destination: SocketAddr, payload: Vec<u8>) -> Self {
        let header = OnionHeader {
            version: 1,
            length: (std::mem::size_of::<OnionHeader>() + payload.len()) as u32,
            hops_remaining: 0, // Will be set by the client
            circuit_id: 0, // Will be set by the client
            sequence: 0, // Will be set by the client
            flags: OnionFlags::default(),
        };

        Self {
            header,
            destination,
            payload,
        }
    }

    /// Create a new onion packet with custom header
    pub fn new_with_header(header: OnionHeader, destination: SocketAddr, payload: Vec<u8>) -> Self {
        Self {
            header,
            destination,
            payload,
        }
    }

    /// Convert packet to bytes for transmission
    pub fn to_bytes(&self) -> Result<Vec<u8>> {
        bincode::serialize(self).context("Failed to serialize onion packet")
    }

    /// Create packet from bytes
    pub fn from_bytes(data: &[u8]) -> Result<Self> {
        bincode::deserialize(data).context("Failed to deserialize onion packet")
    }

    /// Get the total packet size in bytes
    pub fn size(&self) -> usize {
        self.header.length as usize
    }

    /// Check if this packet has reached its destination
    pub fn is_final_destination(&self) -> bool {
        self.header.hops_remaining == 0
    }

    /// Decrement hops remaining (called at each hop)
    pub fn decrement_hops(&mut self) {
        if self.header.hops_remaining > 0 {
            self.header.hops_remaining -= 1;
        }
    }

    /// Set circuit ID
    pub fn set_circuit_id(&mut self, circuit_id: u32) {
        self.header.circuit_id = circuit_id;
    }

    /// Set sequence number
    pub fn set_sequence(&mut self, sequence: u32) {
        self.header.sequence = sequence;
    }

    /// Set number of hops
    pub fn set_hops(&mut self, hops: u8) {
        self.header.hops_remaining = hops;
    }

    /// Mark as control packet
    pub fn set_control(&mut self, is_control: bool) {
        self.header.flags.is_control = is_control;
    }

    /// Mark as final packet in stream
    pub fn set_final(&mut self, is_final: bool) {
        self.header.flags.is_last = is_final;
    }

    /// Set priority level
    pub fn set_priority(&mut self, priority: u8) {
        self.header.flags.priority = priority;
    }

    /// Get packet header
    pub fn get_header(&self) -> &OnionHeader {
        &self.header
    }

    /// Get payload
    pub fn get_payload(&self) -> &[u8] {
        &self.payload
    }

    /// Update payload (for layer peeling)
    pub fn update_payload(&mut self, new_payload: Vec<u8>) {
        self.payload = new_payload;
        self.header.length = (std::mem::size_of::<OnionHeader>() + self.payload.len()) as u32;
    }
}

/// Builder pattern for creating onion packets
pub struct OnionPacketBuilder {
    destination: SocketAddr,
    payload: Vec<u8>,
    circuit_id: u32,
    sequence: u32,
    hops: u8,
    flags: OnionFlags,
}

impl OnionPacketBuilder {
    /// Start building a new onion packet
    pub fn new(destination: SocketAddr) -> Self {
        Self {
            destination,
            payload: Vec::new(),
            circuit_id: 0,
            sequence: 0,
            hops: 0,
            flags: OnionFlags::default(),
        }
    }

    /// Set payload
    pub fn payload(mut self, payload: Vec<u8>) -> Self {
        self.payload = payload;
        self
    }

    /// Set circuit ID
    pub fn circuit_id(mut self, circuit_id: u32) -> Self {
        self.circuit_id = circuit_id;
        self
    }

    /// Set sequence number
    pub fn sequence(mut self, sequence: u32) -> Self {
        self.sequence = sequence;
        self
    }

    /// Set number of hops
    pub fn hops(mut self, hops: u8) -> Self {
        self.hops = hops;
        self
    }

    /// Set as control packet
    pub fn control(mut self, is_control: bool) -> Self {
        self.flags.is_control = is_control;
        self
    }

    /// Set as final packet
    pub fn final_packet(mut self, is_final: bool) -> Self {
        self.flags.is_last = is_final;
        self
    }

    /// Set priority
    pub fn priority(mut self, priority: u8) -> Self {
        self.flags.priority = priority;
        self
    }

    /// Build the onion packet
    pub fn build(self) -> OnionPacket {
        let header = OnionHeader {
            version: 1,
            length: (std::mem::size_of::<OnionHeader>() + self.payload.len()) as u32,
            hops_remaining: self.hops,
            circuit_id: self.circuit_id,
            sequence: self.sequence,
            flags: self.flags,
        };

        OnionPacket {
            header,
            destination: self.destination,
            payload: self.payload,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_route_hop_creation() {
        let hop = RouteHop {
            hop_id: "test_hop".to_string(),
            address: "192.168.1.1:8080".parse().unwrap(),
            public_key: vec![1, 2, 3, 4],
        };

        assert_eq!(hop.hop_id, "test_hop");
        assert_eq!(hop.address.port(), 8080);
        assert_eq!(hop.public_key, vec![1, 2, 3, 4]);
    }

    #[test]
    fn test_onion_packet_creation() {
        let destination = "127.0.0.1:9001".parse().unwrap();
        let payload = vec![1, 2, 3, 4, 5];
        let packet = OnionPacket::new(destination, payload.clone());

        assert_eq!(packet.destination, destination);
        assert_eq!(packet.payload, payload);
        assert_eq!(packet.header.version, 1);
        assert!(packet.header.length > 0);
    }

    #[test]
    fn test_onion_packet_builder() {
        let destination = "127.0.0.1:9001".parse().unwrap();
        let payload = vec![1, 2, 3, 4, 5];

        let packet = OnionPacketBuilder::new(destination)
            .payload(payload.clone())
            .circuit_id(12345)
            .sequence(1)
            .hops(4)
            .control(false)
            .final_packet(true)
            .priority(200)
            .build();

        assert_eq!(packet.destination, destination);
        assert_eq!(packet.payload, payload);
        assert_eq!(packet.header.circuit_id, 12345);
        assert_eq!(packet.header.sequence, 1);
        assert_eq!(packet.header.hops_remaining, 4);
        assert!(!packet.header.flags.is_control);
        assert!(packet.header.flags.is_last);
        assert_eq!(packet.header.flags.priority, 200);
    }

    #[test]
    fn test_packet_serialization() {
        let destination = "127.0.0.1:9001".parse().unwrap();
        let payload = vec![1, 2, 3, 4, 5];
        let packet = OnionPacket::new(destination, payload);

        let bytes = packet.to_bytes().unwrap();
        assert!(!bytes.is_empty());

        let deserialized = OnionPacket::from_bytes(&bytes).unwrap();
        assert_eq!(deserialized.destination, packet.destination);
        assert_eq!(deserialized.payload, packet.payload);
        assert_eq!(deserialized.header.version, packet.header.version);
    }

    #[test]
    fn test_packet_manipulation() {
        let destination = "127.0.0.1:9001".parse().unwrap();
        let payload = vec![1, 2, 3, 4, 5];
        let mut packet = OnionPacket::new(destination, payload);

        packet.set_circuit_id(999);
        packet.set_sequence(42);
        packet.set_hops(3);
        packet.set_control(true);
        packet.set_final(true);
        packet.set_priority(255);

        assert_eq!(packet.header.circuit_id, 999);
        assert_eq!(packet.header.sequence, 42);
        assert_eq!(packet.header.hops_remaining, 3);
        assert!(packet.header.flags.is_control);
        assert!(packet.header.flags.is_last);
        assert_eq!(packet.header.flags.priority, 255);

        // Test hop decrementing
        packet.decrement_hops();
        assert_eq!(packet.header.hops_remaining, 2);

        packet.decrement_hops();
        assert_eq!(packet.header.hops_remaining, 1);

        packet.decrement_hops();
        assert_eq!(packet.header.hops_remaining, 0);
        assert!(packet.is_final_destination());

        // Should not go below 0
        packet.decrement_hops();
        assert_eq!(packet.header.hops_remaining, 0);
    }

    #[test]
    fn test_payload_update() {
        let destination = "127.0.0.1:9001".parse().unwrap();
        let initial_payload = vec![1, 2, 3];
        let mut packet = OnionPacket::new(destination, initial_payload);

        let initial_length = packet.header.length;

        let new_payload = vec![4, 5, 6, 7, 8];
        packet.update_payload(new_payload.clone());

        assert_eq!(packet.payload, new_payload);
        assert_ne!(packet.header.length, initial_length);
        assert_eq!(packet.header.length as usize,
                   std::mem::size_of::<OnionHeader>() + new_payload.len());
    }

    #[test]
    fn test_onion_flags() {
        let mut flags = OnionFlags::default();

        assert!(!flags.is_last);
        assert!(!flags.is_control);
        assert!(flags.allow_fragmentation);
        assert_eq!(flags.priority, 128);

        flags.is_last = true;
        flags.is_control = true;
        flags.allow_fragmentation = false;
        flags.priority = 255;

        assert!(flags.is_last);
        assert!(flags.is_control);
        assert!(!flags.allow_fragmentation);
        assert_eq!(flags.priority, 255);
    }
}