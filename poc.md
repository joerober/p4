# Proof of Concept Lab: Containerlab + Kind

Containerlab manages the network devices; Kind provides the compute endpoint(s). Both run as containers on the same Docker host and can be wired together.

## Option A: RARE/freeRtr (P4-native) + Kind

The most direct P4 option. RARE/freeRtr is a first-class containerlab kind with a `p4emu` dataplane mode that runs a P4-emulated forwarding pipeline.

```yaml
name: p4-pilot
topology:
  nodes:
    # P4 routers
    rtr1:
      kind: rare
      image: ghcr.io/rare-freertr/freertr-containerlab:latest
      env:
        DATAPLANE_TYPE: "p4emu"
    rtr2:
      kind: rare
      image: ghcr.io/rare-freertr/freertr-containerlab:latest
      env:
        DATAPLANE_TYPE: "p4emu"

    # Kind cluster (compute endpoint)
    k8s:
      kind: k8s-kind
      startup-config: kind-config.yaml

    # Wire Kind nodes into the network
    k8s-control-plane:
      kind: ext-container
      exec:
        - "ip addr add dev eth1 192.168.10.1/24"

  links:
    - endpoints: ["rtr1:eth1", "rtr2:eth1"]
    - endpoints: ["rtr2:eth2", "k8s-control-plane:eth1"]
```

- **Pros:** P4 pipeline is active and programmable; containerlab-native; freely available image
- **Cons:** freeRtr is less widely known; CLI/config style may be unfamiliar

## Option B: SONiC-VS + Kind

SONiC-VS is containerized SONiC with a virtual switch (kernel) dataplane. No P4 programmability in the data plane, but gives you the SONiC control plane experience.

```yaml
name: sonic-pilot
topology:
  nodes:
    sonic1:
      kind: sonic-vs
      image: <sonic-vs-image>
    sonic2:
      kind: sonic-vs
      image: <sonic-vs-image>

    k8s:
      kind: k8s-kind
      startup-config: kind-config.yaml
    k8s-control-plane:
      kind: ext-container
      exec:
        - "ip addr add dev eth1 192.168.10.1/24"

  links:
    - endpoints: ["sonic1:eth1", "sonic2:eth1"]
    - endpoints: ["sonic2:eth2", "k8s-control-plane:eth1"]
```

- **Pros:** Real SONiC experience (BGP, IS-IS, config DB, etc.); first-class containerlab kind
- **Cons:** No P4 data plane — fixed virtual switch pipeline

## Option C: Both — RARE/freeRtr + SONiC-VS + Kind

Use RARE/freeRtr as the P4-programmable edge/policy routers, SONiC-VS as a core/transit router, and Kind as the compute endpoint. Combines both NOS experiences.

## How Kind Integrates with Containerlab

- **`k8s-kind`** node type manages Kind cluster lifecycle (deploy/destroy)
- **`ext-container`** node type references the actual Kind Docker containers (named `<cluster-name>-control-plane`, `<cluster-name>-worker`, etc.)
- Links wire the Kind container's `eth1+` interfaces directly to router ports
- Kind config is passed via `startup-config` referencing a standard Kind cluster YAML:

```yaml
# kind-config.yaml
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
  - role: control-plane
  - role: worker
```

## Prerequisites (Single Docker Host)

- **Docker** installed
- **[Containerlab](https://containerlab.dev)** installed
- **[Kind](https://kind.sigs.k8s.io)** installed
