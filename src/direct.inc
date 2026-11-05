; Testy bezposrednie - kazdy sprawdza jedno zachowanie z dokumentacji Intel 8080.
; Porazka: wypisanie " [Txx " i zwiekszenie liczników. Numery testow sa stale.

g_direct:
        lxi h,0
        dad sp
        shld saved_sp
        lxi h,name_direct
        call puts
        xra a
        sta dfails

; T01 PUSH/POP BC,DE,HL: kolejnosc bajtow na stosie (mlodszy pod nizszym adresem) i odtworzenie.
        lxi sp,dstack_top
        lxi b,0x1234
        lxi d,0x5678
        lxi h,0x9ABC
        push b
        push d
        push h
        lxi h,0
        dad sp
        mov a,m
        cpi 0xBC
        jnz t01f
        inx h
        mov a,m
        cpi 0x9A
        jnz t01f
        pop h
        pop d
        pop b
        mov a,h
        cpi 0x9A
        jnz t01f
        mov a,l
        cpi 0xBC
        jnz t01f
        mov a,d
        cpi 0x56
        jnz t01f
        mov a,e
        cpi 0x78
        jnz t01f
        mov a,b
        cpi 0x12
        jnz t01f
        mov a,c
        cpi 0x34
        jz t02
t01f:   lxi sp,dstack_top
        mvi a,0x01
        call dfail

; T02 PUSH PSW/POP PSW: obraz flag SZ0A0P1C; bity 1=1, 3=0, 5=0 niezaleznie od zawartosci stosu.
t02:    lxi sp,dstack_top
        lxi h,0x5AFF
        push h
        pop psw
        push psw
        pop h
        mov a,h
        cpi 0x5A
        jnz t02f
        mov a,l
        IFDEF I8085
        ani 0xD5
        cpi 0xD5
        ELSE
        cpi 0xD7
        ENDIF
        jz t03
t02f:   lxi sp,dstack_top
        mvi a,0x02
        call dfail

; T03 XTHL: wymiana HL z wierzcholkiem stosu.
t03:    lxi sp,dstack_top
        lxi h,0x1122
        push h
        lxi h,0x3344
        xthl
        mov a,h
        cpi 0x11
        jnz t03f
        mov a,l
        cpi 0x22
        jnz t03f
        pop h
        mov a,h
        cpi 0x33
        jnz t03f
        mov a,l
        cpi 0x44
        jz t04
t03f:   lxi sp,dstack_top
        mvi a,0x03
        call dfail

; T04 SPHL, INX SP, DCX SP, DAD SP.
t04:    lxi h,0x7000
        sphl
        inx sp
        inx sp
        dcx sp
        lxi h,0
        dad sp
        lxi sp,dstack_top
        mov a,h
        cpi 0x70
        jnz t04f
        mov a,l
        cpi 0x01
        jnz t04f
        lxi h,1
        lxi sp,0xFFFF
        dad sp
        lxi sp,dstack_top
        jnc t04f
        mov a,h
        ora l
        jz t05
t04f:   lxi sp,dstack_top
        mvi a,0x04
        call dfail

; T05 PCHL: skok pod adres z HL.
t05:    lxi h,t05_ok
        pchl
        mvi a,0x05
        call dfail
        jmp t06
t05_ok:

; T06 LDAX/STAX B i D, LDA/STA, LHLD/SHLD (kolejnosc bajtow).
t06:    lxi h,SCRATCH+16
        mvi m,0x11
        lxi b,SCRATCH+16
        ldax b
        cpi 0x11
        jnz t06f
        lxi d,SCRATCH+17
        mvi a,0x22
        stax d
        lda SCRATCH+17
        cpi 0x22
        jnz t06f
        mvi a,0x33
        stax b
        lda SCRATCH+16
        cpi 0x33
        jnz t06f
        mvi a,0x44
        sta SCRATCH+18
        ldax d
        inx d
        lda SCRATCH+18
        cpi 0x44
        jnz t06f
        lxi h,0xABCD
        shld SCRATCH+20
        lda SCRATCH+20
        cpi 0xCD
        jnz t06f
        lda SCRATCH+21
        cpi 0xAB
        jnz t06f
        lhld SCRATCH+20
        mov a,h
        cpi 0xAB
        jnz t06f
        mov a,l
        cpi 0xCD
        jz t07
t06f:   mvi a,0x06
        call dfail

; T07 XCHG i NOP (rejestry i flagi bez zmian).
t07:    lxi h,0x1357
        lxi d,0x2468
        xchg
        nop
        mov a,h
        cpi 0x24
        jnz t07f
        mov a,l
        cpi 0x68
        jnz t07f
        mov a,d
        cpi 0x13
        jnz t07f
        mov a,e
        cpi 0x57
        jz t08
