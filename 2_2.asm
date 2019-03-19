.MODEL small
.STACK 100h

.DATA
	inputFile1	DB 80 dup(0)				;Pirmojo duomenu failo pavadinimas
	inputFile2	DB 80 dup(0)				;Antrojo duomenu failo pavadinimas
	outputFile	DB 80 dup(0)				;Rezultatu failo pavadinimas
	inputBuff1	DB 256 dup('*')				;Pirmojo failo nuskaitytas skaicius
	inputBuff2  DB 256 dup('*')				;Antrojo failo nuskaitytas skaicius
	count1		DW 0
	count2		DW 0
	fileHandle	DW ?						;Bylos deskriptorius
	RezNulis    DB '0'
;Klaidu zinutes
	duomKlaida					  DB 'Klaida: Nekorektiski duomenys. Galima ivesti skaicius nuo 0 iki F$'
	paramKlaida 				  DB 'Klaida: Neteisingi parametrai. Sintakse: 2_2.exe <input1> <input2> <output>$'
	fNrKlaida					  DB 'Klaida: neteisingas funkcijos numeris$'
	bylaNerastaKlaida			  DB 'Klaida: byla nerasta$'
	keliasNerastasKlaida		  DB 'Klaida: kelias nerastas$'
	perdaugAtidarytuByluKlaida	  DB 'Klaida: per daug atidarytu bylu$'
	bylaNeprieinamaKlaida		  DB 'Klaida: byla neprieinama$'
	neteisingasDarboRezimasKlaida DB 'Klaida: neteisingas darbo rezimas registre$'
	nezinomaKlaida				  DB 'Klaida del nezinomos priezasties$'
.CODE
jmp Kodas
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SimboliuKonvertavimas proc
;SI - adresas count kintamojo
;DI - adresas inputBuff kintamojo
PUSH BX
PUSH CX
	mov BX, 0
	mov CX, [SI]
	inc CX
Konvertavimas:
	cmp byte ptr[DI + BX], 30h
	jnb @NoExit0
	jmp Exit3
@NoExit0:
	cmp byte ptr[DI + BX], 39h
	ja Raides
	sub byte ptr[DI + BX], 30h
	jmp KonvertEnd
Raides:
	cmp byte ptr[DI + BX], 41h
	jnb @NoExit1
	jmp Exit3
@NoExit1:
	cmp byte ptr[DI + BX], 46h
	jna @NoExit2
	jmp Exit3
@NoExit2:
	sub byte ptr[DI + BX], 37h
KonvertEnd:
    inc BX
loop Konvertavimas
POP CX
POP BX
ret
endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Skaitymas proc
;DX - inputFile kintamojo adresas
;SI - inputBuff kintamojo adresas
;AX - gauta count kintamojo reiksme
PUSH BX
PUSH CX
	;Atidaromas duomenu failas
	mov AH, 3Dh				;Atidarymo funkcija
	mov AL, 00h				;Tik skaitymas			
	int 21h
	jnc NoJump1				;Jeigu CF = 1, tai programa terminuojama
	jmp Exit2
NoJump1:
	;Jeigu CF = 0, tai failas sekmingai atidarytas ir AX yra bylos deskriptorius
	
	;Skaitomas failas
	mov BX, AX				;Bylos deskriptoriaus reiksme perkeliama i BX
	mov AH, 3Fh				;Skaitymo funkcija
	mov CX, 0100h			;Maksimalus skaitomu simboliu skaicius (Enteris kaip 2 simboliai)
	mov DX, SI				;Nuskaitymo bufferis
	int 21h
	jnc NoJump2				;Jeigu CF = 1, tai programa terminuojama
	jmp Exit2
NoJump2:
	push AX

	;Uzdaromas failas
	mov AH, 3Eh				;Failo uzdarymo funkcija
	int 21h
	jnc NoJump3
	jmp Exit2
NoJump3:
	pop AX
	dec AX
