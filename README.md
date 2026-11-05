# cpu8080-diag

A self-checking **Intel 8080 CPU diagnostic** for CP/M (`DIAG8080.COM`, loads at `0100h`), released under the **MIT license**.

It exists so that 8080 emulators and FPGA/hardware cores can be tested with a program that may be freely redistributed
(some classic 8080 test programs have no clear redistribution terms).

## Clean-room statement

This program was written from scratch from the public Intel 8080 documentation (instruction set and flag semantics).
It contains **no code or data copied from other test programs**, and the author did not consult the source of
other 8080 diagnostics while writing it. Expected results are produced by an independent reference model
(`tools/model.py`) that is also written from the documentation.

## What it does

For every test case (an instruction plus an initial register/flag state) the program executes the instruction and folds
the resulting `A F B C D E H L` and two memory bytes into a CRC-32. At the end of each group the CRC is compared
with the value computed by the reference model, so the program verifies tens of thousands of cases while printing one line per group.

| Group | Cases | Covers |
|---|---:|---|
| `ALU reg` | 32 768 | `ADD ADC SUB SBB ANA XRA ORA CMP` with all 8 operand registers (incl. `M`), 16 edge values squared, carry in/out |
| `ALU imm` | 4 096 | `ADI ACI SUI SBI ANI XRI ORI CPI` |
| `INR/DCR` | 28 672 | all 256 values, all 8 registers, 7 initial flag patterns (carry must be preserved) |
| `DAA CMA STC CMC RLC RRC RAL RAR` | 14 336 | all 256 accumulator values, 7 flag patterns |
| `DAD INX DCX` | 36 288 | `BC`, `DE`, `HL`, 24 edge 16-bit values squared |
| `MOV r,r'` / `MVI` / `LXI` | 526 | all register moves, immediates, 16-bit loads, flags preserved |
| direct tests | — | `PUSH/POP` (byte order, flag image `SZ0A0P1C`), `XTHL`, `SPHL`, `PCHL`, `LDAX/STAX`, `LDA/STA`, `LHLD/SHLD`, `XCHG`, `CALL/RET`, `RST 1..7`, all 8 conditions of `Jcc/CALLcc/RETcc` |

Total: 116 686 summed cases + the direct tests.

Not covered: `IN`/`OUT`, `HLT`, `EI`/`DI`, interrupts, `RIM`/`SIM` (8085), undocumented opcodes and instruction timing.
A full run is about 560 million 8080 clock cycles (roughly 4.5 minutes at 2 MHz).

Hardware behaviour that is checked: `ANA`/`ANI` set `AC` to the OR of bit 3 of both operands, `SUB`/`CMP` compute `AC`
as the carry of `A + ~operand + 1`, `DCR` sets `AC` unless the low nibble was zero, `DAA` follows the documented
two-step correction, `PUSH PSW` always produces flag bits `S Z 0 AC 0 P 1 CY`.

## Output

```
DIAG8080 - test procesora Intel 8080
ALU reg (ADD ADC SUB SBB ANA XRA ORA CMP) OK
...
WSZYSTKIE TESTY ZALICZONE        (= "ALL TESTS PASSED")
```
On a mismatch the group prints `FAIL got=<crc> exp=<crc>` and the program ends with `TESTY NIEZALICZONE` (= "TESTS FAILED").
Direct-test failures print ` [Txx ` with the test number (see `src/direct.inc`).

## How it was verified

* The reference model and the program agree **case by case** (tracing build, `tools/trace_compare.py`) on an
  independent 8080 core: 0 mismatches over 116 686 cases, and the real `.COM` reports all groups OK.
* **Mutation testing:** 22 deliberately broken variants of that core (wrong flags, off-by-one results, broken
  register moves, ...) were all detected. An earlier additive checksum missed three of them, which is why CRC-32 is used.
* `z88dk-ticks -m8080` is **not** a valid reference: it emulates the Z80 flag logic in "8080 mode" (e.g. parity/overflow
  after arithmetic, `H` after `DAD`, the `N` flag in `DAA`) and disagrees with the 8080 documentation.
* Not verified on real 8080 silicon. If a real chip disagrees with the model, please open an issue.

## Building

Requires `z88dk` (`z88dk-z80asm`) and `python3`.

```
make            # dist/DIAG8080.COM (CP/M build)
make raw        # build/diag8080-raw.bin: output with OUT 80h instead of BDOS (for emulators without CP/M)
make model      # regenerate src/generated.inc from tools/model.py
make check      # fail if src/generated.inc is out of date
```

`-DTRACE` (with `-DRAW`) prints the ten result bytes of every case; `tools/trace_compare.py` compares that output with the model.

## Po polsku

Samosprawdzający się test diagnostyczny procesora Intel 8080 (plik `.COM` dla CP/M) na licencji MIT. Napisany od zera
na podstawie dokumentacji Intela, bez kodu z innych programów testowych. Oczekiwane wyniki liczy niezależny model w Pythonie.

## License

MIT, see `LICENSE`.
