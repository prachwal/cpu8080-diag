# MIT License. Copyright (c) 2026 Przemyslaw Rachwal. See LICENSE.
Z80ASM ?= z88dk-z80asm
PYTHON ?= python3
SRC    := src/diag8080.asm src/direct.inc src/generated.inc src/generated85.inc

.PHONY: all raw model check clean
all: dist/DIAG8080.COM dist/DIAG8085.COM dist/SHA256SUMS

dist/DIAG8080.COM: $(SRC)
	mkdir -p build dist
	$(Z80ASM) -m8080 -b -Isrc -obuild/DIAG8080.bin src/diag8080.asm
	cp build/DIAG8080.bin $@

dist/DIAG8085.COM: $(SRC)
	mkdir -p build dist
	$(Z80ASM) -m8085 -b -DI8085 -Isrc -obuild/DIAG8085.bin src/diag8080.asm
	cp build/DIAG8085.bin $@

dist/SHA256SUMS: dist/DIAG8080.COM dist/DIAG8085.COM
	cd dist && sha256sum DIAG8080.COM DIAG8085.COM > SHA256SUMS

# Wersje "raw": wyjscie przez OUT 80h zamiast BDOS (dla emulatorow bez CP/M).
raw: $(SRC)
	mkdir -p build
	$(Z80ASM) -m8080 -b -DRAW -Isrc -m -obuild/diag8080-raw.bin src/diag8080.asm
	$(Z80ASM) -m8085 -b -DI8085 -DRAW -Isrc -m -obuild/diag8085-raw.bin src/diag8080.asm

model:
	$(PYTHON) tools/model.py --emit src/generated.inc
	$(PYTHON) tools/model.py --emit src/generated85.inc --cpu 8085

check:
	$(PYTHON) tools/model.py --check src/generated.inc
	$(PYTHON) tools/model.py --check src/generated85.inc --cpu 8085

clean:
	rm -rf build
