; DIAG8080 - samosprawdzajacy test diagnostyczny procesora Intel 8080 (CP/M, plik .COM pod 0100h).
;
; MIT License. Copyright (c) 2026 Przemyslaw Rachwal. Zob. LICENSE.
; Napisany od podstaw na podstawie dokumentacji Intel 8080; nie zawiera kodu ani danych z innych
; programow testowych. Oczekiwane wyniki sa liczone przez niezalezny model (tools/model.py).
;
; Zasada dzialania: dla kazdego przypadku (instrukcja + stan poczatkowy rejestrow i flag) program
; wykonuje instrukcje, zbiera A,F,B,C,D,E,H,L oraz 2 bajty pamieci i dolicza je do sumy kontrolnej
; (CRC-32 z tablicami z generated.inc). Na koniec grupy porownuje sume z wartoscia z modelu.
; Wydruk: "<grupa> OK" albo "<grupa> FAIL got=<crc> exp=<crc>". Testy bezposrednie (stos, skoki,
; RST, pamiec) maja numery Txx.
;
; Budowanie: z80asm -m8080 (z88dk). Wariant -DRAW zamienia wyjscie BDOS na OUT 80h (do emulatorow
; bez CP/M).

        org 0x100

        defc SCRATCH = 0x8000

start:  lxi sp,stack_top
        xra a
        sta fails
        lxi h,msg_banner
        call puts

        call g_alu
        call g_imm
        call g_incdec
        call g_acc
        call g_dad
        call g_mov
        call g_mvi
        call g_lxi
        call g_ralu
        call g_rdad
        call g_direct

        lda fails
        ora a
        jnz failed
        lxi h,msg_pass
        call puts
        jmp finish
failed: lxi h,msg_fail
        call puts
finish:
        IFDEF RAW
done:   jmp done
        ELSE
        jmp 0
        ENDIF

; ---------------------------------------------------------------------------------- wyjscie
; putc: A = znak; zachowuje wszystkie rejestry.
putc:
        IFDEF RAW
        out 0x80
        ret
        ELSE
        push psw
        push b
        push d
        push h
        mov e,a
        mvi c,2
        call 5
        pop h
        pop d
        pop b
        pop psw
        ret
        ENDIF

puts:   mov a,m
        ora a
        rz
        call putc
        inx h
        jmp puts

puthex8:
        push psw
        rrc
        rrc
        rrc
        rrc
        call hexdig
        pop psw
hexdig: ani 0x0F
        adi 0x30
        cpi 0x3A
        jc hd_out
        adi 7
hd_out: jmp putc

puthex16:
        mov a,h
        call puthex8
        mov a,l
        jmp puthex8

; ---------------------------------------------------------------------------------- tabele
; tbl8: HL = baza, A = indeks -> A = bajt. Zmienia D, E, HL.
tbl8:   mov e,a
        mvi d,0
        dad d
        mov a,m
        ret

; tbl16: HL = baza, A = indeks (< 128) -> HL = slowo. Zmienia A, D, E.
tbl16:  add a
        mov e,a
        mvi d,0
        dad d
        mov e,m
        inx h
        mov d,m
        xchg
        ret

; ---------------------------------------------------------------------------------- suma kontrolna
crc_init:
        lxi h,crc
        mvi m,0xFF
        inx h
        mvi m,0xFF
        inx h
        mvi m,0xFF
        inx h
        mvi m,0xFF
        ret

; fold: A = bajt; crc = (crc >> 8) ^ T[(crc ^ A) & 0xFF] (CRC-32, wielomian EDB88320h, tablice
; tab_crc0..3 = kolejne bajty wpisow tablicy). Zachowuje wszystko.
fold:   push psw
        push b
        push d
        push h
        lxi h,crc
        xra m
        mov e,a
        mvi d,0
        lxi h,tab_crc0
        dad d
        mov b,m
        lda crc+1
        xra b
        sta crc
        lxi h,tab_crc1
        dad d
        mov b,m
        lda crc+2
        xra b
        sta crc+1
        lxi h,tab_crc2
        dad d
        mov b,m
        lda crc+3
        xra b
        sta crc+2
        lxi h,tab_crc3
        dad d
        mov a,m
        sta crc+3
        pop h
        pop d
        pop b
        pop psw
        ret

