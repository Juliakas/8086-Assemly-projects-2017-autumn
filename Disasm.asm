.MODEL Huge
	MAX_LENGTH 		equ 255
	READ_ONLY   	equ 0
	NO_ATTRIBUTES 	equ 6
.STACK 100h
.DATA
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Input/Output;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
inputFile		db 'CODE.COM', 0			;Duomenu failo pavadinimas
outputFile		db 'Assembly.asm', 0		;Rezultato failo pavadinimas
inputHandle		dw ?						;Duomenu failo deskriptorius
outputHandle	dw ?						;Rezultatu failo deskriptorius
inputBuff		db 6 dup(0)					;Duomenys paimti is duomenu failo
bufferPointer   dw 6						;Rodykle rodanti i inputBuff masyva (kuri elementa apdorosime)
InstructionPtr	dw 100h						;IP
startingPtr		dw 0						;Ciklo pradzioje bufferPointer reiksme (=/= 0 tik tuo atveju, kai issenka duomenu failas)
baigesiFailas	db 0						;1 - Taip, 0 - Ne
duomSk			dw 6						;Kiek liko duomenu input buferyje (<6 tik tuo atveju, kai issenka duomenu failas)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Pagalbiniai masyvai;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ascii			db 5 dup(0)					;Masyvas, i kuri ByteGetAscii procedura talpina rezultatus
number			db 0						;Atminties vieta naudojama ivairiomis situacijomis
currentSeg		db 3 dup(0)
currentReg		db 3 dup(0)					;Dabartine registro israiska simboliais (kuria greiciausiai spausdinsime i rezultatu faila)
				db 10 dup(0)				;Paliekam vietos prefiksam
currentRm		db 27 dup(0)				;Dabartine registro/atminties israiska simboliais (kuria greiciausiai spausdinsime i rezultatu faila)
currentData		db 5 dup(0)					;Sesioliktainiai skaiciai isreiksti simboliai (Dazniausia naudojami betarpiskam operandui uzrasyti)
outputBuff		db 60 dup(0)				;Buferis, paruostas spausdinimui i rezultatu faila
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Papildomi kintamieji;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
wordBit			db ?						;w bito reiksme
directionBit	db ?						;d bito reiksme
signBit			db ?						;s bito reiksme
modValue		db ?						;mod reiksme
regValue		db ?						;reg reiksme
rmValue			db ?						;rm reiksme
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Irasymui;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
registerArray	db 'ALCLDLBLAHCHDHBHAXCXDXBXSPBPSIDI'
segmentArray	db 'ESCSSSDS'
memoryArray1	db 'BX + SIBX + DIBP + SIBP + DI'
memoryArray2	db '        SIDIBPBX'
bytePtr			db 'byte ptr '
wordPtr			db 'word ptr '
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Klaidu pranesimai;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
noInputFile		db 'Klaida: Nerastas duomenu failas$'
noOutputFile	db 'Klaida: Negalima sukurti rezultatu failo$'
illegalSymbol	db 'Klaida: Aptiktas neleistinas simbolis$'
;*******************************************************************************************************
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;CODE;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;*******************************************************************************************************
LOCALS @@
.CODE
	mov ax, @data
	mov ds, ax
	mov es, ax
	call FailuIniciavimas
	
Disasembleris:
	cmp baigesiFailas, 1
	je Neskaityti
	call Nuskaitymas
Neskaityti:
	mov si, bufferPointer
	mov startingPtr, si
	call SegmentuPrefiksai
	call OpkAtpazinimas
	call Rasymas
	call Isvalymas
	mov si, bufferPointer			;Siuo metu bufferPointer rodo i 
	add instructionPtr, si			;instructionPtr rodys i instrukcijos baita
	mov di, startingPtr
	sub instructionPtr, di
	cmp si, DuomSk					;Jeigu bufferPointer "uzbego uz akiu" duomenims (ju tiesiog nebeliko) 
	jb Disasembleris				;ir rodo i siuksle siuo momentu, tai reikia uzbaigti programa 

	
Pabaiga:
	mov ax, 4C00h
	int 21h
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Klaidu pranesimai;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	KlaidaIllegalSymbol:
	lea dx, illegalSymbol
	jmp KlaidaPrint
	KlaidaNoOutput:
	lea dx, noOutputFile
	jmp KlaidaPrint
	KlaidaNoInput:
	lea dx, noInputFile
	KlaidaPrint:
	mov ah, 09h
	int 21h
	jmp Pabaiga
;*******************************************************************************************************
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;PROCEDUROS;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;*******************************************************************************************************
FailuIniciavimas PROC
;Atidarome duomenu faila
	lea dx, inputFile
	mov al, READ_ONLY		;Tik skaitymui
	mov ah, 3Dh
	int 21h					;ax = file handle
	jnc @@NoError
	jmp KlaidaNoInput
@@NoError:
	mov inputHandle, ax
;Sukuriame rezultatu faila
	lea dx, outputFile
	mov ah, 3Ch
	mov cx, NO_ATTRIBUTES
	int 21h
	jnc @@NoError1
	jmp KlaidaNoOutput
