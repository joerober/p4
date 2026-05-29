# NOS + P4 ASIC Combinations (Validated)

| NOS | P4 Hardware | Notes |
|---|---|---|
| **SONiC** | **Cisco Silicon One** (P100, P200, G200, G300) | SONiC runs on Cisco 8000 platform. SAI abstracts between SONiC and the P4-programmable ASIC. |
| **Cisco IOS XR** | **Cisco Silicon One** | Native NOS for Cisco 8000. Same P4-programmable ASIC, different OS on top. |
| **Arista EOS** | **Intel (Barefoot) Tofino / Tofino2** | Arista 7170 Series. EOS SDK on top of Tofino P4 pipeline. |
| **RARE/freeRtr** | **BMv2, Tofino** | Purpose-built for P4. NOS designed from the ground up with P4 as its data plane. |

## What P4 Adds to the NOS

- **In-band Network Telemetry (INT)** — Per-packet, per-hop metadata insertion at line rate
- **Custom match/action policies** — ACLs, compliance tagging, header manipulation beyond what a fixed ASIC supports
- **Non-standard protocol support** — Parse and act on headers the ASIC vendor didn't anticipate
- **Programmable forwarding** — Pipeline structure defined by the operator, not the silicon vendor
