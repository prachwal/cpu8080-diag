#!/usr/bin/env python3
# MIT License. Copyright (c) 2026 Przemyslaw Rachwal.
"""Porownuje wydruk wariantu -DTRACE z modelem przypadek po przypadku (narzedzie diagnostyczne)."""
import sys
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import model

MASK_F = 0xD5 if model.CPU85 else 0xFF

lines = [l.strip() for l in open(sys.argv[1], errors="replace") if l.strip()]
want = sys.argv[2:] or [n for n, _ in model.GROUPS]
pos = 0
KEYS = ("A", "F", "B", "C", "D", "E", "H", "L", "M0", "M1")
for name, factory in model.GROUPS:
    fn = factory()
    dims = model.DIMS[name]
    n = 1
    for d in dims:
        n *= d
    # pomin linie niebedace hex (naglowki / wyniki grup)
    chunk = []
    while len(chunk) < n and pos < len(lines):
        l = lines[pos]
        pos += 1
        if len(l) == 20 and all(c in "0123456789ABCDEF" for c in l):
            chunk.append(l)
    bad = 0
    first = []
    for ctr, got in zip(model.odometer(dims), chunk):
        s = fn(ctr)
        exp = "".join("%02X" % (s[k] & MASK_F if k == "F" else s[k]) for k in KEYS)
        if exp != got.upper()[:2] + "%02X" % (int(got[2:4], 16) & MASK_F) + got[4:]:
            bad += 1
            if len(first) < 12:
                first.append((ctr, got, exp))
    print("== %s: %d/%d niezgodnych" % (name, bad, n))
    if name in want:
        for ctr, got, exp in first:
            diff = [KEYS[i] + ":%s!=%s" % (got[2*i:2*i+2], exp[2*i:2*i+2]) for i in range(10) if got[2*i:2*i+2] != exp[2*i:2*i+2]]
            print("  ctr=%s  %s" % (ctr, " ".join(diff)))