@@NoError1:
	mov outputHandle, ax
	ret
FailuIniciavimas ENDP
;************************************************************************************************************
Nuskaitymas PROC
	mov cx, bufferPointer 			;(1-6)
	push cx
@@ciklas:
	mov dx, 5
	mov si, 0
	@@cikle:
		mov al, inputBuff[si + 1]
		mov inputBuff[si], al
		inc si
		dec dx
	jne @@cikle
loop @@ciklas
	pop cx
	mov dx, offset inputBuff
	add dx, 6
	sub dx, cx
	mov bx, inputHandle
	mov ah, 3Fh
	int 21h
	cmp ax, cx
	jnb @@poSkaitymo
	mov baigesiFailas, 1
	mov duomSk, ax
	sub duomSk, cx
	add duomSk, 6
	cmp duomSk, 0
	je Pabaiga
@@poSkaitymo:
	mov bufferPointer, 0
	ret
Nuskaitymas ENDP
;************************************************************************************************************
SegmentuPrefiksai PROC
	mov si, bufferPointer
	mov al, byte ptr inputBuff[si]
	cmp al, 26h
	jne @@notES
	inc bufferPointer
	mov currentSeg[0], 'E'
	mov currentSeg[1], 'S'
@@notES:
	cmp al, 2Eh
	jne @@notCS
	inc bufferPointer
	mov currentSeg[0], 'C'
	mov currentSeg[1], 'S'
@@notCS:
	cmp al, 36h
	jne @@notSS
	inc bufferPointer
	mov currentSeg[0], 'S'
	mov currentSeg[1], 'S'
@@notSS:
	cmp al, 3Eh
	jne @@notDS
	inc bufferPointer
	mov currentSeg[0], 'D'
	mov currentSeg[1], 'S'	
@@notDS:
	ret
SegmentuPrefiksai ENDP
;************************************************************************************************************
OpkAtpazinimas proc near
;and funkcija padeda atpazinti operacijos koda (vienetukai - konstantos, nuliukai kintantys bitai[d, w, r/m, reg...])
	mov si, bufferPointer
	mov ax, word ptr inputBuff[si]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Visi mov;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'M'
	mov outputBuff[21], 'O'
	mov outputBuff[22], 'V'
;mov 1 atvejis
	and al, 11111100b
	cmp al, 10001000b
	jne @@mov1
	call aritm1
	ret
@@mov1:
	mov ax, word ptr inputBuff[si]
;mov 2 atvejis
	and al, 11111110b
	cmp al, 11000110b
	jne @@mov2
	and ah, 00111000b
	cmp ah, 00000000b
	jne @@mov2
	call mov2
	ret
@@mov2:
	mov ax, word ptr inputBuff[si]
;mov 3 atvejis
	and al, 11110000b
	cmp al, 10110000b
	jne @@mov3
	call mov3
	ret
@@mov3:
	mov ax, word ptr inputBuff[si]
;mov 4, 5 atvejai
	and al, 11111100b
	cmp al, 10100000b
	jne @@mov45
	call mov45
	ret
@@mov45:
	mov ax, word ptr inputBuff[si]
;mov 6, 7 atvejai
	and al, 11111101b
	cmp al, 10001100b
	jne @@mov67
	and ah, 00100000b
	cmp ah, 00000000b
	jne @@mov67
	call mov67
	ret
@@mov67:
	mov ax, word ptr inputBuff[si]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Visi push;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'P'
	mov outputBuff[21], 'U'
	mov outputBuff[22], 'S'
	mov outputBuff[23], 'H'
;push 1 atvejis
	and al, 11111111b
	cmp al, 11111111b
	jne @@push1
	and ah, 00111000b
	cmp ah, 00110000b
	jne @@push1
	call pushPop1
	ret
@@push1:
	mov ax, word ptr inputBuff[si]
;push 2 atvejis
	and al, 11111000b
	cmp al, 01010000b
	jne @@push2
	call pushPop2
	ret
@@push2:
	mov ax, word ptr inputBuff[si]
;push 3 atvejis
	and al, 11100111b
	cmp al, 00000110b
	jne @@push3
	call pushPop3
	ret
@@push3:
	mov ax, word ptr inputBuff[si]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Visi pop;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'P'
	mov outputBuff[21], 'O'
	mov outputBuff[22], 'P'
	mov outputBuff[23], ' '
;pop 1 atvejis
	cmp al, 10001111b
	jne @@pop1
	and ah, 00111000b
	cmp ah, 00000000b
	jne @@pop1
	call pushPop1
	ret
@@pop1:
	mov ax, word ptr inputBuff[si]
;pop 2 atvejis
	and al, 11111000b
	cmp al, 01011000b
	jne @@pop2
	call pushPop2
	ret
@@pop2:
	mov ax, word ptr inputBuff[si]
;pop 3 atvejis
	and al, 11100111b
	cmp al, 00000111b
	jne @@pop3
	call pushPop3
	ret
@@pop3:
	mov ax, word ptr inputBuff[si]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Visi add;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'A'
	mov outputBuff[21], 'D'
	mov outputBuff[22], 'D'
