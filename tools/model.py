#!/usr/bin/env python3
# MIT License. Copyright (c) 2026 Przemyslaw Rachwal. Zob. LICENSE.
"""Referencyjny model instrukcji Intel 8080 oraz generator tabel i wartosci oczekiwanych.

Model jest napisany wylacznie na podstawie dokumentacji Intel 8080 (opis instrukcji i flag),
bez korzystania z cudzych programow testowych. Generuje `src/generated.inc` (tabele i sumy
kontrolne), ktore konsumuje `src/diag8080.asm`.

Uzycie:  python3 tools/model.py --emit src/generated.inc
         python3 tools/model.py --check src/generated.inc   (porownuje z zapisanym plikiem)
"""
import sys

V16 = [0x00, 0x01, 0x0F, 0x10, 0x1F, 0x7F, 0x80, 0x81, 0x8F, 0xF0, 0xFF, 0x55, 0xAA, 0x3C, 0xC3, 0x7E]
F2 = [0x02, 0xD7]
F7 = [0x02, 0x03, 0x12, 0x06, 0x42, 0x82, 0xD7]
W24 = [0x0000, 0x0001, 0x0002, 0x00FF, 0x0100, 0x0101, 0x0FFF, 0x1000, 0x7FFF, 0x8000, 0x8001, 0xFFFE,
       0xFFFF, 0x5555, 0xAAAA, 0x1234, 0xFEDC, 0x00F0, 0x0F00, 0xF000, 0x7F7F, 0x8080, 0x0A0A, 0xA5A5]
ALU_OPS = [0x80, 0x88, 0x90, 0x98, 0xA0, 0xA8, 0xB0, 0xB8]   # ADD ADC SUB SBB ANA XRA ORA CMP (rejestr w bitach 0-2)
IMM_OPS = [0xC6, 0xCE, 0xD6, 0xDE, 0xE6, 0xEE, 0xF6, 0xFE]   # ADI ACI SUI SBI ANI XRI ORI CPI
INCDEC_BASE = [0x04, 0x05]                                    # INR r, DCR r (rejestr w bitach 3-5)
ACC_OPS = [0x27, 0x2F, 0x37, 0x3F, 0x07, 0x0F, 0x17, 0x1F]    # DAA CMA STC CMC RLC RRC RAL RAR
DAD_OPS = [0x09, 0x19, 0x29, 0x03, 0x13, 0x23, 0x0B, 0x1B, 0x2B]  # DAD B,D,H  INX B,D,H  DCX B,D,H
LXI_OPS = [0x01, 0x11, 0x21]
REG = ['B', 'C', 'D', 'E', 'H', 'L', 'M', 'A']

FS, FZ, FA, FP, FC = 0x80, 0x40, 0x10, 0x04, 0x01


def parity(x):
    return FP if bin(x & 0xFF).count("1") % 2 == 0 else 0


def szp(r):
    return (FS if r & 0x80 else 0) | (FZ if (r & 0xFF) == 0 else 0) | parity(r)


def new_state(a, f, b, c, d, e, h, l, m0, m1):
    return {'A': a, 'F': f, 'B': b, 'C': c, 'D': d, 'E': e, 'H': h, 'L': l, 'M0': m0, 'M1': m1}


def vstate(v, a, f):
    return new_state(a, f, v, v, v, v, 0x80, 0x00, v, 0x92)


def base(a, f):
    return new_state(a, f, 0xB2, 0xC3, 0xD4, 0xE5, 0x80, 0x00, 0x6D, 0x92)


def getr(s, r):
    return s['M0'] if r == 6 else s[REG[r]]


def setr(s, r, v):
    s['M0' if r == 6 else REG[r]] = v & 0xFF


def pair(s, hi, lo):
    return (s[hi] << 8) | s[lo]


def setpair(s, hi, lo, v):
    s[hi] = (v >> 8) & 0xFF
    s[lo] = v & 0xFF


