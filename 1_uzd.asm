.MODEL small

.STACK 100h

.DATA
    ivesk		 DB 'Iveskite eilute zodziu, atskirtu tarpais:', 10, 13, '$'
	input		 DB 255, 0, 255 dup('$')
	newLine		 DB 10, 13, '$'
.CODE
Programa:
	mov AX, @data
	mov DS, AX
	
	DB 10001000b, 0ffh, 01h, 23h
	
	;Paprasoma ivesti eilute zodziu
	mov AH, 09h
	lea DX, ivesk
	int 21h
	
	;Ivedimas
	mov AH, 0Ah
	lea DX, input
	int 21h
	lea DX, newLine
	mov AH, 09h
	int 21h
	
	mov AH, 09h
	int 21h
	lea DX, newLine
	mov AH, 09h
	int 21h
	
	;Atskiru zodziu ilgiu radimas
	mov SI, 1
Ciklas:
	xor BL, BL
Zodis:
	inc SI
	cmp input[SI], 20h
	jz Print
	inc BL
	cmp input[SI], 0Dh
	jnz Zodis
	jmp Pabaiga
	
	;Spausdinamas raidziu skaicius zodyje
Print:
	mov AH, 02h
	add BL, 30h
	mov DL, BL
	int 21h
	mov DL, 20h
	int 21h
	jmp Ciklas
	
	;Uzbaigiama programa
Pabaiga:
	mov AH, 02h
	add BL, 2Fh
	mov DL, BL
	int 21h
	mov AH, 4Ch
	int 21h
END Programa