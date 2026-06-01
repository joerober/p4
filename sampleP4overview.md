# sample.p4 Program Overview

## Block 1 - #include files

Lines 1-2:

```p4
#include <core.p4>
#include <v1model.p4>
```

- `core.p4` — standard library. Same across all targets.
- `v1model.p4` — architecture file. Platform-dependent. Declares the pipeline shape for bmv2.

> **Context note:** Throughout this overview, "pipeline" means **one specific ASIC's internal pipeline** (parser → ingress → egress → deparser), not the end-to-end network path.

## Block 2 - Header definitions

Lines 6-21:

```p4
header ethernet_t {
    bit<48> dst_mac;
    bit<48> src_mac;
    bit<16> ethertype;
}

header ipv6_t {
    bit<4>   version;
    bit<8>   traffic_class;
    bit<20>  flow_label;
    bit<16>  payload_len;
    bit<8>   next_hdr;
    bit<8>   hop_limit;
    bit<128> src_addr;
    bit<128> dst_addr;
}
```

- `header` declares a packet header layout.
- Field order = on-the-wire order.
- `bit<N>` = width of that field in bits.

## Block 3 - Struct definitions

Lines 23-28:

```p4
struct headers_t {
    ethernet_t ethernet;
    ipv6_t     ipv6;
}

struct metadata_t { }
```

- `struct` groups things by name. Fixed layout, fixed-width fields, decided at compile time. Not a dict/map/slice — P4 has no dynamic data structures.
- `headers_t` bundles the header instances the program will use.
- `metadata_t` is required by v1model to avoid a compile error. This sample has the minimum of an empty `{ }` value. When used, this metadata is local to this ASIC's internal pipeline only and never reaches the wire.
  - More information to follow on how this field is utilized by In-band Network Telemetry (INT) and other use cases.

## Block 4 - Parser

Lines 32-47:

```p4
parser MyParser(packet_in pkt,
                out headers_t hdr,
                inout metadata_t meta,
                inout standard_metadata_t std_meta) {
    state start {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ethertype) {
            0x86DD: parse_ipv6;
            default: accept;
        }
    }
    state parse_ipv6 {
        pkt.extract(hdr.ipv6);
        transition accept;
    }
}
```

- A `parser` is a **state machine** that reads bytes off the wire and fills in header instances.
- Always starts in `state start`.
- `pkt.extract(...)` pulls bytes into a header (and marks that header valid).
- `transition` picks the next state. Ends with `accept` (done) or `reject` (drop).

**External symbols used in this block:**

| Symbol | Defined in |
|---|---|
| `packet_in` | `core.p4` |
| `standard_metadata_t` | `v1model.p4` |

## Block 5 - Verify Checksum

Lines 51-53:

```p4
control MyVerifyChecksum(inout headers_t hdr, inout metadata_t meta) {
    apply { }
}
```

- `control` is a match-action block. v1model expects six of them in a fixed order — this is the first.
- This block is **required** by v1model. Empty body is fine.
- IPv6 has no header checksum, so nothing to verify. (Would matter for IPv4 or upper-layer checksums.)
- `apply { }` is the entry point of any control block. Empty here = does nothing.

## Block 6 - Ingress

Lines 57-89:

```p4
control MyIngress(inout headers_t hdr,
                  inout metadata_t meta,
                  inout standard_metadata_t std_meta) {

    action drop() {
        mark_to_drop(std_meta);
    }

    action forward(bit<9> port, bit<48> next_hop_mac) {
        std_meta.egress_spec = port;
        hdr.ethernet.src_mac = hdr.ethernet.dst_mac;
        hdr.ethernet.dst_mac = next_hop_mac;
        hdr.ipv6.hop_limit   = hdr.ipv6.hop_limit - 1;
    }

    table ipv6_lpm {
        key = {
            hdr.ipv6.dst_addr : lpm;
        }
        actions = {
            forward;
            drop;
        }
        default_action = drop();
        size = 1024;
    }

    apply {
        if (hdr.ipv6.isValid()) {
            ipv6_lpm.apply();
        }
    }
}
```

- This is the second of v1model's six `control` blocks — where forwarding decisions happen.
- Three things inside: **actions** (what to do), a **table** (what to match on), and an **apply** block (what runs).
- `action` = a named operation. The table picks one when a packet matches.
- `table` = match-on-something, run-an-action. The P4 program defines the **shape** (what fields are matched, what actions are possible); the control plane fills in the **entries** at runtime via P4Runtime (e.g., "prefix `2001:db8::/32` → forward(port=5, mac=...)"). This is the main seam between the P4 program and the control plane.
- `default_action` only runs when **no entry matches**. Empty table → everything drops. Once the control plane installs entries → matching packets get the matched action; non-matching still drop.
- `apply { ... }` is the entry point of the control block. Here it runs the table, guarded by `isValid()` so we don't read fields of a header that wasn't parsed.
- `.apply()` is a built-in method on every `table` — the compiler generates it automatically when you declare a table. It's how you invoke the table lookup.

**External symbols used in this block:**

| Symbol | Defined in |
|---|---|
| `standard_metadata_t` | `v1model.p4` |
| `mark_to_drop` | `v1model.p4` |

## Block 7 - Egress

Lines 93-97:

```p4
control MyEgress(inout headers_t hdr,
                 inout metadata_t meta,
                 inout standard_metadata_t std_meta) {
    apply { }
}
```

- Third of v1model's six `control` blocks. Runs **after** the traffic manager (queueing, replication), so it has access to egress-side info like queue depth and egress port.
- Required by v1model. Empty body is fine.
- Empty here — the sample only forwards. This is typically where telemetry/INT work would live.

## Block 8 - Compute Checksum

Lines 101-103:

```p4
control MyComputeChecksum(inout headers_t hdr, inout metadata_t meta) {
    apply { }
}
```

- Fourth of v1model's six `control` blocks. Mirror of Block 5 (Verify Checksum), but runs on the way out.
- Required by v1model. Empty body is fine.
- IPv6 has no header checksum, so nothing to compute. (Would matter for IPv4 or upper-layer checksums after modifying the packet.)

## Block 9 - Deparser

Lines 107-112:

```p4
control MyDeparser(packet_out pkt, in headers_t hdr) {
    apply {
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.ipv6);
    }
}
```

- Fifth of v1model's six `control` blocks. Rebuilds the outgoing packet.
- `pkt.emit(hdr)` writes a header back to the wire **only if it's valid**. Invalid headers are skipped.
- That's how headers are added/removed: `setValid()` / `setInvalid()` in the control blocks, and the deparser does or doesn't emit them.

**External symbols used in this block:**

| Symbol | Defined in |
|---|---|
| `packet_out` | `core.p4` |

## Block 10 - V1Switch instantiation

Lines 116-123:

```p4
V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;
```

- This ties everything together — declares the complete program by instantiating the package as `main`.
- `V1Switch` is the package type defined by v1model. It expects six blocks in this exact order: 1 parser + 5 controls.
- `main` is the name the compiler looks for. Without this, the file is just definitions — nothing compiles into a pipeline.
- Reminder: this single instantiation compiles to one monolithic pipeline — all or none, per ASIC.

**External symbols used in this block:**

| Symbol | Defined in |
|---|---|
| `V1Switch` | `v1model.p4` |