t07f:   mvi a,0x07
        call dfail

; T08 CALL/RET oraz zagniezdzenie.
t08:    lxi sp,dstack_top
        xra a
        call t08_a
        cpi 0x03
        jz t09
        lxi sp,dstack_top
        mvi a,0x08
        call dfail
        jmp t09
t08_a:  inr a
        call t08_b
        inr a
        ret
t08_b:  inr a
        ret

; T09 RST 1..7 (wektory pod adresami 8*n): tymczasowo wstawiamy "mvi a,n / ret", przywracamy bajty.
t09:    lxi sp,dstack_top
        mvi b,1
t09_l:  call t09_addr
        mov a,m
        sta rsave
        inx h
        mov a,m
        sta rsave+1
        inx h
        mov a,m
        sta rsave+2
        call t09_addr
        mvi m,0x3E
        inx h
        mov m,b
        inx h
        mvi m,0xC9
        mov a,b
        add a
        add a
        add a
        ori 0xC7
        sta t09_op
        xra a
t09_op: nop
        sub b
        sta rres
        call t09_addr
        lda rsave
        mov m,a
        inx h
        lda rsave+1
        mov m,a
        inx h
        lda rsave+2
        mov m,a
        lda rres
        ora a
        jz t09_n
        mvi a,0x09
        call dfail
t09_n:  mov a,b
        inr a
        mov b,a
        cpi 8
        jc t09_l
        jmp t10
t09_addr:
        mov a,b
        add a
        add a
        add a
        mov l,a
        mvi h,0
        ret

; T10 Jcc, CALLcc, RETcc: wszystkie 8 warunkow, kazdy w 4 stanach flag: wszystkie zerowe (F=02h),
; tylko flaga warunku, wszystkie poza flaga warunku, wszystkie ustawione (F=D7h). Dzieki temu
; instrukcja czytajaca zla flage jest wykrywana. Dodatkowo sprawdzane: SP po operacji oraz adres
; powrotu zapisany przez CALLcc. Warunki parzyste (NZ,NC,PO,P) wykonuja sie przy fladze zerowej,
; nieparzyste (Z,C,PE,M) przy fladze ustawionej.
t10:    xra a
        sta tc
t10_c:  lda tc
        mov e,a
        mvi d,0
        lxi h,tab_cc_jmp
        dad d
        mov a,m
        sta t10_jop
        lxi h,tab_cc_call
        dad d
        mov a,m
        sta t10_cop
        lxi h,tab_cc_ret
        dad d
        mov a,m
        sta t10_rop
        lxi h,tab_cc_mask
        dad d
        mov a,m
        sta tmask
        xra a
        sta tf
t10_f:  lda tf
        ora a
        mvi a,0x02
        jz t10_fs
        lda tf
        cpi 1
        jnz t10_f2
        lda tmask
        ori 0x02
        jmp t10_fs
t10_f2: cpi 2
        jnz t10_f3
        lda tmask
        cma
        ani 0xD7
        ori 0x02
        jmp t10_fs
t10_f3: mvi a,0xD7
t10_fs: mov l,a
        mvi h,0
        shld tflag
        lda tc
        ani 1
        mov b,a
        lda tf
        ani 1
        xra b
        xri 1
        ani 1
        sta texp
        ; --- Jcc
        xra a
        sta tdet
        lxi sp,dstack_top
        lhld tflag
        push h
        pop psw
t10_jop: nop
        dw t10_jt
        jmp t10_jn
t10_jt: mvi a,1
        sta tdet
t10_jn: lda tdet
        mov b,a
        lda texp
        cmp b
        jz t10_c1
        mvi a,0x10
        call dfail
t10_c1: lxi h,0
        dad sp
        lxi d,dstack_top
        call eq16
        jz t10_c2
        mvi a,0x13
        call dfail
        ; --- CALLcc
t10_c2: xra a
        sta tdet
        lxi sp,dstack_top
        lhld tflag
        push h
        pop psw
t10_cop: nop
        dw t10_ct
t10_cnt:
        lxi h,0
        dad sp
        shld tsp
        jmp t10_cn
t10_ct: mvi a,1
        sta tdet
        lxi h,0
        dad sp
        shld tsp
        mov e,m
        inx h
        mov d,m
        xchg
        shld tret
t10_cn: lxi sp,dstack_top
        lda tdet
        mov b,a
        lda texp
        cmp b
        jz t10_c3
        mvi a,0x11
        call dfail