fold_all:
        IFDEF TRACE
        call dump_case
        ENDIF
        lda out_af+1
        call fold
        lda out_af
        call fold
        lda out_bc+1
        call fold
        lda out_bc
        call fold
        lda out_de+1
        call fold
        lda out_de
        call fold
        lda out_hl+1
        call fold
        lda out_hl
        call fold
        lda SCRATCH
        call fold
        lda SCRATCH+1
        jmp fold

        IFDEF TRACE
; dump_case (tylko -DTRACE): jedna linia z dziesiecioma bajtami wyniku w hex.
dump_case:
        push psw
        push h
        lhld out_af
        mov a,h
        call puthex8
        mov a,l
        call puthex8
        lhld out_bc
        call puthex16
        lhld out_de
        call puthex16
        lhld out_hl
        call puthex16
        lda SCRATCH
        call puthex8
        lda SCRATCH+1
        call puthex8
        mvi a,10
        call putc
        pop h
        pop psw
        ret
        ENDIF

; check_crc: HL = nazwa grupy (zakonczona zerem), DE = adres oczekiwanego CRC-32 (4 bajty, mlodszy pierwszy).
check_crc:
        xchg
        shld exp_ptr
        xchg
        call puts
        lhld exp_ptr
        xchg
        lxi h,crc
        mvi c,4
cc_cmp: ldax d
        cmp m
        jnz cc_bad
        inx d
        inx h
        dcr c
        jnz cc_cmp
        lxi h,msg_ok
        jmp puts
cc_bad: lxi h,msg_got
        call puts
        lxi h,crc+3
        call put_crc
        lxi h,msg_exp
        call puts
        lhld exp_ptr
        inx h
        inx h
        inx h
        call put_crc
        lxi h,msg_nl
        call puts
        lda fails
        inr a
        sta fails
        ret

; put_crc: HL = adres najstarszego bajtu; drukuje 4 bajty od najstarszego do najmlodszego (malejace adresy).
put_crc:
        mvi b,4
pc_l:   mov a,m
        call puthex8
        dcx h
        dcr b
        jnz pc_l
        ret

; ---------------------------------------------------------------------------------- licznik wielowymiarowy
; odo_init: HL = tablica [n, lim0, lim1, ...]; zeruje liczniki.
odo_init:
        mov a,m
        sta odo_n
        mov c,a
        inx h
        lxi d,odo_lim
oi_c:   mov a,m
        stax d
        inx h
        inx d
        dcr c
        jnz oi_c
        lxi h,odo_ctr
        mvi c,6
        xra a
oi_z:   mov m,a
        inx h
        dcr c
        jnz oi_z
        ret

; odo_next: zwieksza ostatni licznik z przeniesieniem; CY = 1, gdy wszystkie wymiary sie przewinely.
odo_next:
        lda odo_n
        mov c,a
        mvi b,0
odn_l:  dcr c
        jm odn_done
        lxi h,odo_ctr
        dad b
        mov a,m
        inr a
        mov m,a
        lxi h,odo_lim
        dad b
        cmp m
        jc odn_more
        lxi h,odo_ctr
        dad b
        mvi m,0
        jmp odn_l
odn_more:
        xra a
        ret
odn_done:
        stc
        ret

; ---------------------------------------------------------------------------------- wykonanie przypadku
; Wejscie: op0..op2 (instrukcja, uzupelniona zerami = NOP), in_af/in_bc/in_de/in_hl (slowo: mlodszy
; bajt = F, C, E, L), c_m0/c_m1 (pamiec SCRATCH, SCRATCH+1). Wyjscie: out_af/out_bc/out_de/out_hl.
run_case:
        lda op0
        sta ex_code
        lda op1
        sta ex_code+1
        lda op2
        sta ex_code+2
        lda c_m0
        sta SCRATCH
        lda c_m1
        sta SCRATCH+1
        lhld in_bc
        push h
        lhld in_de
        push h
        lhld in_af
        push h
        lhld in_hl
        pop psw
        pop d
        pop b