;add 1 atvejis
	and al, 11111100b
	cmp al, 00000000b
	jne @@add1
	call aritm1
	ret
@@add1:
	mov ax, word ptr inputBuff[si]
;add 2 atvejis
	and al, 11111100b
	cmp al, 10000000b
	jne @@add2
	and ah, 00111000b
	cmp ah, 00000000b
	jne @@add2
	call aritm2
	ret
@@add2:
	mov ax, word ptr inputBuff[si]
;add 3 atvejis
	and al, 11111110b
	cmp al, 00000100b
	jne @@add3
	call aritm3
	ret
@@add3:
	mov ax, word ptr inputBuff[si]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Visi inc;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'I'
	mov outputBuff[21], 'N'
	mov outputBuff[22], 'C'
;inc 1 atvejis
	and al, 11111110b
	cmp al, 11111110b
	jne @@inc1
	and ah, 00111000b
	cmp ah, 00000000b
	jne @@inc1
	call pushPop1
	ret
@@inc1:
	mov ax, word ptr inputBuff[si]
;inc 2 atvejis
	and al, 11111000b
	cmp al, 01000000b
	jne @@inc2
	call pushPop2
	ret
@@inc2:
	mov ax, word ptr inputBuff[si]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Visi sub;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'S'
	mov outputBuff[21], 'U'
	mov outputBuff[22], 'B'	
;sub 1 atvejis
	and al, 11111100b
	cmp al, 00101000b
	jne @@sub1
	call aritm1
	ret
@@sub1:
	mov ax, word ptr inputBuff[si]
;sub 2 atvejis
	and al, 11111100b
	cmp al, 10000000b
	jne @@sub2
	and ah, 00111000b
	cmp ah, 00101000b
	jne @@sub2
	call aritm2
	ret
@@sub2:
	mov ax, word ptr inputBuff[si]
;sub 3 atvejis
	and al, 11111110b
	cmp al, 00101100b
	jne @@sub3
	call aritm3
	ret
@@sub3:
	mov ax, word ptr inputBuff[si]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Visi dec;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'D'
	mov outputBuff[21], 'E'
	mov outputBuff[22], 'C'
	mov outputBuff[23], ' '	
;dec 1 atvejis
	and al, 11111110b
	cmp al, 11111110b
	jne @@dec1
	and ah, 00111000b
	cmp ah, 00001000b
	jne @@dec1
	call pushPop1
	ret
@@dec1:
	mov ax, word ptr inputBuff[si]
;dec 2 atvejis
	and al, 11111000b
	cmp al, 01001000b
	jne @@dec2
	call pushPop2
	ret
@@dec2:
	mov ax, word ptr inputBuff[si]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Visi cmp;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'C'
	mov outputBuff[21], 'M'
	mov outputBuff[22], 'P'	
;cmp 1 atvejis
	and al, 11111100b
	cmp al, 00111000b
	jne @@cmp1
	call aritm1
	ret
@@cmp1:
	mov ax, word ptr inputBuff[si]
;cmp 2 atvejis
	and al, 11111100b
	cmp al, 10000000b
	jne @@cmp2
	and ah, 00111000b
	cmp ah, 00111000b
	jne @@cmp2
	call aritm2
	ret
@@cmp2:
	mov ax, word ptr inputBuff[si]
;cmp 3 atvejis
	and al, 11111110b
	cmp al, 00111100b
	jne @@cmp3
	call aritm3
	ret
@@cmp3:
	mov ax, word ptr inputBuff[si]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Visi and;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'A'
	mov outputBuff[21], 'N'
	mov outputBuff[22], 'D'	
;and 1 atvejis
	and al, 11111100b
	cmp al, 00100000b
	jne @@and1
	call aritm1
	ret
@@and1:
	mov ax, word ptr inputBuff[si]
;and 2 atvejis
	and al, 11111110b
	cmp al, 10000000b
	jne @@and2
	and ah, 00111000b
	cmp ah, 00100000b
	jne @@and2
	call aritm2
	ret
@@and2:
	mov ax, word ptr inputBuff[si]
;and 3 atvejis
	and al, 11111110b
	cmp al, 00100100b
	jne @@and3
	call aritm3
	ret
@@and3:
	mov ax, word ptr inputBuff[si]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Mul;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'M'
	mov outputBuff[21], 'U'
	mov outputBuff[22], 'L'
	mov outputBuff[23], ' '		
	and al, 11111110b
	cmp al, 11110110b
	jne @@mul
	and ah, 00111000b
	cmp ah, 00100000b
	jne @@mul
	call pushPop1
	ret
@@mul:
	mov ax, word ptr inputBuff[si]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Div;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'D'
	mov outputBuff[21], 'I'
	mov outputBuff[22], 'V'
	mov outputBuff[23], ' '
	and al, 11111110b
	cmp al, 11110110b
	jne @@div
	and ah, 00111000b
	cmp ah, 00110000b
	jne @@div
	call pushPop1
	ret
