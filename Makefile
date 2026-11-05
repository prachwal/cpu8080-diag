# MIT License. Copyright (c) 2026 Przemyslaw Rachwal. See LICENSE.
Z80ASM ?= z88dk-z80asm
PYTHON ?= python3
SRC    := src/diag8080.asm src/direct.inc src/generated.inc

.PHONY: all raw model check sums clean
all: dist/DIAG8080.COM

dist/DIAG8080.COM: $(SRC)
	mkdir -p build dist
	$(Z80ASM) -m8080 -b -Isrc -obuild/DIAG8080.bin src/diag8080.asm
	cp build/DIAG8080.bin $@
	cd dist && sha256sum DIAG8080.COM > SHA256SUMS

raw: $(SRC)
	mkdir -p build
	$(Z80ASM) -m8080 -b -DRAW -Isrc -m -obuild/diag8080-raw.bin src/diag8080.asm

model:
	$(PYTHON) tools/model.py --emit src/generated.inc

check:
	$(PYTHON) tools/model.py --check src/generated.inc

clean:
	rm -rf build
