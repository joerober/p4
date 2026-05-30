#include <core.p4>
#include <v1model.p4>

// ---------- Header definitions ----------

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

struct headers_t {
    ethernet_t ethernet;
    ipv6_t     ipv6;
}

struct metadata_t { }

// ---------- Parser ----------

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

// ---------- Checksum verify (required block, empty here) ----------

control MyVerifyChecksum(inout headers_t hdr, inout metadata_t meta) {
    apply { }
}

// ---------- Ingress: match-action ----------

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

// ---------- Egress (empty) ----------

control MyEgress(inout headers_t hdr,
                 inout metadata_t meta,
                 inout standard_metadata_t std_meta) {
    apply { }
}

// ---------- Checksum compute (required block, empty here) ----------

control MyComputeChecksum(inout headers_t hdr, inout metadata_t meta) {
    apply { }
}

// ---------- Deparser ----------

control MyDeparser(packet_out pkt, in headers_t hdr) {
    apply {
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.ipv6);
    }
}

// ---------- Wire it all together ----------

V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;