ex_code:
        nop
        nop
        nop
        push psw
        shld out_hl
        mov h,b
        mov l,c
        shld out_bc
        xchg
        shld out_de
        pop h
        shld out_af
        ret

; set_vstate: A = v -> B=C=D=E=v, HL=SCRATCH, pamiec = v, 92h.
set_vstate:
        mov h,a
        mov l,a
        shld in_bc
        shld in_de
        sta c_m0
        mvi a,0x92
        sta c_m1
        lxi h,SCRATCH
        shld in_hl
        ret

; set_base: stany staly B2C3 D4E5 SCRATCH, pamiec 6Dh 92h.
set_base:
        lxi h,0xB2C3
        shld in_bc
        lxi h,0xD4E5
        shld in_de
        lxi h,SCRATCH
        shld in_hl
        mvi a,0x6D
        sta c_m0
        mvi a,0x92
        sta c_m1
        ret

; clr_ops: op1 = op2 = 0.
clr_ops:
        xra a
        sta op1
        sta op2
        ret

; ---------------------------------------------------------------------------------- grupy
g_alu:  lxi h,dims_alu
        call odo_init
        call crc_init
ga_l:   lxi h,tab_alu_ops
        lda odo_ctr
        call tbl8
        mov b,a
        lda odo_ctr+1
        ora b
        sta op0
        call clr_ops
        lxi h,tab_v16
        lda odo_ctr+4
        call tbl8
        call set_vstate
        lxi h,tab_f2
        lda odo_ctr+2
        call tbl8
        sta c_f
        lxi h,tab_v16
        lda odo_ctr+3
        call tbl8
        mov h,a
        lda c_f
        mov l,a
        shld in_af
        call run_case
        call fold_all
        call odo_next
        jnc ga_l
        lxi h,name_alu
        lxi d,exp_alu
        jmp check_crc

g_imm:  lxi h,dims_imm
        call odo_init
        call crc_init
gi_l:   lxi h,tab_imm_ops
        lda odo_ctr
        call tbl8
        sta op0
        lxi h,tab_v16
        lda odo_ctr+3
        call tbl8
        sta op1
        xra a
        sta op2
        call set_base
        lxi h,tab_f2
        lda odo_ctr+1
        call tbl8
        sta c_f
        lxi h,tab_v16
        lda odo_ctr+2
        call tbl8
        mov h,a
        lda c_f
        mov l,a
        shld in_af
        call run_case
        call fold_all
        call odo_next
        jnc gi_l
        lxi h,name_imm
        lxi d,exp_imm
        jmp check_crc

g_incdec:
        lxi h,dims_incdec
        call odo_init
        call crc_init
gd_l:   lxi h,tab_incdec
        lda odo_ctr
        call tbl8
        mov b,a
        lda odo_ctr+1
        add a
        add a
        add a
        ora b
        sta op0
        call clr_ops
        call value_hi_lo
        call set_vstate
        lxi d,tab_f7
        lda odo_ctr+2
        call tbl8_de
        sta c_f
        lda c_v
        mov h,a
        lda c_f
        mov l,a
        shld in_af
        call run_case
        call fold_all
        call odo_next
        jnc gd_l
        lxi h,name_incdec
        lxi d,exp_incdec
        jmp check_crc

g_acc:  lxi h,dims_acc
        call odo_init
        call crc_init
gc_l:   lxi h,tab_acc_ops
        lda odo_ctr
        call tbl8
        sta op0
        call clr_ops
        call value_hi_lo_2
        call set_vstate
        lxi d,tab_f7
        lda odo_ctr+1
        call tbl8_de
        sta c_f
        lda c_v
        mov h,a
        lda c_f
        mov l,a
        shld in_af
        call run_case
        call fold_all
        call odo_next
        jnc gc_l
        lxi h,name_acc
        lxi d,exp_acc
        jmp check_crc