def alu(kind, a, b, cy_in):
    """kind: 0 ADD 1 ADC 2 SUB 3 SBB 4 ANA 5 XRA 6 ORA 7 CMP. Zwraca (wynik A, F)."""
    if kind in (0, 1):
        c = cy_in if kind == 1 else 0
        t = a + b + c
        res, cy, ac = t & 0xFF, t > 0xFF, ((a & 0xF) + (b & 0xF) + c) > 0xF
    elif kind in (2, 3, 7):
        c = cy_in if kind == 3 else 0
        t = a - b - c
        res, cy = t & 0xFF, t < 0
        ac = ((a & 0xF) + ((~b) & 0xF) + (1 - c)) > 0xF      # 8080: AC = przeniesienie z bitu 3 sumy A + ~B + ~C
    elif kind == 4:
        res, cy, ac = a & b, False, bool((a | b) & 0x08)       # 8080: AC = OR bitow 3 argumentow
    elif kind == 5:
        res, cy, ac = a ^ b, False, False
    else:
        res, cy, ac = a | b, False, False
    f = 0x02 | szp(res) | (FA if ac else 0) | (FC if cy else 0)
    return (a if kind == 7 else res), f


def do_daa(a, f):
    cy, ac = bool(f & FC), bool(f & FA)
    cor = 0
    if (a & 0xF) > 9 or ac:
        cor |= 0x06
    new_cy = cy
    if a > 0x99 or cy:
        cor |= 0x60
        new_cy = True
    new_ac = ((a & 0xF) + (cor & 0xF)) > 0xF
    res = (a + cor) & 0xFF
    return res, 0x02 | szp(res) | (FA if new_ac else 0) | (FC if new_cy else 0)


def _crc_table():
    t = []
    for i in range(256):
        c = i
        for _ in range(8):
            c = (c >> 1) ^ 0xEDB88320 if c & 1 else c >> 1
        t.append(c)
    return t


CRC_T = _crc_table()


def fold_state(crc, s):
    """CRC-32 (odbity, wielomian EDB88320h) po kolejnych bajtach stanu; bez koncowego XOR."""
    for k in ('A', 'F', 'B', 'C', 'D', 'E', 'H', 'L', 'M0', 'M1'):
        crc = (crc >> 8) ^ CRC_T[(crc ^ s[k]) & 0xFF]
    return crc


def odometer(dims):
    """Ostatni wymiar zmienia sie najszybciej (jak w asm)."""
    ctr = [0] * len(dims)
    while True:
        yield tuple(ctr)
        i = len(dims) - 1
        while i >= 0:
            ctr[i] += 1
            if ctr[i] < dims[i]:
                break
            ctr[i] = 0
            i -= 1
        if i < 0:
            return


def run_group(dims, build):
    acc = 0xFFFFFFFF
    for ctr in odometer(dims):
        s = build(ctr)
        acc = fold_state(acc, s)
    return acc


# ---- grupy -----------------------------------------------------------------------------------

DIMS = {
    'alu':    [8, 8, 2, 16, 16],
    'imm':    [8, 2, 16, 16],
    'incdec': [2, 8, 7, 16, 16],
    'acc':    [8, 7, 16, 16],
    'dad':    [9, 7, 24, 24],
    'mov':    [63, 2],
    'mvi':    [8, 2, 16],
    'lxi':    [3, 2, 24],
}


def g_alu(c):
    op, r, fi, ai, bi = c
    a, b, f = V16[ai], V16[bi], F2[fi]
    s = vstate(b, a, f)
    src = getr(s, r)
    res, nf = alu(op, a, src, f & FC)
    s['A'], s['F'] = res, nf
    return s


def g_imm(c):
    op, fi, ai, ii = c
    a, imm, f = V16[ai], V16[ii], F2[fi]
    s = base(a, f)
    s['A'], s['F'] = alu(op, a, imm, f & FC)
    return s


def g_incdec(c):
    kind, r, fi, hi, lo = c
    v, f = (hi << 4) | lo, F7[fi]
    s = vstate(v, v, f)
    x = getr(s, r)
    if kind == 0:
        res, ac = (x + 1) & 0xFF, (x & 0xF) == 0xF
    else:
        res, ac = (x - 1) & 0xFF, (x & 0xF) != 0
    setr(s, r, res)
    s['F'] = 0x02 | (f & FC) | szp(res) | (FA if ac else 0)
    return s