@@div:
	mov ax, word ptr inputBuff[si]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Visi call;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'C'
	mov outputBuff[21], 'A'
	mov outputBuff[22], 'L'
	mov outputBuff[23], 'L'
;call 1 atvejis
	cmp al, 11101000b
	jne @@call1
	mov wordBit, 1
	call callJmp1
	ret
@@call1:
;call 2 atvejis
	cmp al, 11111111b
	jne @@call2
	and ah, 00111000b
	cmp ah, 00010000b
	jne @@call2
	call pushPop1
	ret
@@call2:
	mov ax, word ptr inputBuff[si]
;call 3 atvejis
	cmp al, 10011010b
	jne @@call3
	call callJmp2
	ret
@@call3:
;call 4 atvejis
	cmp al, 11111111b
	jne @@call4
	and ah, 00111000b
	cmp ah, 00011000b
	jne @@call4
	call callJmp3
	ret
@@call4:
	mov ax, word ptr inputBuff[si]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Visi jmp;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'J'
	mov outputBuff[21], 'M'
	mov outputBuff[22], 'P'
	mov outputBuff[23], ' '
;jmp 1 atvejis
	cmp al, 11101001b
	jne @@jmp1
	mov wordBit, 1
	call callJmp1
	ret
@@jmp1:
;jmp 2 atvejis
	cmp al, 11101011b
	jne @@jmp2
	mov wordBit, 0
	call callJmp1
	ret
@@jmp2:
;jmp 3 atvejis
	cmp al, 11111111b
	jne @@jmp3
	and ah, 00111000b
	cmp ah, 00100000b
	jne @@jmp3
	call pushPop1
	ret
@@jmp3:
	mov ax, word ptr inputBuff[si]
;jmp 4 atvejis
	cmp al, 11101010b
	jne @@jmp4
	call callJmp2
	ret
@@jmp4:
;jmp 5 atvejis
	cmp al, 11111111b
	jne @@jmp5
	and ah, 00111000b
	cmp ah, 00101000b
	jne @@jmp5
	call callJmp3
	ret
@@jmp5:
	mov ax, word ptr inputBuff[si]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Visi ret;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'R'
	mov outputBuff[21], 'E'
	mov outputBuff[22], 'T'
	mov outputBuff[23], ' '
;ret 1 atvejis
	cmp al, 11000011b
	jne @@ret1
	inc bufferPointer
	call CreateOutput1
	mov outputBuff[23], 10
	ret
@@ret1:
;ret 2 atvejis
	cmp al, 11000010b
	jne @@ret2
	mov wordBit, 1
	call IntRet
	ret
@@ret2:
;ret 3 atvejis
	mov outputBuff[20], 'R'
	mov outputBuff[21], 'E'
	mov outputBuff[22], 'T'
	mov outputBuff[23], 'F'
	cmp al, 11001011b
	jne @@ret3
	inc bufferPointer
	call CreateOutput1
	mov outputBuff[24], 10
	ret
@@ret3:
;ret 4 atvejis
	cmp al, 11001010b
	jne @@ret4
	mov wordBit, 1
	call IntRet
	ret
@@ret4:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Visi j**;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'J'
	mov outputBuff[23], 0
	mov wordBit, 0
;je atvejis
	cmp al, 01110100b
	jne @@je
	mov outputBuff[21], 'E'
	mov outputBuff[22], ' '
	call callJmp1
	ret
@@je:
;jl atvejis
	cmp al, 01111100b
	jne @@jl
	mov outputBuff[21], 'L'
	mov outputBuff[22], ' '
	call callJmp1
	ret
@@jl:
;jle atvejis
	cmp al, 01111110b
	jne @@jle
	mov outputBuff[21], 'L'
	mov outputBuff[22], 'E'
	call callJmp1
	ret
@@jle:
;jb atvejis
	cmp al, 01110010b
	jne @@jb
	mov outputBuff[21], 'L'
	mov outputBuff[22], ' '
	call callJmp1
	ret
@@jb:
;jbe atvejis
	cmp al, 01110110b
	jne @@jbe
	mov outputBuff[21], 'B'
	mov outputBuff[22], 'E'
	call callJmp1
	ret
@@jbe:
;jp atvejis
	cmp al, 01111010b
	jne @@jp
	mov outputBuff[21], 'P'
	mov outputBuff[22], ' '
	call callJmp1
	ret
@@jp:
;jo atvejis
	cmp al, 01110000b
	jne @@jo
	mov outputBuff[21], 'O'
	mov outputBuff[22], ' '
	call callJmp1
	ret
@@jo:
;js atvejis
	cmp al, 01111000b
	jne @@js
	mov outputBuff[21], 'S'
	mov outputBuff[22], ' '
	call callJmp1
	ret
@@js:
;jne atvejis
	cmp al, 01110101b
	jne @@jne
	mov outputBuff[21], 'N'
	mov outputBuff[22], 'E'
	call callJmp1
	ret
@@jne:
;jge atvejis
	cmp al, 01111101b
	jne @@jge
	mov outputBuff[21], 'G'
	mov outputBuff[22], 'E'
	call callJmp1
	ret