; value_hi_lo: c_v = (ctr3 << 4) | ctr4, A = c_v.   value_hi_lo_2: to samo dla ctr2, ctr3.
value_hi_lo:
        lda odo_ctr+3
        mov b,a
        lda odo_ctr+4
        jmp vhl_mix
value_hi_lo_2:
        lda odo_ctr+2
        mov b,a
        lda odo_ctr+3
vhl_mix:
        mov c,a
        mov a,b
        add a
        add a
        add a
        add a
        ora c
        sta c_v
        ret

; tbl8_de: DE = baza, A = indeks -> A. Zmienia H, L, D, E.
tbl8_de:
        xchg
        jmp tbl8

g_dad:  lxi h,dims_dad
        call odo_init
        call crc_init
gp_l:   lxi h,tab_dad_ops
        lda odo_ctr
        call tbl8
        sta op0
        call clr_ops
        lxi h,tab_w24
        lda odo_ctr+3
        call tbl16
        shld in_bc
        shld in_de
        lxi h,tab_w24
        lda odo_ctr+2
        call tbl16
        shld in_hl
        mvi a,0x6D
        sta c_m0
        mvi a,0x92
        sta c_m1
        lxi d,tab_f7
        lda odo_ctr+1
        call tbl8_de
        mov l,a
        mvi h,0xA1
        shld in_af
        call run_case
        call fold_all
        call odo_next
        jnc gp_l
        lxi h,name_dad
        lxi d,exp_dad
        jmp check_crc

g_mov:  lxi h,dims_mov
        call odo_init
        call crc_init
gm_l:   lda odo_ctr
        cpi 0x36
        jc gm_nb
        inr a
gm_nb:  adi 0x40
        sta op0
        call clr_ops
        call set_base
        lxi d,tab_f2
        lda odo_ctr+1
        call tbl8_de
        mov l,a
        mvi h,0xA1
        shld in_af
        call run_case
        call fold_all
        call odo_next
        jnc gm_l
        lxi h,name_mov
        lxi d,exp_mov
        jmp check_crc

g_mvi:  lxi h,dims_mvi
        call odo_init
        call crc_init
gv_l:   lda odo_ctr
        add a
        add a
        add a
        adi 0x06
        sta op0
        lxi h,tab_v16
        lda odo_ctr+2
        call tbl8
        sta op1
        xra a
        sta op2
        call set_base
        lxi d,tab_f2
        lda odo_ctr+1
        call tbl8_de
        mov l,a
        mvi h,0xA1
        shld in_af
        call run_case
        call fold_all
        call odo_next
        jnc gv_l
        lxi h,name_mvi
        lxi d,exp_mvi
        jmp check_crc

g_lxi:  lxi h,dims_lxi
        call odo_init
        call crc_init
gx_l:   lxi h,tab_lxi_ops
        lda odo_ctr
        call tbl8
        sta op0
        lxi h,tab_w24
        lda odo_ctr+2
        call tbl16
        mov a,l
        sta op1
        mov a,h
        sta op2
        call set_base
        lxi d,tab_f2
        lda odo_ctr+1
        call tbl8_de
        mov l,a
        mvi h,0xA1
        shld in_af
        call run_case
        call fold_all
        call odo_next
        jnc gx_l
        lxi h,name_lxi
        lxi d,exp_lxi
        jmp check_crc


; lfsr_next8: osiem krokow rejestru LFSR (Galois, wielomian B400h); zwraca HL = nowy stan.
lfsr_next8:
        lhld lfsr
        mvi b,8
lf_l:   mov a,h
        ora a
        rar
        mov h,a
        mov a,l
        rar
        mov l,a
        jnc lf_nx
        mov a,h
        xri 0xB4
        mov h,a
lf_nx:  dcr b
        jnz lf_l
        shld lfsr
        ret

