# HEIMDALL — Embedded System Supervision Framework

**HEIMDALL Core v1.0** is a modular, protocol-agnostic hardware supervision core that monitors whether a supervised processor is not just *alive*, but *executing correctly*. It combines heartbeat monitoring with challenge-response verification, and drives an automated, bounded recovery sequence on fault detection.

```
========================================
HEIMDALL SYSTEM VERIFICATION
========================================
Tests Passed : 25
Tests Failed : 0

HEIMDALL SYSTEM VERIFICATION PASSED
```
<!-- SCREENSHOT REQUIRED: terminal output above, 25 PASS / 0 FAIL -->

---

## Overview

A conventional watchdog timer only answers one question: *is the processor still executing?* It cannot tell you whether that execution is correct. HEIMDALL goes further by combining:

- **Heartbeat monitoring** — detects loss of a periodic liveness pulse.
- **Challenge-response verification** — confirms the monitored firmware is executing *correctly*, not just looping.
- **Fault detection and logging** — every fault is recorded in a hardware event log.
- **Automated recovery** — a bounded, deterministic reset-and-verify sequence, with an explicit failure outcome if the monitored system never comes back ready.

HEIMDALL Core v1.0 is intentionally **protocol-agnostic**: it exposes generic register and signal interfaces rather than a bus-specific one, so that protocol front-ends (SPI, UART, etc.) can be layered on top of the frozen, verified core in future releases without modifying any verified RTL.

## Motivation

Embedded systems that rely solely on watchdog timers are vulnerable to failures where the processor keeps running but stops doing the right thing — a stuck state machine, a corrupted-but-still-executing loop, a logic fault that never trips a simple liveness check. HEIMDALL was built to close that gap with a small, fully verified supervision core suitable for embedded, industrial, robotics, automotive, and research applications.

## Features

- Six independently verified RTL modules + top-level integration, all in synthesizable Verilog-2001
- Every module backed by a golden Embedded C reference model, verified for behavioral equivalence before RTL was accepted
- Centralized, memory-mapped configuration register bank
- Deterministic, parameterized recovery sequencing (reset hold / stabilization / readiness timeout)
- 16-entry hardware event log (circular FIFO) for fault history
- 25/25 system-level integration tests passing, zero outstanding failures
- 100% open-source simulation flow — no vendor FPGA tools required

## Architecture

<!-- DIAGRAM REQUIRED: Complete HEIMDALL system architecture, all six core
modules + top-level wrapper, signal connections labelled. -->

| ID | Module | Responsibility |
|----|--------|-----------------|
| HMD-001 | Configuration Manager | Memory-mapped register bank; runtime configuration |
| HMD-002 | Event Logger | Circular FIFO event log for fault records |
| HMD-003 | Heartbeat Engine | Detects loss of periodic heartbeat |
| HMD-004 | Challenge Engine | Issues challenges, verifies responses |
| HMD-005 | Supervisor FSM | Central coordinator — the "brain" of HEIMDALL |
| HMD-006 | Recovery Manager | Bounded, deterministic recovery sequencing |
| HMD-007 | Top-Level Integration | Instantiates and wires all six core modules |

Full module-level detail (interfaces, FSM states, design rationale) is in [`docs/`](docs/).

## Repository Structure

```
HEIMDALL/
├── docs/           Documentation, diagrams, assets
├── firmware/       Embedded C reference models
├── rtl/            Synthesizable Verilog-2001 RTL
├── tb/             Testbenches
├── scripts/        Build / simulation automation
├── build/          Compiled simulation binaries (generated)
├── waves/          GTKWave VCD dumps (generated)
├── assets/         Diagrams, screenshots, logos
└── examples/       Usage examples
```

## Verification Summary

Every module has an independent Embedded C unit test suite and a corresponding Verilog testbench, verified against the C golden model for both output correctness and cycle-level timing before being frozen. The full system is additionally verified end-to-end at the top-level integration.

| Module | Unit Tested | Integration Tested | Status |
|--------|:---:|:---:|:---:|
| Configuration Manager | ✅ | ✅ | PASS |
| Event Logger | ✅ | ✅ | PASS |
| Heartbeat Engine | ✅ | ✅ | PASS |
| Challenge Engine | ✅ | ✅ | PASS |
| Supervisor FSM | ✅ | ✅ | PASS |
| Recovery Manager | ✅ | ✅ | PASS |
| Top-Level Integration | — | ✅ | PASS |

**System test coverage:** Reset · Configuration Manager · Heartbeat Engine · Heartbeat Timeout · Challenge Engine (success) · Challenge Engine (failure) · Recovery Manager · Event Logger FIFO · Complete End-to-End System Flow

## Build Instructions

Toolchain: GCC, Icarus Verilog, GTKWave, Git.

```bash
# Build and run an Embedded C reference model + its unit tests
gcc firmware/<module>.c firmware/<module>_test.c -o build/<module>_test
./build/<module>_test
```

## Simulation Instructions

```bash
# Compile and simulate a single RTL module against its testbench
iverilog -o build/<module>_tb rtl/<module>.v tb/<module>_tb.v
vvp build/<module>_tb
gtkwave waves/<module>.vcd

# Full system integration
iverilog -o build/heimdall_top_tb rtl/*.v tb/heimdall_top_tb.v
vvp build/heimdall_top_tb
```

## Roadmap

HEIMDALL Core v1.0 is frozen. Planned future work is strictly additive, layered around the core without modifying verified RTL:

- Protocol front-ends (e.g. SPI, UART) translating bus transactions onto the existing configuration register interface
- Stronger, cryptographically robust challenge-response scheme
- Configurable Event Logger depth
- Support for multiple concurrently supervised processors
- FPGA synthesis and hardware bring-up
- Formal verification of the Supervisor FSM and Recovery Manager

## License

MIT License. See [`LICENSE`](LICENSE) for details.

## Author

HEIMDALL Project — developed as a disciplined, specification-first RTL/firmware co-design project.