t10_c3: lda texp
        ora a
        lxi h,dstack_top
        jz t10_c4
        lxi h,dstack_top-2
t10_c4: xchg
        lhld tsp
        call eq16
        jz t10_c5
        mvi a,0x14
        call dfail
t10_c5: lda texp
        ora a
        jz t10_r1
        lhld tret
        lxi d,t10_cnt
        call eq16
        jz t10_r1
        mvi a,0x15
        call dfail
        ; --- RETcc: adres powrotu t10_rt lezy na stosie, ustawia tdet
t10_r1: xra a
        sta tdet
        lxi sp,dstack_top
        lxi h,t10_rt
        push h
        lhld tflag
        push h
        pop psw
t10_rop: nop
        lxi h,0
        dad sp
        shld tsp
        jmp t10_rn
t10_rt: mvi a,1
        sta tdet
        lxi h,0
        dad sp
        shld tsp
t10_rn: lxi sp,dstack_top
        lda tdet
        mov b,a
        lda texp
        cmp b
        jz t10_r2
        mvi a,0x12
        call dfail
t10_r2: lda texp
        ora a
        lxi h,dstack_top-2
        jz t10_r3
        lxi h,dstack_top
t10_r3: xchg
        lhld tsp
        call eq16
        jz t10_nx
        mvi a,0x16
        call dfail
t10_nx: lda tf
        inr a
        sta tf
        cpi 4
        jc t10_f
        lda tc
        inr a
        sta tc
        cpi 8
        jc t10_c

; T13 JMP bezwarunkowy omija kod; T14 CALL/RET nie zmienia flag.
t13:    lxi sp,dstack_top
        jmp t13_a
        mvi a,0x17
        call dfail
        jmp t13_z
t13_a:  nop
t13_z:  lxi h,0x00D7
        push h
        pop psw
        call t13_sub
        push psw
        pop h
        mov a,l
        IFDEF I8085
        ani 0xD5
        cpi 0xD5
        ELSE
        cpi 0xD7
        ENDIF
        jz t13_ok
        mvi a,0x18
        call dfail
t13_ok: jmp t13_end
t13_sub:
        ret
t13_end:

; eq16: porownanie HL z DE; Z = rowne.
        jmp eq16_skip
eq16:   mov a,h
        cmp d
        rnz
        mov a,l
        cmp e
        ret
eq16_skip:


        IFDEF I8085
; T19 RIM/SIM (tylko 8085): SIM z MSE (bit 3) ustawia maski M7.5,M6.5,M5.5 (bity 2..0), RIM je zwraca
; w bitach 2..0; SIM bez MSE masek nie zmienia. Na koncu maski sa zerowane.
t19:    lxi sp,dstack_top
        mvi a,0x0F
        sim
        rim
        ani 0x07
        cpi 0x07
        jnz t19f
        mvi a,0x0A
        sim
        rim
        ani 0x07
        cpi 0x02
        jnz t19f
        mvi a,0x05
        sim
        rim
        ani 0x07
        cpi 0x02
        jnz t19f
        mvi a,0x0C
        sim
        rim
        ani 0x07
        cpi 0x04
        jnz t19f
        mvi a,0x08
        sim
        rim
        ani 0x07
        jz t19ok
t19f:   mvi a,0x19
        call dfail
t19ok:  mvi a,0x08
        sim
        ENDIF

        lhld saved_sp
        sphl
        lda dfails
        ora a
        jnz gd_fail
        lxi h,msg_ok
        jmp puts
gd_fail:
        lxi h,msg_nl
        jmp puts

; dfail: A = numer testu; drukuje " [Txx " i zwieksza liczniki.
dfail:  push psw
        lxi h,msg_t
        call puts
        pop psw
        call puthex8
        mvi a,0x5D
        call putc
        lda fails
        inr a
        sta fails
        lda dfails
        inr a
        sta dfails
        ret

saved_sp: dw 0
dstack: defs 128
dstack_top:
tc:     db 0
tf:     db 0
texp:   db 0
tdet:   db 0
tflag:  dw 0
tmask:  db 0
tsp:    dw 0
tret:   dw 0
rsave:  db 0,0,0
rres:   db 0
tab_cc_jmp:  db 0xC2,0xCA,0xD2,0xDA,0xE2,0xEA,0xF2,0xFA
tab_cc_call: db 0xC4,0xCC,0xD4,0xDC,0xE4,0xEC,0xF4,0xFC
tab_cc_ret:  db 0xC0,0xC8,0xD0,0xD8,0xE0,0xE8,0xF0,0xF8
tab_cc_mask: db 0x40,0x40,0x01,0x01,0x04,0x04,0x80,0x80
