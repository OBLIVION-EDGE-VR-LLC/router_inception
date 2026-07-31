# Modifiable Cyber Terrain — Geographic Hopping Flow Example

## Detailed Packet Transformation Walkthrough

![Packet Flow Through Hops](../diagrams/mct_packet_flow.png)

*Sequence diagram showing DNS query transformation at each geographic hop, with encryption and re-assignment at each stage.*

## Step-by-Step Example: Client Queries DNS for google.com

### Initial State
- User enters URL: google.com in browser
- OS creates DNS query packet:
  - Source IP: 192.168.1.100 (client's home network)
  - Destination IP: 8.8.8.8 (Google Public DNS)
  - Destination Port: 53 (DNS)
  - Payload: Query for google.com A record

### Step 1: Primary Router (Entry Point)

**Input:** Unencrypted packet from 192.168.1.100

**Processing:**
- ZTNA daemon validates client certificate: ✓ PASS
- Routing policy allows DNS: ✓ PASS
- Record packet source (192.168.1.100)
- Assign tunnel ID: 12345
- Wrap packet in WireGuard encryption (key: wg0-hop1-key-1)
- Determine next hop: Russia

**Output:** WireGuard Packet to Russia Hop
```
WireGuard {
  Encrypted Payload: <original packet>,
  Receiver: 1234567890,
  Counter: 42,
  Datalen: 156 bytes
}
```

### Step 2: Russia Hop (AS12389 ROSTELECOM)

**Input:** WireGuard Packet (encrypted with wg0-hop1-key-1)

**Processing:**
- Decrypt using wg0-hop1-key-1
- Extract original packet: 192.168.1.100 → 8.8.8.8:53
- Assign new source IP from Russian range: 5.101.50.42
- Keep destination unchanged: 8.8.8.8:53
- Log transformation: {from: 192.168.1.100, to: 5.101.50.42, geography: russia}
- Wrap in new WireGuard encryption (key: wg0-hop2-key-1)
- Determine next hop: Canada

**Output:** WireGuard Packet to Canada Hop
```
WireGuard {
  Encrypted Payload: <packet with source IP 5.101.50.42>,
  Receiver: 9876543210,
  Counter: 15,
  Datalen: 156 bytes
}
```

**Internal Log:**
- Russian IP assigned: 5.101.50.42 (Moscow)
- Query destination: 8.8.8.8 (unchanged)
- Next hop: Canada
- Timestamp: 2026-07-27T12:30:45.123Z

### Step 3: Canada Hop (AS812 ROGERS)

**Input:** WireGuard Packet (encrypted with wg0-hop2-key-1)

**Processing:**
- Decrypt using wg0-hop2-key-1
- Extract packet: 5.101.50.42 → 8.8.8.8:53
- Assign new source IP from Canadian range: 174.95.123.56
- Keep destination unchanged: 8.8.8.8:53
- Log transformation: {from: 5.101.50.42, to: 174.95.123.56, geography: canada}
- Wrap in new WireGuard encryption (key: wg0-hop3-key-1)
- Determine next hop: Taiwan

**Output:** WireGuard Packet to Taiwan Hop

**Internal Log:**
- Canadian IP assigned: 174.95.123.56 (Toronto)
- Query destination: 8.8.8.8 (unchanged)
- Next hop: Taiwan
- Timestamp: 2026-07-27T12:30:45.234Z

### Step 4: Taiwan Hop (AS9924 CHUNGHWA)

**Input:** WireGuard Packet (encrypted with wg0-hop3-key-1)

**Processing:**
- Decrypt using wg0-hop3-key-1
- Extract packet: 174.95.123.56 → 8.8.8.8:53
- Assign new source IP from Taiwan range: 1.160.200.10
- Keep destination unchanged: 8.8.8.8:53
- Log transformation: {from: 174.95.123.56, to: 1.160.200.10, geography: taiwan}
- Wrap in new WireGuard encryption (key: wg0-hop4-key-1)
- Determine next hop: Australia

**Output:** WireGuard Packet to Australia Hop

**Internal Log:**
- Taiwan IP assigned: 1.160.200.10 (Taipei)
- Query destination: 8.8.8.8 (unchanged)
- Next hop: Australia
- Timestamp: 2026-07-27T12:30:45.345Z

### Step 5: Australia Hop (AS1221 TELSTRA)

**Input:** WireGuard Packet (encrypted with wg0-hop4-key-1)

**Processing:**
- Decrypt using wg0-hop4-key-1
- Extract packet: 1.160.200.10 → 8.8.8.8:53
- Assign new source IP from Australian range: 1.128.100.77
- Keep destination unchanged: 8.8.8.8:53
- Log transformation: {from: 1.160.200.10, to: 1.128.100.77, geography: australia}
- Wrap in new WireGuard encryption (key: wg0-hop5-key-1)
- Determine next hop: Exit Router

**Output:** WireGuard Packet to Exit Router

**Internal Log:**
- Australian IP assigned: 1.128.100.77 (Sydney)
- Query destination: 8.8.8.8 (unchanged)
- Next hop: Exit Router
- Timestamp: 2026-07-27T12:30:45.456Z

### Step 6: Exit Router (Gateway)

**Input:** WireGuard Packet (encrypted with wg0-hop5-key-1)

**Processing:**
- Decrypt using wg0-hop5-key-1
- Extract final packet: 1.128.100.77 → 8.8.8.8:53
- Route to external network (internet)
- Log: {source: 1.128.100.77, destination: 8.8.8.8:53, type: dns_query}
- Send to external network

**Output:** DNS Query to Internet
```
DNS Query Packet {
  Source IP: 1.128.100.77 (Sydney, Australia)
  Destination IP: 8.8.8.8
  Destination Port: 53
  Payload: Query for google.com A record
}
```

### External Observer (Google DNS Server)

**Receives DNS Query:**
- Query appears to come from: 1.128.100.77
- Geographic location: Sydney, Australia (via IP geolocation)
- ASN: AS1221 TELSTRA

**External Observer Does NOT See:**
- ✗ Original source IP (192.168.1.100)
- ✗ Intermediate geographic hops
- ✗ WireGuard encryption at each hop
- ✗ Packet transformations at each stage

## Response Flow (Reverse Path)

Google DNS responds:
```
DNS Response (8.8.8.8 → 1.128.100.77):
  google.com A record: 142.251.41.14
```

### Reverse Transformation

Exit Router receives response:
- Destination: 1.128.100.77 (Australian IP)
- Recognizes as from tunnel 12345
- Reverse-maps Australian IP → Australia Hop
- Encrypts with wg0-hop5-key-1
- Sends back to Australia

Australia Hop reverses: 1.128.100.77 → 1.160.200.10 → Taiwan

Taiwan Hop reverses: 1.160.200.10 → 174.95.123.56 → Canada

Canada Hop reverses: 174.95.123.56 → 5.101.50.42 → Russia

Russia Hop reverses: 5.101.50.42 → 192.168.1.100 → Primary

Primary Router sends unencrypted response back to client (192.168.1.100)

### Client Receives Response

Browser receives DNS response:
- google.com A record: 142.251.41.14
- Can now connect to google.com

## Transformation Summary

| Stage | Source IP | Destination | ASN | Country |
|-------|-----------|-------------|-----|---------|
| Original | 192.168.1.100 | 8.8.8.8 | Home Network | Home |
| Russia | 5.101.50.42 | 8.8.8.8 | AS12389 | Russia |
| Canada | 174.95.123.56 | 8.8.8.8 | AS812 | Canada |
| Taiwan | 1.160.200.10 | 8.8.8.8 | AS9924 | Taiwan |
| Australia | 1.128.100.77 | 8.8.8.8 | AS1221 | Australia |
| External View | 1.128.100.77 | 8.8.8.8 | AS1221 | Australia |

## Key Insight

At each hop, the packet is **transformed AND encrypted**. This creates multiple layers of encryption plus multiple layers of IP masking, resulting in:

- **High Security:** Original source completely obscured through 6 layers of encryption
- **Geographic Obscurity:** Traffic appears to originate from Australia
- **Forensic Capability:** Complete packet transformation history logged at each hop
- **Transparency to Client:** All transformations happen invisibly; client sees normal operation