@@jge:
;jg atvejis
	cmp al, 01111111b
	jne @@jg
	mov outputBuff[21], 'G'
	mov outputBuff[22], ' '
	call callJmp1
	ret
@@jg:
;jae atvejis
	cmp al, 01110011b
	jne @@jae
	mov outputBuff[21], 'A'
	mov outputBuff[22], 'E'
	call callJmp1
	ret
@@jae:
;ja atvejis
	cmp al, 01110111b
	jne @@ja
	mov outputBuff[21], 'A'
	mov outputBuff[22], ' '
	call callJmp1
	ret
@@ja:
;jnp atvejis
	cmp al, 01111011b
	jne @@jnp
	mov outputBuff[21], 'N'
	mov outputBuff[22], 'P'
	call callJmp1
	ret
@@jnp:
;jno atvejis
	cmp al, 01110001b
	jne @@jno
	mov outputBuff[21], 'N'
	mov outputBuff[22], 'O'
	call callJmp1
	ret
@@jno:
;jns atvejis
	cmp al, 01111001b
	jne @@jns
	mov outputBuff[21], 'N'
	mov outputBuff[22], 'S'
	call callJmp1
	ret
@@jns:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Loop;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	cmp al, 11100010b
	jne @@loop
	mov outputBuff[20], 'L'
	mov outputBuff[21], 'O'
	mov outputBuff[22], 'O'
	mov outputBuff[23], 'P'
	mov wordBit, 0
	call callJmp1
	ret
@@loop:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Int;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov outputBuff[20], 'I'
	mov outputBuff[21], 'N'
	mov outputBuff[22], 'T'
	mov outputBuff[23], ' '
;int **h
	cmp al, 11001101b
	jne @@int
	mov wordBit, 0
	call IntRet
	ret
@@int:
;int 03h
	cmp al, 11001100b
	jne @@int3
	inc bufferPointer
	call CreateOutput1
	mov word ptr currentData, '30'
	lea di, currentData
	mov si, 0
	mov bx, 24
	call CreateOutput2
	ret
@@int3:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	call neatpazintasOPK
	ret
OpkAtpazinimas ENDP
;************************************************************************************************************
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;VISU KOMANDU ATVEJAI;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;************************************************************************************************************
neatpazintasOPK PROC
	mov outputBuff[20], 'D'
	mov outputBuff[21], 'B'
	mov wordBit, 0
	call GetData
	call CreateOutput1
	mov bx, 22
	mov si, 0
	lea di, currentData
	call CreateOutput2
	ret
neatpazintasOPK ENDP
;************************************************************************************************************
;************************************************************************************************************
aritm1 PROC		;Naudojamas MOV, ADD, SUB ir CMP pirmiems atvejams
;Register <--> Register/Memory
	call GetBitVariables	;Issifruojame bitus i d, w, mod, reg ir r/m reiksmes
	call GetRegister		;Gaunamas registro operandas
	call GetRm				;Gaunamas r/m operandas
	call CreateOutput1		;Irasoma IP reiksme ir naudojami baitai komandoje
	mov bx, 23
	cmp directionBit, 1
	je @@direction
	lea si, currentReg
	lea di, currentRm
	call createOutput2
	ret
@@direction:
	lea si, currentRm
	lea di, currentReg
	call CreateOutput2		;Sukuriamas output bufferis
	ret
aritm1 ENDP
;************************************************************************************************************
mov2 PROC
;Register/Memory <-- Immediate
	call GetBitVariables
	call GetRm
	call GetData
	call CreateOutput1
	mov bx, 23
	lea si, currentData
	lea di, currentRm
	call CreateOutput2
	ret
mov2 ENDP
;************************************************************************************************************
mov3 PROC
;Register <-- Immediate
	mov si, bufferPointer
	mov ax, word ptr inputBuff[si]
	and al, 00001000b
	shr al, 3
	mov wordBit, al
	mov ax, word ptr inputBuff[si]
	and al, 00000111b
	mov regValue, al
	inc bufferPointer
	call GetRegister
	call GetData
	call CreateOutput1
	mov bx, 23
	lea si, currentData
	lea di, currentReg
	call createOutput2
	ret
mov3 ENDP
;************************************************************************************************************
mov45 PROC
;Memory <--> Accumulator (AX/AL)
	call GetBitVariables				;tik w ir d atitinka prasme ir mums yra aktualus
	dec bufferPointer					;GetBitVariables vienu per daug padidino
	mov regValue, 0
	call GetRegister
	mov modValue, 00b
	mov rmValue, 110b
	call GetRm
	call CreateOutput1
	mov bx, 23
	cmp directionBit, 1
	je @@direction
	lea si, currentRm
	lea di, currentReg
@@direction:
	lea si, currentReg
	lea di, currentRm
	call CreateOutput2
	ret
mov45 ENDP
;************************************************************************************************************
mov67 PROC
;Register/Memory <--> Segment Register
	call GetBitVariables
	mov wordBit, 1
	call GetSegment
	call GetRm
	call CreateOutput1
	cmp directionBit, 1
	je @@direction
	lea si, currentReg
	lea di, currentRm
