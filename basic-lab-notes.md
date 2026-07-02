# Basic Lab Notes

Notes on p4/tutorials/exercises/basic to validate install and start learning.

## Build → Run Chain

1. `p4c-bm2-ss` compiles `basic.p4` → `build/basic.json` + `build/basic.p4.p4info.txtpb`
2. Mininet launches topology from `pod-topo/topology.json`
3. `simple_switch_grpc` starts per switch, loaded with `basic.json`
4. Table entries from `s*-runtime.json` pushed via P4Runtime
5. `mininet>` prompt — ready for traffic

All triggered by `make run` from the exercise directory.

## Mininet Commands

| Command | Purpose |
|---|---|
| `nodes` | List hosts + switches |
| `net` | Show links |
| `dump` | Node info (IPs, PIDs) |
| `h1 ping h2` | Ping between hosts |
| `pingall` | Ping all pairs |
| `h1 <cmd>` | Run shell command on h1 |
| `exit` | Tear down and quit |

## Observing Traffic

| What | Where |
|---|---|
| Packet captures | `pcaps/s1-eth1_in.pcap` |
| Switch pipeline logs | `logs/s1.log` |
| Runtime table state | `simple_switch_CLI --thrift-port 9090` |

Key CLI commands: `show_tables`, `show_actions`, `table_dump MyIngress.ipv4_lpm`

## Two-Terminal Workflow

- **Terminal 1** — `make run` → `mininet>` prompt → generate traffic
- **Terminal 2** — `tail -f logs/s1.log`, `tcpdump -r pcaps/...`, or `simple_switch_CLI`

Thrift ports: s1=9090, s2=9091, s3=9092, s4=9093

## Cleanup

- `exit` from mininet tears everything down
- `make stop` and `make clean` to stop and clean up
- `sudo mn --clean` as last resort

## Example: Incomplete basic.p4

Setup: two terminals open, both in venv and exercise directory.

- **Terminal 1** — `make run` → `mininet>` prompt
- **Terminal 2** — `tail -f logs/s1.log`

### 1. h1 ping s1 (local, does not traverse the P4 pipeline)

```
mininet> h1 ping s1
PING 127.0.0.1 (127.0.0.1) 56(84) bytes of data.
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.901 ms
64 bytes from 127.0.0.1: icmp_seq=2 ttl=64 time=0.050 ms
```

Success — since s1 has no (management) IPv4 address, h1 resolved s1 to 127.0.0.1. Key point is that this traffic does not traverse through s1's P4 data plane.

### 2. h1 ping h2 (through s1, exercises the P4 pipeline)

```
mininet> h1 ping h2
PING 10.0.2.2 (10.0.2.2) 56(84) bytes of data.
--- 10.0.2.2 ping statistics ---
5 packets transmitted, 0 received, 100% packet loss, time 4120ms
```

100% loss. The s1.log shows why:

```
[cxt 0] Parser 'parser' entering state 'start'
[cxt 0] Parser state 'start' has no switch, going to default next state
[cxt 0] Bytes parsed: 0
[cxt 0] Applying table 'MyIngress.ipv4_lpm'
[cxt 0] Looking up key:
* hdr.ipv4.dstAddr    : 00000000
[cxt 0] Table 'MyIngress.ipv4_lpm': miss
[cxt 0] Action entry is MyIngress.drop -
[cxt 0] Action MyIngress.drop
[cxt 0] basic.p4(100) Primitive mark_to_drop(standard_metadata)
[cxt 0] Egress port is 511
[cxt 0] Dropping packet at the end of ingress
```

The parser extracted 0 bytes (no headers parsed), so `ipv4.dstAddr` is all zeros → table miss → drop action → packet dropped (egress port 511 = drop).

Root cause: the starter `basic.p4` has an empty parser and empty `ipv4_forward` action.

### 3. Inspecting switch state (Terminal 2)

Connect to s1 (thrift port 9090):

```
simple_switch_CLI --thrift-port 9090
```

```
RuntimeCmd: show_tables
MyIngress.ipv4_lpm             [implementation=None, mk=ipv4.dstAddr(lpm, 32)]
RuntimeCmd: table_dump MyIngress.ipv4_lpm
==========
TABLE ENTRIES
**********
Dumping entry 0x0
Match key:
* ipv4.dstAddr        : LPM       0a000101/32
Action entry: MyIngress.ipv4_forward - 080000000111, 01
**********
Dumping entry 0x1
Match key:
* ipv4.dstAddr        : LPM       0a000202/32
Action entry: MyIngress.ipv4_forward - 080000000222, 02
**********
Dumping entry 0x2
Match key:
* ipv4.dstAddr        : LPM       0a000303/32
Action entry: MyIngress.ipv4_forward - 080000000300, 03
**********
Dumping entry 0x3
Match key:
* ipv4.dstAddr        : LPM       0a000404/32
Action entry: MyIngress.ipv4_forward - 080000000400, 04
==========
Dumping default entry
Action entry: MyIngress.drop - 
==========
RuntimeCmd: show_actions
MyIngress.drop                 []
MyIngress.ipv4_forward         [dstAddr(48),    port(9)]
NoAction                       []
RuntimeCmd: EOF
```

LPM values are hex IPs (e.g. `0a000101` = `10.0.1.1`). Action params are hex MAC + egress port. Default entry is `drop` (table miss).