POP CX
POP BX
ret
endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Atimtis proc
;BX - Mazesniojo skaiciaus apimtis
;SI - Mazesniojo skaiciaus adresas be poslinkio
;DI - Didesniojo skaiciaus adresas + poslinkis
PUSH AX
PUSH CX
    mov CX, 0
Ciklas:
	mov AL, [DI]
	sub AL, [SI + BX]					;Vykdome atimti po viena skaitmeni
	jb Mintyje							;Jeigu skirtumas <0, viena skaicius lieka mintyje (skolinames)
	cmp CX, 1 							;Jeigu CX = 1, skolinames toliau
	je Mintyje
	mov CX, 0
	jmp Continue
Mintyje:
	mov CX, 0
	add AL, 10h
	dec byte ptr[DI - 1]
	jns Continue
	mov CX, 1							;Jeigu nera is kur skolintis, CX = 1
Continue:
    mov [DI], AL
	dec DI
	dec BX
	jns Ciklas
	cmp CX, 1
	jne NeraSkolos
Skolintis:
	sub byte ptr[DI], 1
	jns NeraSkolos
	add byte ptr[DI], 10h
	dec DI
	jmp Skolintis
NeraSkolos:	
POP CX
POP AX
ret
endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
HexSkaiciai proc
;CX - kiek simboliu masyve
;DX - inputBuff adresas
PUSH BX
    push CX
	mov BX, DX
	inc CX
	mov AX, 0
ArNulis:
    cmp byte ptr[BX], 00h
    je Nulis
@Ciklas:
	cmp byte ptr[BX], 09h
	ja @Raides
	add byte ptr[BX], 30h
	jmp @Continue
@Raides:
	add byte ptr[BX], 37h
	jmp @Continue
Nulis:
    inc DX                  ;Pastumiam inputBuff adresa vienetu
    inc AX                  ;Kiek skaitmenu sumazejo
    inc BX
    jmp ArNulis
@Continue:
	inc BX
	loop @Ciklas
	pop CX
	sub CX, AX
POP BX
ret
endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Rasymas proc
;DX - inputBuff adresas
;CX - kiek simboliu spausdinti
PUSH AX
PUSH BX
    inc CX
	push DX					;Issaugome DX velesniam panaudojimui
	push CX					;Issaugome CX velesniam panaudojimui
	;Sukuriamas rezultatu failas
	mov AH, 3Ch				;Failo sukurimo funkcija
	mov CX, 06h				;File attributes (-)
	lea DX, outputFile		;Rezultato failo pavadinimo adresas (Skaitoma tol, kol nesurandamas 0)
	int 21h
	jnc NoJump4
	jmp Exit2
NoJump4:
	
	;Rasome i faila
	pop CX
	pop DX
	cmp CX, 0
	jnz @RezNeNulis					;Jeigu simboliu skaicius yra 0, tai spausdiname nuli
	inc CX
	lea DX, RezNulis
@RezNeNulis:
	mov BX, 1						;Bylos deskriptorius
	mov AH, 40h
	int 21h
	jnc NoJump5
	jmp Exit2
NoJump5:
	
	;Uzdarome rezultatu faila
    mov AH, 3Eh                     ;Failo uzdarymo funkcija
    int 21h
	jnc NoJump6
	jmp Exit2
NoJump6:
POP BX
POP AX
ret
endp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Kodas:
	mov AX, @Data
	mov DS, AX			
	
	;Skaitomas ir apdorojamas parametras
	;ES:80h - adresas, kuriame prasideda parametras
	mov CL, byte ptr ES:[80h]			;Parametro simboliu skaicius randasi siame adrese
	mov CH, 00h
	add CL, 81h
	mov BX, 81h
	mov DL, 00h					;Kiek kartu praejo ciklas 'Parametrai'(Nuskaitytas tarpu/enter skaicius)
	lea SI, inputFile1			;inputFile adresas
	mov DH, 20h					;Tarpo ASCII kodas cmp operacijai(Veliau DH keisis i 0Dh (Carriage Return))
