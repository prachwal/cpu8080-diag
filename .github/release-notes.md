Self-checking **Intel 8080 CPU diagnostic** for CP/M (`DIAG8080.COM`, loads at `0100h`), MIT licensed.

* 150 734 summed test cases (ALU, flags, `DAA`, rotates, 16-bit arithmetic, moves) checked against an independent
  reference model with CRC-32, plus direct tests for the stack, jumps, calls, returns (each condition in four flag
  states, with stack pointer and return address checks), `RST 1..7`, and memory addressing.
* 238 of the 244 documented opcodes are executed. Not covered: `IN`, `OUT`, `HLT`, `EI`, `DI`, `RST 0`, interrupts,
  undocumented opcodes and timing.
* Verified case by case on an independent 8080 core and by mutation testing (31 broken variants detected, a correct
  control variant passes). Not verified on real 8080 silicon.
* A full run is about 740 million 8080 clock cycles (roughly 6 minutes at 2 MHz). Success prints
  `WSZYSTKIE TESTY ZALICZONE` and returns to `0000h`.

SHA-256 of the release asset:
