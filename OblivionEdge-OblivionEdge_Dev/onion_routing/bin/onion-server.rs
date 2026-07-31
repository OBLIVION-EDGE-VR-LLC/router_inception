// Onion Routing Server Binary
// Server component that runs on each hop to handle onion packet forwarding
// Copyright © OBLIVION EDGE LLC, 2026. All rights reserved.

use onion_routing::OnionRoutingServer;
use std::{env, process};
use tracing::{info, error};

#[tokio::main]
async fn main() {
    // Initialize logging
    if let Err(e) = onion_routing::init() {
        eprintln!("Failed to initialize logging: {}", e);
        process::exit(1);
    }

    info!("OblivionEdge Onion Routing Server v{}", onion_routing::VERSION);

    // Parse command line arguments
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("Usage: {} <hop-id> <listen-address>", args[0]);
        eprintln!("Example: {} russia 172.20.0.20:9001", args[0]);
        process::exit(1);
    }

    let hop_id = args[1].clone();
    let listen_address = match args[2].parse() {
        Ok(addr) => addr,
        Err(e) => {
            error!("Invalid listen address '{}': {}", args[2], e);
            process::exit(1);
        }
    };

    // Generate a mock private key for this hop
    let private_key = generate_mock_private_key(&hop_id);

    info!("Starting onion routing server for hop: {}", hop_id);
    info!("Listening on: {}", listen_address);

    // Create and start onion server
    match OnionRoutingServer::new(hop_id.clone(), listen_address, private_key) {
        Ok(mut server) => {
            info!("Server configured successfully");

            match server.start().await {
                Ok(_) => {
                    info!("Onion routing server started for hop {}", hop_id);
                    // Server runs indefinitely
                }
                Err(e) => {
                    error!("Failed to start onion server: {}", e);
                    process::exit(1);
                }
            }
        }
        Err(e) => {
            error!("Failed to create onion server: {}", e);
            process::exit(1);
        }
    }
}

fn generate_mock_private_key(hop_id: &str) -> Vec<u8> {
    // In a real implementation, this would load the private key from a secure location
    // For demo purposes, generate a deterministic key based on hop ID
    let mut key = vec![0u8; 32];
    let hop_bytes = hop_id.as_bytes();

    for (i, &byte) in hop_bytes.iter().enumerate() {
        if i < 32 {
            key[i] = byte.wrapping_add(128); // Different from public key generation
        }
    }

    // Fill remaining bytes with a different pattern
    for i in hop_bytes.len()..32 {
        key[i] = (i.wrapping_mul(3).wrapping_add(hop_bytes.len())) as u8;
    }

    key
}