Parametrai:
	cmp BX, CX					;Tikriname, ar BX nevirsija ivesto parametru skaiciaus
	jna NoExit0
	jmp Exit1
NoExit0:
	inc BX
	mov AH, byte ptr ES:[BX]				;Parametro ASCII simbolis perkeliamas i AH
	mov [SI], AH
	inc SI
	mov AX, ES:[BX]
	cmp AH, DH
jne Parametrai
	inc DL
	inc BX
	cmp DL, 03h
	je Nuskaityta
	cmp DL, 01h					;Tikriname, kelintas parametras yra skaitomas
	je AntrasFailas
	mov DH, 0Dh					;Paskutini trecia cikla uzbaigia Enteris
	lea SI, outputFile
	jmp Parametrai
AntrasFailas:
	lea SI, inputFile2
	jmp Parametrai
Nuskaityta:
	
	;Kvieciame skaitymo funkcija
	lea DX, inputFile1
	lea SI, inputBuff1
	call Skaitymas
	mov count1, AX
	lea DX, inputFile2
	lea SI, inputBuff2
	call Skaitymas
	mov count2, AX
	
	;Kvieciame konvertavimo funkcija
	
	lea SI, count1
	lea DI, inputBuff1
	call SimboliuKonvertavimas
	lea SI, count2
	lea DI, inputBuff2
	call SimboliuKonvertavimas
	
	;Nustatome, kuris skaicius yra didesnis
	mov BX, 0FFFFh
	mov AX, count1
	cmp AX, count2
	je Lygu
	ja Pirmas
	jb Antras
Lygu:
	inc BX
	mov AL, inputBuff1[BX]
	cmp AL, inputBuff2[BX]
	je Lygu
	ja Pirmas
Antras:
	mov BX, count1					;Mazesniojo failo apimtis
	lea SI, inputBuff1
	lea DI, inputBuff2
	add DI, count2
	call Atimtis					;Atimame pirma is antro
	jmp Continue2
Pirmas:
	mov BX, count2					;Mazesniojo failo apimtis
	lea SI, inputBuff2
	lea DI, inputBuff1
	add DI, count1
	call Atimtis					;Atimame antra is pirmo
	;Kvieciama rasymo funkcija
	lea DX, inputBuff1				;Buferio adresas
	mov CX, count1					;Simboliu skaicius
	call HexSkaiciai
	call Rasymas
	jmp Exit
Continue2:
	lea DX, inputBuff2
	mov CX, count2
	call HexSkaiciai
	call Rasymas
	jmp Exit
	
Exit1:			;Klaida del parametru netaisyklingumo
	lea DX, paramKlaida
	mov AH, 09h
	int 21h
	jmp Exit
Exit2:
	cmp AX, 02h
	je  Klaida02
	cmp AX, 03h
	je  Klaida03
	cmp AX, 04h
	je  Klaida04
	cmp AX, 05h
	je  Klaida05
	cmp AX, 0Ch
	je  Klaida0C
	lea DX, NezinomaKlaida
	jmp Klaida
Exit3:
	lea DX, duomKlaida
	jmp Klaida
Klaida01:
	lea DX, fNrKlaida
	jmp Klaida
Klaida02:
	lea DX, bylaNerastaKlaida
	jmp Klaida
Klaida03:
	lea DX, keliasNerastasKlaida
	jmp Klaida
Klaida04:
	lea DX, perdaugAtidarytuByluKlaida
	jmp Klaida
Klaida05:
	lea DX, bylaNeprieinamaKlaida
	jmp Klaida
Klaida0C:
	lea DX, neteisingasDarboRezimasKlaida
Klaida:
	mov AH, 09h
	int 21h
Exit:
	mov AX, 4C00h
	int 21h
END