@@direction:
	lea si, currentRm
	lea di, currentReg
	mov bx, 23
	call CreateOutput2
	ret
mov67 ENDP
;************************************************************************************************************
;************************************************************************************************************
pushPop1 PROC				;Taip pat naudojama daugelio kitu funkciju, turinciu adresavimo baitus ir viena operanda
;Register/Memory
	call GetBitVariables
	call GetRm
	call CreateOutput1
	mov bx, 24
	mov si, 0				;Nera antro operando
	lea di, currentRm
	call CreateOutput2	
	ret
pushPop1 ENDP
;************************************************************************************************************
pushPop2 PROC
;Register
	mov si, bufferPointer
	mov ax, word ptr inputBuff[si]
	and al, 00000111b
	mov regValue, al
	inc bufferPointer
	mov wordBit, 1
	call GetRegister
	call CreateOutput1
	mov bx, 24
	mov si, 0
	lea di, currentReg
	call CreateOutput2
	ret
pushPop2 ENDP
;************************************************************************************************************
pushPop3 PROC
;Segment Register
	mov si, bufferPointer
	mov ax, word ptr inputBuff[si]
	and al, 00011000b
	shr al, 3
	mov regValue, al
	inc bufferPointer
	call GetSegment
	call CreateOutput1
	mov bx, 24
	mov si, 0
	lea di, currentReg
	call CreateOutput2
	ret
pushPop3 ENDP
;************************************************************************************************************
;************************************************************************************************************
aritm2 PROC
;Immediate --> Register/Memory
	call GetBitVariables		;signBit = directionBit (s-->d)
	mov al, directionBit
	mov signBit, al
	call GetRm
	call GetData
	call CreateOutput1
	mov bx, 23
	lea si, currentData
	lea di, currentRm
	call CreateOutput2
	ret
aritm2 ENDP
;************************************************************************************************************
aritm3 PROC
;Immediate --> Accumulator
	mov si, bufferPointer
	mov al, inputBuff[si]
	and al, 00000001b
	mov wordBit, al
	inc bufferPointer
	call GetRegister
	call GetData
	call CreateOutput1
	mov bx, 23
	lea si, currentData
	lea di, currentReg
	call CreateOutput2
	ret
aritm3 ENDP
;************************************************************************************************************
callJmp1 PROC
;Direct Within Segment
	inc bufferPointer
	mov si, bufferPointer
	mov ax, word ptr inputBuff[si]
	inc bufferPointer
	cmp wordBit, 1
	je @@word
    cbw
	jmp @@afterWord
@@word:
	inc bufferPointer
@@afterWord:
	add ax, instructionPtr 
	add ax, bufferPointer
	lea si, number
	mov number, al
	mov di, 2
	call ByteGetAscii
	mov number, ah
	mov di, 0
	call ByteGetAscii
	mov cx, 4
	cld
	lea di, currentData
	lea si, ascii
	rep movsb
	call CreateOutput1
	mov bx, 23
	cmp outputBuff[23], 0
	je @@TikTrys
	mov bx, 24
@@TikTrys:
	lea di, currentData
	mov si, 0
	call CreateOutput2
	ret
callJmp1 ENDP
;************************************************************************************************************
callJmp2 PROC
;Direct within segment (Memory)
	inc bufferPointer
	mov currentRm[4], ':'
	mov cx, 2
	mov wordBit, 1
	lea di, currentRm + 5
@@ciklas:
	push cx
	mov cx, 4
	push di
	call GetData
	pop di
	cld
	lea si, currentData
	rep movsb
	lea di, currentRm
	pop cx
	loop @@ciklas
	call CreateOutput1
	mov bx, 24
	mov si, 0				;Nera antro operando
	lea di, currentRm
	call CreateOutput2
	ret
callJmp2 ENDP
;************************************************************************************************************
callJmp3 PROC
;Intersegment indirect
	call GetBitVariables
	call GetRm
	call CreateOutput1
	mov currentRm - 1, 'd'
	mov bx, 24
	mov si, 0				;Nera antro operando
	lea di, currentRm - 1
	call CreateOutput2	
	ret
callJmp3 ENDP
;************************************************************************************************************
IntRet PROC
	inc bufferPointer
	call GetData
	call CreateOutput1
	mov si, 0
	mov bx, 24
	lea di, currentData
	call CreateOutput2
	ret
IntRet ENDP
;************************************************************************************************************
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;SKAICIAVIMO PROCEDUROS;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;************************************************************************************************************
GetBitVariables PROC
	mov si, bufferPointer
;1 baitas
	mov ax, word ptr inputBuff[si]
	and al, 00000001b
	mov wordBit, al
	mov ax, word ptr inputBuff[si]
	and al, 00000010b
	shr al, 1
	mov directionBit, al
;2 baitas
	mov ax, word ptr inputBuff[si]
	and ah, 11000000b
	shr ah, 6
	mov modValue, ah			;mod 0-3
	mov ax, word ptr inputBuff[si]
	and ah, 00111000b
	shr ah, 3
	mov regValue, ah			;reg 0-7
	mov ax, word ptr inputBuff[si]
	and ah, 00000111b
	mov rmValue, ah				;r/m 0-7
	add bufferPointer, 2
	ret