; g_ralu: ALU na rejestrach B,C,D,E,H,L,A z losowymi (LFSR) wartosciami; H=L=B=C=D=E=b.
g_ralu: lxi h,dims_ralu
        call odo_init
        call crc_init
        lxi h,0xACE1
        shld lfsr
gr_l:   lxi h,tab_alu_ops
        lda odo_ctr
        call tbl8
        mov b,a
        lxi h,tab_r7
        lda odo_ctr+1
        call tbl8
        ora b
        sta op0
        call clr_ops
        lxi d,tab_f2
        lda odo_ctr+2
        call tbl8_de
        sta c_f
        call lfsr_next8
        shld c_x
        mov a,l
        mov h,a
        shld in_bc
        shld in_de
        shld in_hl
        mvi a,0x6D
        sta c_m0
        mvi a,0x92
        sta c_m1
        lda c_x+1
        mov h,a
        lda c_f
        mov l,a
        shld in_af
        call run_case
        call fold_all
        call odo_next
        jnc gr_l
        lxi h,name_ralu
        lxi d,exp_ralu
        jmp check_crc

; g_rdad: DAD B/D/H z losowymi 16-bitowymi HL i rp.
g_rdad: lxi h,dims_rdad
        call odo_init
        call crc_init
        lxi h,0xACE1
        shld lfsr
grd_l:  lxi h,tab_dad_ops
        lda odo_ctr
        call tbl8
        sta op0
        call clr_ops
        lxi d,tab_f7
        lda odo_ctr+1
        call tbl8_de
        sta c_f
        call lfsr_next8
        shld in_hl
        call lfsr_next8
        shld in_bc
        shld in_de
        mvi a,0x6D
        sta c_m0
        mvi a,0x92
        sta c_m1
        lda c_f
        mov l,a
        mvi h,0xA1
        shld in_af
        call run_case
        call fold_all
        call odo_next
        jnc grd_l
        lxi h,name_rdad
        lxi d,exp_rdad
        jmp check_crc

; ---------------------------------------------------------------------------------- testy bezposrednie
        include "direct.inc"

; ---------------------------------------------------------------------------------- dane
        include "generated.inc"

name_alu:    db "ALU reg (ADD ADC SUB SBB ANA XRA ORA CMP) ",0
name_imm:    db "ALU imm (ADI ACI SUI SBI ANI XRI ORI CPI) ",0
name_incdec: db "INR/DCR                                   ",0
name_acc:    db "DAA CMA STC CMC RLC RRC RAL RAR           ",0
name_dad:    db "DAD INX DCX (BC DE HL)                    ",0
name_mov:    db "MOV r,r'                                  ",0
name_mvi:    db "MVI r,n                                   ",0
name_lxi:    db "LXI rp,nn                                 ",0
name_ralu:   db "ALU reg, dane losowe (B C D E H L A)      ",0
name_rdad:   db "DAD B/D/H, dane losowe                    ",0
name_direct: db "Testy bezposrednie (stos, skoki, RST, pamiec)",0

msg_banner:  db "DIAG8080 - test procesora Intel 8080",13,10,0
msg_ok:      db "OK",13,10,0
msg_got:     db "FAIL got=",0
msg_exp:     db " exp=",0
msg_nl:      db 13,10,0
msg_pass:    db "WSZYSTKIE TESTY ZALICZONE",13,10,0
msg_fail:    db "TESTY NIEZALICZONE",13,10,0
msg_t:       db " [T",0

fails:       db 0
dfails:      db 0
odo_n:       db 0
odo_lim:     defs 6
odo_ctr:     defs 6
crc:         defs 4
lfsr:        dw 0
c_x:         dw 0
exp_ptr:     dw 0
op0:         db 0
op1:         db 0
op2:         db 0
c_f:         db 0
c_v:         db 0
c_m0:        db 0
c_m1:        db 0
in_af:       dw 0
in_bc:       dw 0
in_de:       dw 0
in_hl:       dw 0
out_af:      dw 0
out_bc:      dw 0
out_de:      dw 0
out_hl:      dw 0
tmp_w:       dw 0

stack:       defs 256
stack_top:
