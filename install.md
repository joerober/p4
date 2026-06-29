# Native Install — Mininet + BMv2

Install path for the P4 dev/learning toolchain. **Installed directly on a
Linux host (bare metal), not a VM.** Mininet uses Linux network namespaces and
veth pairs natively, so a hypervisor/VM only adds overhead with no benefit on a
machine that is already Linux. Containerizing the stack was likewise rejected —
Mininet belongs on the host.

> Decision context: target is an Ubuntu 24.04 Linux instance. `stratum-bmv2`
> (adds P4Runtime + gNMI on top of BMv2) is parked as a later direction.

## What gets installed

`jafingerhut/p4-guide`'s `install-p4dev-v10.sh` builds the full toolchain from
source (~8 GB): `p4c`, BMv2, PI, Mininet, and gRPC/protobuf. Ubuntu 24.04 is
supported.

## Steps

```bash
# 1. Get the installer
git clone https://github.com/jafingerhut/p4-guide

# 2. Build the toolchain from source (long; logs to log.txt)
cd p4-guide/bin
./install-p4dev-v10.sh |& tee log.txt

# 3. Load the environment (PATH etc.) into the current shell
source p4setup.bash

# 4. Get the official exercises
git clone https://github.com/p4lang/tutorials

# 5. Compile a P4 program and launch Mininet + BMv2
cd tutorials/exercises/basic && make run
# drops into the mininet> prompt
```

## Notes

- `source p4setup.bash` must be re-run per shell (or add to shell rc) to get
  `p4c`, `simple_switch`, etc. on `PATH`.
- `make run` in an exercise dir compiles the `.p4`, starts the Mininet
  topology with BMv2 switches, and gives you the `mininet>` CLI.