def g_acc(c):
    op, fi, hi, lo = c
    v, f = (hi << 4) | lo, F7[fi]
    s = vstate(v, v, f)
    cy = f & FC
    if op == 0:
        s['A'], s['F'] = do_daa(v, f)
    elif op == 1:
        s['A'] = (~v) & 0xFF
    elif op == 2:
        s['F'] = f | FC
    elif op == 3:
        s['F'] = f ^ FC
    elif op == 4:
        s['A'], s['F'] = ((v << 1) | (v >> 7)) & 0xFF, (f & 0xFE) | (v >> 7)
    elif op == 5:
        s['A'], s['F'] = ((v >> 1) | ((v & 1) << 7)) & 0xFF, (f & 0xFE) | (v & 1)
    elif op == 6:
        s['A'], s['F'] = ((v << 1) | cy) & 0xFF, (f & 0xFE) | (v >> 7)
    else:
        s['A'], s['F'] = ((v >> 1) | (cy << 7)) & 0xFF, (f & 0xFE) | (v & 1)
    return s


def g_dad(c):
    op, fi, hli, rpi = c
    hl, rp, f = W24[hli], W24[rpi], F7[fi]
    s = new_state(0xA1, f, rp >> 8, rp & 0xFF, rp >> 8, rp & 0xFF, hl >> 8, hl & 0xFF, 0x6D, 0x92)
    kind, rr = divmod(op, 3)                      # 0 DAD, 1 INX, 2 DCX ; rr: 0 BC 1 DE 2 HL
    hi, lo = [('B', 'C'), ('D', 'E'), ('H', 'L')][rr]
    if kind == 0:
        t = pair(s, 'H', 'L') + pair(s, hi, lo)
        setpair(s, 'H', 'L', t)
        s['F'] = (f & 0xFE) | (FC if t > 0xFFFF else 0)
    elif kind == 1:
        setpair(s, hi, lo, pair(s, hi, lo) + 1)
    else:
        setpair(s, hi, lo, pair(s, hi, lo) - 1)
    return s


def g_mov(c):
    i, fi = c
    f = F2[fi]
    s = base(0xA1, f)
    op = 0x40 + i + (1 if i >= 0x36 else 0)
    setr(s, (op >> 3) & 7, getr(s, op & 7))
    return s


def g_mvi(c):
    r, fi, ni = c
    s = base(0xA1, F2[fi])
    setr(s, r, V16[ni])
    return s


def g_lxi(c):
    op, fi, wi = c
    s = base(0xA1, F2[fi])
    hi, lo = [('B', 'C'), ('D', 'E'), ('H', 'L')][op]
    setpair(s, hi, lo, W24[wi])
    return s


GROUPS = [('alu', g_alu), ('imm', g_imm), ('incdec', g_incdec), ('acc', g_acc), ('dad', g_dad),
          ('mov', g_mov), ('mvi', g_mvi), ('lxi', g_lxi)]


def hexb(xs):
    return ",".join("0x%02X" % x for x in xs)


def emit():
    out = ["; WYGENEROWANE przez tools/model.py - nie edytuj recznie.", ""]
    out += ["tab_v16: db " + hexb(V16), "tab_f2:  db " + hexb(F2), "tab_f7:  db " + hexb(F7)]
    out += ["tab_w24: dw " + ",".join("0x%04X" % w for w in W24)]
    out += ["tab_alu_ops: db " + hexb(ALU_OPS), "tab_imm_ops: db " + hexb(IMM_OPS),
            "tab_incdec:  db " + hexb(INCDEC_BASE), "tab_acc_ops: db " + hexb(ACC_OPS),
            "tab_dad_ops: db " + hexb(DAD_OPS), "tab_lxi_ops: db " + hexb(LXI_OPS), ""]
    for i in range(4):
        out.append("tab_crc%d: db %s" % (i, hexb([(c >> (8 * i)) & 0xFF for c in CRC_T])))
    out.append("")
    total = 0
    for name, fn in GROUPS:
        d = DIMS[name]
        n = 1
        for x in d:
            n *= x
        total += n
        crc = run_group(d, fn)
        out.append("dims_%s: db %s" % (name, hexb([len(d)] + d)))
        out.append("exp_%s:  db %s    ; CRC-32 = 0x%08X, %d przypadkow" % (name, hexb([(crc >> (8 * i)) & 0xFF for i in range(4)]), crc, n))
    out.append("; razem przypadkow sumowanych: %d" % total)
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    text = emit()
    if len(sys.argv) >= 3 and sys.argv[1] == "--emit":
        open(sys.argv[2], "w", newline="\n").write(text)
        print("zapisano", sys.argv[2])
    elif len(sys.argv) >= 3 and sys.argv[1] == "--check":
        same = open(sys.argv[2]).read() == text
        print("zgodne" if same else "ROZNE")
        sys.exit(0 if same else 1)
    else:
        sys.stdout.write(text)