GetBitVariables ENDP
;************************************************************************************************************
GetRegister PROC
	lea si, registerArray
	cmp wordBit, 1
	je @@word
	jmp @@afterWord
@@word:
	add si, 16
@@afterWord:
	mov al, regValue
	xor ah, ah
	add si, ax
	add si, ax
	mov ax, word ptr [si]
	mov word ptr currentReg, ax
	ret
GetRegister ENDP
;************************************************************************************************************
GetSegment PROC
	lea si, segmentArray
	mov al, regValue
	xor ah, ah
	add si, ax
	add si, ax
	mov ax, word ptr [si]
	mov word ptr currentReg, ax
	ret
GetSegment ENDP
;************************************************************************************************************
ByteGetAscii PROC
;di = poslinkis ascii masyve (0 - v.b)(2 - j.b)
;si = adresas, kurio baita konvertuosime
push cx
push ax
push bx
	mov bh, byte ptr [si]
	mov al, bh
	xor ah, ah
	mov bh, 10h
	div bh								;AL = vyr. pusbaitis	AH = jaun. pusbaitis
	mov cx, 2
@@pusbaiciai:
	cmp al, 9
	jbe @@skaicius
	add al, 37h
	jmp @@afterSkaicius
@@skaicius:
	add al, 30h
@@afterSkaicius:
	mov byte ptr ascii[di], al
	inc di
	mov al, ah
	loop @@pusbaiciai
pop bx
pop ax
pop cx
	ret
ByteGetAscii ENDP
;************************************************************************************************************
GetRm PROC
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;MOD = 11;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;r/m - registras, jeigu mod = 11
	cmp modValue, 3
	jne @@notRegister
	lea si, registerArray
	cmp wordBit, 1
	je @@word
	jmp @@afterWord
@@word:
	add si, 16
@@afterWord:
	mov al, rmValue
	xor ah, ah
	add si, ax
	add si, ax
	mov ax, word ptr [si]
	mov word ptr currentRm, ax
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;MOD =/= 11;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@@notRegister:
	cmp rmValue, 6
	jne @@notDirect
	cmp modValue, 0
	jne @@notDirect
	call GetDirectAddress 			;r/m - tiesioginis adresas, jeigu mod = 00 ir r/m = 110
	jmp @@prefiksoIrasymas
@@notDirect:
	;r/m - operandas atmintyje
	cmp rmValue, 4
	jae @@trumpesni
	mov bl, 7
	lea si, memoryArray1
	jmp @@ilgesni
@@trumpesni:
	mov bl, 2
	lea si, memoryArray2
@@ilgesni:
	mov al, rmValue
	xor ah, ah
	mul bl
	add si, ax
	xor bh, bh
	mov cx, bx
	mov currentRm[0], '['
	lea di, currentRm + 1
	cmp currentSeg, 0
	je @@NeraPrefikso
	add di, 3
	mov al, currentSeg[0]
	mov currentRm[0], al
	mov al, currentSeg[1]
	mov currentRm[1], al
	mov currentRm[2], ':'
	mov currentRm[3], '['
@@NeraPrefikso:
	cld							;DF = 0
	rep movsb					;mov ES[di], DS[si]  si, di ++
	cmp modValue, 0				;Kai mod == 00, tai poslinkio nera
	jne @@poslinkis
	mov byte ptr[di], ']'
	jmp @@prefiksoIrasymas
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;MOD = 01;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@@poslinkis:
	mov byte ptr[di], ' '
	mov byte ptr[di + 1], '+'
	mov byte ptr[di + 2], ' '
	mov byte ptr[di + 7], ']'
	add di, 3
	push di
	mov di, 2
	lea si, inputBuff
	add si, bufferPointer
	call ByteGetAscii
	cmp modValue, 1
	jne @@wordPoslinkis
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;MOD = 01;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	cmp ascii[2], '8'
	jae @@pletimasPagalZenkla
	mov ascii[0], '0'
	mov ascii[1], '0'
	jmp @@poslinkioIrasymas
@@pletimasPagalZenkla:
	mov ascii[0], 'F'
	mov ascii[1], 'F'
	jmp @@poslinkioIrasymas
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;MOD = 10;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@@wordPoslinkis:
	mov di, 0
	inc bufferPointer
	lea si, inputBuff
	add si, bufferPointer
	call ByteGetAscii
@@poslinkioIrasymas:
	mov cx, 4
	cld
	lea si, ascii
	pop di
	rep movsb
	inc bufferPointer
@@prefiksoIrasymas:
	std
	mov cx, 27
	lea di, currentRm[26]
	lea si, currentRm[17]
	rep movsb					;Masyvas perstumiamas per 8 i prieki
	cld
	mov cx, 9
	lea di, currentRm
	cmp wordBit, 1
	je @@wordPtr
	lea si, bytePtr	
	jmp @@afterWordPtr
@@wordPtr:
	lea si, wordPtr
