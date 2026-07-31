// Onion Routing Client Binary
// Command-line tool for establishing onion circuits with UDP-over-TCP
// Copyright © OBLIVION EDGE LLC, 2026. All rights reserved.

use onion_routing::{OnionRoutingClient, OnionConfig, RouteHop};
use std::process;
use tracing::{info, error};

#[tokio::main]
async fn main() {
    // Initialize logging
    if let Err(e) = onion_routing::init() {
        eprintln!("Failed to initialize logging: {}", e);
        process::exit(1);
    }

    info!("OblivionEdge Onion Routing Client v{}", onion_routing::VERSION);

    // Parse command line arguments (simplified for demo)
    let config = create_default_config();

    // Create and start onion client
    match OnionRoutingClient::new(config) {
        Ok(mut client) => {
            info!("Starting onion routing client...");

            match client.start().await {
                Ok(_) => {
                    info!("Onion client started successfully");
                    info!("Ready to tunnel WireGuard UDP traffic through TCP onion circuit");

                    // Keep the client running
                    info!("Press Ctrl+C to stop");
                    tokio::signal::ctrl_c().await.expect("Failed to listen for ctrl-c");
                    info!("Shutting down onion client...");
                }
                Err(e) => {
                    error!("Failed to start onion client: {}", e);
                    process::exit(1);
                }
            }
        }
        Err(e) => {
            error!("Failed to create onion client: {}", e);
            process::exit(1);
        }
    }
}

fn create_default_config() -> OnionConfig {
    OnionConfig {
        route: vec![
            RouteHop {
                hop_id: "russia".to_string(),
                address: "172.20.0.20:9001".parse().unwrap(),
                public_key: vec![0; 32], // Would be loaded from config file
            },
            RouteHop {
                hop_id: "canada".to_string(),
                address: "172.20.0.30:9001".parse().unwrap(),
                public_key: vec![0; 32],
            },
            RouteHop {
                hop_id: "taiwan".to_string(),
                address: "172.20.0.40:9001".parse().unwrap(),
                public_key: vec![0; 32],
            },
            RouteHop {
                hop_id: "australia".to_string(),
                address: "172.20.0.50:9001".parse().unwrap(),
                public_key: vec![0; 32],
            },
        ],
        local_udp_port: 51820,
        local_tcp_port: 9000,
        max_packet_size: 1500,
    }
}