@@afterWordPtr:
	rep movsb					;Irasomas prefiksas
	ret	
GetRm ENDP
;************************************************************************************************************
GetData PROC
	lea si, inputBuff
	add si, bufferPointer
	mov di, 2
	call ByteGetAscii
	inc bufferPointer
	mov al, ascii[2]
	mov currentData[2], al
	mov al, ascii[3]
	mov currentData[3], al
	cmp wordBit, 1
	jne @@byte
	cmp signBit, 1
	je @@extendedByte
	mov di, 0
	inc si
	call ByteGetAscii
	inc bufferPointer
	mov al, ascii[0]
	mov currentData[0], al
	mov al, ascii[1]
	mov currentData[1], al
	ret
@@byte:
	mov al, currentData[2]
	mov currentData[0], al
	mov al, currentData[3]
	mov currentData[1], al
	mov currentData[2], 0
	ret
@@extendedByte:
	cmp currentData[2], '8'
	jb @@pridetiNuliuku
	mov currentData[0], 'F'
	mov currentData[1], 'F'
	ret
@@pridetiNuliuku:
	mov currentData[0], '0'
	mov currentData[1], '0'
	ret
GetData ENDP
;************************************************************************************************************
GetDirectAddress PROC
	lea si, inputBuff
	add si, bufferPointer
	mov di, 2
	call ByteGetAscii
	inc si
	mov di, 0
	call ByteGetAscii
	mov cx, 4
	cld							;DF = 0, nes vykdysime eilutine komanda
	lea si, ascii
	mov di, offset currentRm + 1
	mov bx, 0
	cmp currentSeg, 0
	je @@NeraPrefikso
	add di, 3
	mov bx, 3
	mov al, currentSeg[0]
	mov currentRm[0], al
	mov al, currentSeg[1]
	mov currentRm[1], al
	mov currentRm[2], ':'
@@NeraPrefikso:
	rep movsb					;mov ES[di], DS[si]; si, di ++
	mov currentRm[bx], '['
	mov currentRm[bx+5], ']'
	add bufferPointer, 2
	ret
GetDirectAddress ENDP
;************************************************************************************************************
CreateOutput1 PROC
	mov ax, instructionPtr
	mov di, 0
	lea si, number
	mov number, ah
	call ByteGetAscii		;di = di + 2
	mov number, al
	mov di, 2
	call ByteGetAscii
	mov cx, 4
	lea si, ascii
	lea di, outputBuff
	cld
	rep movsb	
	mov outputBuff[4], ':'
	mov outputBuff[5], ' '
	lea si, inputBuff
	add si, startingPtr
	mov bx, 6
	mov cx, bufferPointer
	sub cx, startingPtr
@@ciklas:
	mov di, 0
	call ByteGetAscii			;di = 0; si = elementas bufferyje; ascii[0-1] = baitas ascii formatu
	mov al, byte ptr ascii[0]
	mov outputBuff[bx], al
	inc bx
	mov al, byte ptr ascii[1]
	mov outputBuff[bx], al
	inc bx
	inc si
	loop @@ciklas
	
@@tarpai:
	mov outputBuff[bx], ' '
	inc bx
	cmp bx, 20
	jb @@tarpai
	ret
CreateOutput1 ENDP
;************************************************************************************************************
CreateOutput2 PROC
	;di - pirmasis operandas
	;si - antrasis operandas (jeigu toks yra)
	;bx - outputBuff pozicija	
@@Tarpai:
	mov byte ptr outputBuff[bx], ' ' 
	inc bx
	cmp bx, 26
	jb @@Tarpai
@@Pirmas:
	cmp byte ptr[di], 0
	je @@BaigesiPirmas
	mov al, byte ptr[di]
	mov byte ptr outputBuff[bx], al
	inc di
	inc bx
	jmp @@Pirmas
@@BaigesiPirmas:
	cmp si, 0
	je @@baigesiAntras
	mov byte ptr outputBuff[bx], ','
	mov byte ptr outputBuff[bx + 1], ' '
	add bx, 2
@@Antras:
	cmp byte ptr[si], 0
	je @@BaigesiAntras
	mov al, byte ptr[si]
	mov byte ptr outputBuff[bx], al
	inc si
	inc bx
	jmp @@Antras
@@BaigesiAntras:
	mov byte ptr outputBuff[bx], 10
	ret
CreateOutput2 ENDP
;************************************************************************************************************
Rasymas PROC
	mov bx, 0
@@Ciklas:
	cmp byte ptr outputBuff[bx], 0
	je @@Continue
	inc bx
	jmp @@Ciklas
@@Continue:
	mov cx, bx
	mov bx, outputHandle
	mov ah, 40h
	lea dx, outputBuff
	int 21h
	ret
Rasymas ENDP
;************************************************************************************************************
Isvalymas PROC
;Isvalomi masyvai duomenu segmente nuo ascii iki outputBuff
	mov al, 0
	mov cx, 120
	lea di, ascii
	cld
	rep stosb 			;mov es[di], al		di++
	ret
Isvalymas ENDP
;************************************************************************************************************
END