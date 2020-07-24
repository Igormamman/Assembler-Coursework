;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;cursovaya.asm
;
; T�����:
;  tasm.exe /l cursovaya.asm
;  tlink /t /x cursovaya.obj
;
; L����v:
;  i+TL ��. =.i. +������, LL5-44, 2020 �.
;  +��� L.-.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

code segment	'code'
	assume	CS:code, DS:code
	org	100h
	_start:
	
	jmp _initTSR ; �� ������ ��������v
	
	; ����v�
   	f5changeChars1				DB	'abcdefghijklmnopqrstuvwxyz'	;@ ������ ����������v� ��������
   	f5changeLength1 				equ	$-f5changeChars1		; ����� ������ f5changeChars1	      
 	f5changeChars2			DB	'ABCDEFGHIJKLMNOPQRSTUVWXYZ'	;@ ������ ����������v� �������
  	f5changeLength2 				equ	$-f5changeChars2		; ����� ������ f5changeChars2	                       
	changeEnabled 				DB	0							; ���� ������� ������������� �����
	 changeTo1				DB '�������������������������������'     
	 changeTo2				DB '�����Ũ��������������������������-'     
	
	translateFrom 				DB	'{WXIO'						;@ ������v ��� �����v (L+T+- �� ����. ���������)
	translateTo 					DB	'-?++-'						;@ ������v �� �����v� ����� ���� ������
	translateLength				equ	$-translateTo					; ����� ������ trasnlateFrom
	translateEnabled				DB	0							; ���� ������� ��������
	
	signaturePrintingEnabled 		DB	0							; ���� ������� �v���� ���������� �� ������
	cursiveEnabled 				DB	0							; ���� �������� ������� � ������

	cursiveSymbol 				DB 00000000b						;@ ������, ����������v� �� �������� (��� �������v� �������)
								DB 00000000b
								DB 00000000b
								DB 00111110b
								DB 00111111b
								DB 00110011b
								DB 01100110b
								DB 01100110b
								DB 01111100b
								DB 11000110b
								DB 11000110b
								DB 11000110b
								DB 11111100b
								DB 00000000b
								DB 00000000b
								DB 00000000b
	
	charToCursiveIndex 			DB 'i'							; ������ ��� �����v
	savedSymbol 					DB 16 dup(0FFh)					; ���������� ��� �������� ������� �������
	
	true 						equ	0FFh							; ��������� ����������
	old_int9hOffset 				DW	?							; ����� ������� ����������� int 9h
	old_int9hSegment 				DW	?							; ������� ������� ����������� int 9h
	old_int1ChOffset 				DW	?							; ����� ������� ����������� int 1Ch
	old_int1ChSegment 			DW	?							; ������� ������� ����������� int 1Ch
	old_int2FhOffset 				DW	?							; ����� ������� ����������� int 2Fh
	old_int2FhSegment 			DW	?							; ������� ������� ����������� int 2Fh
	
	unloadTSR					DB	0 							; 1 - �v������� ��������
	notLoadTSR					DB	0							; 1 - �� ���������
	counter	  					DW	0
	printDelay					equ	2 							;@ �������� ����� �v����� "�������" � ��������
	printPos						DW	1 							;@ ��������� ������� �� ������. 0 - ����, 1 - �����, 2 - ���
	
	;@ �������� �� ���������v� ����v�. ������������ ������v ���� �� ������ ������� ����v (1� ������).
	signatureLine1				DB	179, '+��� L���� -��������', 179
	Line1_length 					equ	$-signatureLine1
	signatureLine2				DB	179, 'LL5-44                                            ', 179
	Line2_length 					equ	$-signatureLine2
	signatureLine3				DB	179, 'T������ i22                                        ', 179
	Line3_length 					equ	$-signatureLine3
	helpMsg DB '>tsr.com [/?] [/u]', 10, 13
			DB ' [/?] - �v��� ������ �������', 10, 13
			DB '  F1  - �v��� LL+ � �����v �� ������� � ������ ������', 10, 13
			DB '  F2  - ���i����� � ����i����� ���������� �v���� �������� ������� i', 10, 13
			DB '  F3  - ���i����� � ����i����� ��������� ����������� ���������v({WXIO-> -?++-)', 10, 13
			DB '  F4  - ���i����� � ����i����� ������ ���������� ����� ��������� ������v� ����', 10, 13			
	helpMsg_length				equ  $-helpMsg                                                                                                                 
	
	errorParamMsg					DB	'+����� ���������� ���������� ������', 10, 13
	errorParamMsg_length			equ	$-errorParamMsg
	
	tableTop						DB	218, Line1_length-2 dup (196), 191
	tableTop_length 				equ	$-tableTop
	tableBottom					DB	192, Line1_length-2 dup (196), 217
	tableBottom_length 			equ  $-tableBottom
	
	; ��������		
	installedMsg					DB  'i������� ��������!$'
	alreadyInstalledMsg			DB  'i������� ��� ��������$'
	noMemMsg						DB  '=����������� ������$'
	notInstalledMsg				DB  '=� ������� ��������� ��������$'
	
	removedMsg					DB  'i������� �v������'
	removedMsg_length				equ	$-removedMsg
	
	noRemoveMsg					DB  '=� ������� �v������� ��������'
	noRemoveMsg_length			equ	$-noRemoveMsg
	
	f2_txt						DB	'F2'
	f3_txt						DB	'F3'
	f4_txt						DB	'F4'
	f5_txt						DB	'F5'
	fx_length					equ	$-f4_txt
	
	changeFx proc
		push AX
		push BX
		push CX
		push DX
		push BP
		push ES
		xor BX, BX
		
		mov AH, 03h
		int 10h
		push DX
		
		push CS
		pop ES
		
	_checkF2:
		lea BP, f2_txt
		mov CX, fx_length
		mov BH, 0
		mov DH, 0
		mov DL, 78
		mov AX, 1301h
		
		cmp signaturePrintingEnabled, true
		je _greenF2
		
		_redF2:
			mov BL, 01001111b ; red
			int 10h
			jmp _checkF3
		
		_greenF2:
			lea BP, f2_txt
			mov BL, 00101111b ; green
			int 10h
			
	_checkF3:
		lea BP, f3_txt
		mov CX, fx_length
		mov BH, 0
		mov DH, 1
		mov DL, 78
		mov AX, 1301h
		
		cmp cursiveEnabled, true
		je _greenF3
		
		_redF3:
			mov BL, 01001111b ; red
			int 10h
			jmp _checkF4
		
		_greenF3:
			mov BL, 00101111b ; green
			int 10h
		
	_checkF4:
		lea BP, f4_txt
		mov CX, fx_length
		mov BH, 0
		mov DH, 2
		mov DL, 78
		mov AX, 1301h
		
		cmp translateEnabled, true
		je _greenF4
		
		_redF4:
			mov BL, 01001111b ; red
			int 10h
			jmp _checkF5
		
		_greenF4:
			mov BL, 00101111b ; green
			int 10h
			
	_checkF5:
		lea BP, f5_txt
		mov CX, fx_length
		mov BH, 0
		mov DH, 3
		mov DL, 78
		mov AX, 1301h
		
		cmp changeEnabled, true
		je _greenF5
		
		_redF5:
			mov BL, 01001111b ; red
			int 10h
			jmp _outFx
		
		_greenF5:
			mov BL, 00101111b ; green
			int 10h
			
	_outFx:
		pop DX
		mov AH, 02h
		int 10h
		
		pop ES
		pop BP
		pop DX
		pop CX
		pop BX
		pop AX
		ret
	changeFx endp
	
    ;���v� ����������
    new_int9h proc far
		; ��������� �������� ����, ��������v� ��������� � �����
		push SI
		push AX
		push BX
		push CX
		push DX
		push ES
		push DS
		; �������������� CS � DS
		push CS
		pop	DS

		mov	AX, 40h ; 40h-�������,��� �������� ����� ����-� ���������v, �����. ����� ����� 
		mov	ES, AX
		in	AL, 60h	; �����v���� � AL ����-��� ������� �������
		
		;�������� F2-F5
		_test_Fx:
		sub AL, 58 ; � AL ������ ����� �������������� �������
		_F2:
			cmp AL, 2 ; F2
			jne _F3
			not signaturePrintingEnabled
			call changeFx
			jmp	_change_translate	
		_F3:
			cmp AL, 3 ; F3
			jne _F4
			not cursiveEnabled
			call changeFx
			call setCursive ; ������� ������� � ������ � ������� � ����������� �� ����� cursiveEnabled
			jmp	_change_translate
		_F4:
			cmp AL, 4 ; F4
			jne _F5
			not translateEnabled
			call changeFx
			jmp	_change_translate
		_F5:
			cmp AL, 5 ; F5
			jne	_change_translate
			not changeEnabled
			call changeFx
			jmp 	_change_translate
				
		;������������� � �������
		_change_translate:
		
		pushf
		call dword ptr CS:[old_int9hOffset] ; �v�v���� ���������v� ���������� ����v�����
		mov	AX, 40h 	; 40h-�������,��� �������� ����� ����-� ����v,�����. ����� ����� 
		mov	ES, AX
		mov	BX, ES:[1Ch]	; ����� ������
		dec	BX	; ��������� ����� � ����������
		dec	BX	; ��������� �������
		cmp	BX, 1Eh	; �� �v��� �� �v �� ������v ������?
		jae	_go
		mov	BX, 3Ch	; ����� �v��� �� ������v ������, ������ ��������� ������v� ������
				    ; ���������	� ����� ������

	_go:		
		mov DX, ES:[BX] ; � DX 0 ������v� ������
		;���i��� �� ����� ���������� �����?
		cmp changeEnabled, true
		jne _check_translate
		
		; ��, ���i���
		mov SI, 0
		mov CX, f5changeLength1 ;���-�� ����������v� ��������
		
		; ���������, ������������ �� ������ ������ � ������ ����������v�
	_check_change1:
		cmp DL,f5changeChars1[SI]
		je _change1
		inc SI
	loop _check_change1                   
		mov CX, f5changeLength2 ;���-�� ����������v� ��������
	_check_change2:
		cmp DL,f5changeChars2[SI]
		je _change2
		inc SI
	loop _check_change2
		jmp _check_translate
		
	; ���������
	_change1:
		
		;@ ���� �� �������� ����� �� ����������� ���� �������,
		;@ � �������� ���� ������v �������,
		;@ �������� ������ �v�� �������
		;@  mov ES:[BX], AX
		;@ �� ����� AX ����� �v�� '*' ��� �����v ���� �������� ��������� ignoredChars �� ��������
		;@ ���, ��� �������� ����� �������� � ������ - ������� ������
		;@ replaceWith DB '...', ��� ����������� ������v, �� �����v� ����� ������
		;@ � ����������������� ������ ����:
		xor AX, AX
		mov AL,  changeTo1[SI]
		mov ES:[BX], AX	; ������ �������
		jmp _quit
	
	_change2:
		xor AX, AX
		mov AL,  changeTo2[SI]
		mov ES:[BX], AX	; ������ �������
		jmp _quit
	
	_check_translate:
		; ���i��� �� ����� ��������?
		cmp translateEnabled, true
		jne _quit
		
		; ��, ���i���
		mov SI, 0
		mov CX, translateLength ; ���-�� �������� ��� ��������
		; ���������, ������������ �� ������ ������ � ������ ��� ��������
		_check_translate_loop:
			cmp DL, translateFrom[SI]
			je _translate
			inc SI
		loop _check_translate_loop
		jmp _quit
		
		; ���������
		_translate:		
			xor AX, AX
			mov AL, translateTo[SI]
			mov ES:[BX], AX	; ������ �������
			
	_quit:
		; ��������������� ��� �������v
		pop	DS
		pop	ES
		pop DX
		pop CX
		pop	BX
		pop	AX
		pop SI
		iret
new_int9h endp  

;=== +��������� ����v����� int 1Ch ===;
;=== Tv�v������ ����v� 55 �� ===;
new_int1Ch proc far
	push AX
	push CS
	pop DS
	
	pushf
	call dword ptr CS:[old_int1ChOffset]
	
	cmp signaturePrintingEnabled, true ; ���� ������ �������i�� ������� (� ������ ������ F1)
	jne _notToPrint		
	
		cmp counter, printDelay*1000/55 + 1 ; ���� ���-�� "������" ������������ %printDelay% ��������
		je _letsPrint
		
		jmp _dontPrint
		
		_letsPrint:
			not signaturePrintingEnabled
			mov counter, 0
			call printSignature
		
		_dontPrint:
			add counter, 1
		
	_notToPrint:
	
	pop AX
	
	iret
new_int1Ch endp

;=== +��������� ����v����� int 2Fh ===;
;=== T����� ���:
;===  1) �������� ����� ����������� TSR � ������ (��� AH=0FFh, AL=0)
;===     ����� �������� AH='i' � ������, ���� TSR ��� ��������
;===  2) �v������ TSR �� ������ (��� AH=0FFh, AL=1)
;===     
new_int2Fh proc
	cmp	AH, 0FFh	;���� �������?
	jne	_2Fh_std	;��� - �� ����v� ����������
	cmp	AL, 0	;���������� ��������, �������� �� �������� � ������?
	je	_already_installed
	cmp	AL, 1	;���������� �v������ �� ������?
	je	_uninstall	
	jmp	_2Fh_std	;��� - �� ����v� ����������
	
_2Fh_std:
	jmp	dword ptr CS:[old_int2FhOffset]	;�v��� ������� �����������
	
_already_installed:
		mov	AH, 'i'	;����� 'i', ���� �������� ��������	� ������
		iret
	
_uninstall:
	push	DS
	push	ES
	push	DX
	push	BX
	
	xor BX, BX
	
	; CS = ES, ��� ������� � ��������v�
	push CS
	pop ES
	
	mov	AX, 2509h
	mov DX, ES:old_int9hOffset         ; ��������� ������ ����v�����
    mov DS, ES:old_int9hSegment        ; �� �����
	int	21h
	
	mov	AX, 251Ch
	mov DX, ES:old_int1ChOffset         ; ��������� ������ ����v�����
    mov DS, ES:old_int1ChSegment        ; �� �����
	int	21h

	mov	AX, 252Fh
	mov DX, ES:old_int2FhOffset         ; ��������� ������ ����v�����
    mov DS, ES:old_int2FhSegment        ; �� �����
	int	21h

	mov	ES, CS:2Ch	; �������� � ES ����� ���������			
	mov	AH, 49h		; �v������ �� ������ ���������
	int	21h
	jc _notRemove
	
	push	CS
	pop	ES	;� ES - ����� ����������� ��������v
	mov	AH, 49h  ;�v������ �� ������ ��������
	int	21h
	jc _notRemove
	jmp _unloaded
	
_notRemove: ; �� ������� �v������� �v������
    ; �v��� �������� � ��������� �v������
	mov AH, 03h					; �������� ������i �������
	int 10h
	lea BP, noRemoveMsg
	mov CX, noRemoveMsg_length
	mov BL, 0111b
	mov AX, 1301h
	int 10h
	jmp _2Fh_exit
	
_unloaded: ; �v������ ������ �������
    ; �v��� �������� �� ������� �v������
	mov AH, 03h					; �������� ������i �������
	int 10h
	lea BP, removedMsg
	mov CX, removedMsg_length
	mov BL, 0111b
	mov AX, 1301h
	int 10h
	
_2Fh_exit:
	pop BX
	pop	DX
	pop	ES
	pop	DS
	iret
new_int2Fh endp

;=== i�������� �v���� ������� (LL+, ������)
;=== =������������ ���������� ��������v� � ������ ���������
;===
printSignature proc
	push AX
	push DX
	push CX
	push BX
	push ES
	push SP
	push BP
	push SI
	push DI

	xor AX, AX
	xor BX, BX
	xor DX, DX
	
	mov AH, 03h						;������ ������ ������� �������
	int 10h
	push DX							;������� ���������i � ��������� ������� � ����
	
	cmp printPos, 0
	je _printTop
	
	cmp printPos, 1
	je _printCenter
	
	cmp printPos, 2
	je _printBottom
	
	;��� ����� ��������v �� ����...
	_printTop:
		mov DH, 0
		mov DL, 15
		jmp _actualPrint
	
	_printCenter:
		mov DH, 9
		mov DL, 15
		jmp _actualPrint
		
	_printBottom:
		mov DH, 19
		mov DL, 15
		jmp _actualPrint
		
	_actualPrint:	
		mov AH, 0Fh					;������ ������� �����������. � BH - ������ ��������
		int 10h

		push CS						
		pop ES						;����v���� ES �� CS
		
		;�v��� '��������' ������v
		push DX
		lea BP, tableTop				;������� � BP ��������� �� �v������i ������
		mov CX, tableTop_length		;� CX - ����� ������
		mov BL, 0111b 				;���� �v�������� ������ ref: http://en.wikipedia.org/wiki/BIOS_color_attributes
		mov AX, 1301h					;AH=13h - ����� �-��, AL=01h - ������ ����������� ��� �v���� ������� �� �������� ������
		int 10h
		pop DX
		inc DH
		
		
		;�v��� ������ �����
		push DX
		lea BP, signatureLine1
		mov CX, Line1_length
		mov BL, 0111b
		mov AX, 1301h
		int 10h
		pop DX
		inc DH
		
		;�v��� ������ �����
		push DX
		lea BP, signatureLine2
		mov CX, Line2_length
		mov BL, 0111b
		mov AX, 1301h
		int 10h
		pop DX
		inc DH
		
		;�v��� ������� �����
		push DX
		lea BP, signatureLine3
		mov CX, Line3_length
		mov BL, 0111b
		mov AX, 1301h
		int 10h
		pop DX
		inc DH
		
		;�v��� '����' ������v
		push DX
		lea BP, tableBottom
		mov CX, tableBottom_length
		mov BL, 0111b
		mov AX, 1301h
		int 10h
		pop DX
		inc DH
		
		xor BX, BX
		pop DX						;��������������� �� ����� ������� ��������� �������
		mov AH, 02h					;������ ��������� ������� �� ��������������
		int 10h
		call changeFx
		
	pop DI
	pop SI
	pop BP
	pop SP
	pop ES
	pop BX
	pop CX
	pop DX
	pop AX
	
	ret
printSignature endp

;=== L������, ������� � ����������� �� ����� cursiveEnabled ������ ���������� ������� � ������� �� ��v���� � �������
;=== T��� ����� ���������� � ��������� changeFont, � ����� ������������i��� ����v�
setCursive proc
	push ES ; ��������� �������v
	push AX
	push CS
	pop ES

	cmp cursiveEnabled, true
	jne _restoreSymbol
	; ���� ���� ����� true, �v������� ������ ������� �� �������v� �������,
	; �������������� �������� ����v� ������ � savedSymbol
	
	call saveFont
	mov CL, charToCursiveIndex
_shifTtable:
	; �v �������� � BP ������� ���� ��������. ����� ����v���� �� ������ 0
	; ������� ����� ��������� ����� 16*X - ��� X - ��� �������
	add BP, 16
	loop _shiftTable
	
	; �p� savefont �������� p�����p ES
	; ������y �p�������� ������ ����� ���������, ����v 
	; �������� ���y����v� ������� � savedSymbol
	; swap(ES, DS) � ���������� ������� �������� DS
	push DS
	pop AX
	push ES
	pop DS
	push AX
	pop ES
	push AX

	mov SI, BP
	lea DI, savedSymbol
	; ���p����� � ��p�����yi savedSymbol
	; ������y �y����� �������
	mov CX, 16
	; movsb �� DS:SI � ES:DI
	rep movsb
	; ������v� ������� ��������� ����p���v	
	pop DS ; �������������� DS

	; ������� ��������� ������� �� �yp���
	mov CX, 1
	mov DH, 0
	mov DL, charToCursiveIndex
	lea BP, cursiveSymbol
	call changeFont
	jmp _exitSetCursive
	
_restoreSymbol:	
	; ���� ���� ����� 0, �v������� ������ ���������� ������� �� ����v� �������

	mov CX, 1
	mov DH, 0
	mov DL, charToCursiveIndex
	lea bp, savedSymbol
	call changeFont
	
_exitSetCursive:
	pop AX
	pop ES
	ret
setCursive endp	
	
;=== L������ ����v ���������� ������� (������/����������)
;===
; *** �����v� ����v�
; DL = ����� ������� ��� �����v
; CX = i��-�� �������� ��������v� ����������� ��������
; (������� � ������� ���������� � DX)
; ES:bp = ����� ������v
;
; *** �������� �����v ��������v
; i��������� �v��� int 10h (�����������)
; � �������� AH = 11h (������� ���������������)
; i������� AL = 0 �������, ��� ����� �������� �����������
; ������� ��� ������� ������
; T �������, ����� AL = 1 ��� 2, ����� �������� �����������
; ������ ��� ������������ ������ (8x14 � 8x8 ��������������)
; i������� BH = 0Eh �������, ��� �� ���������� ������� ����������� �������
; ����������� �� 14 ���� (����� 8x14 ��� ��� ��� 14 ����)
; i������� BL = 0 - ���� ������ ��� �������� (�� 0 �� 4)
;
; *** ���������
; ����������� ����������(v�) �������(��) ����� ��������
; �� ������������ �������������.
; L�������i ������������ ��� ������v, ���������� �� ������,
; �� ���� ���� ����������� ��������, ����v� ������� ����� ��� �� ���������

changeFont proc
	push AX
	push BX
	mov AX, 1100h
	mov BX, 1000h
	int 10h
	pop AX
	pop BX
	ret
changeFont endp

;=== L������ ���������� ����������� ���������� �������
;===
; *** �����v� ����v�
; BH - ��� ����������� ���������� ������v
;   0 - ������� �� int 1fh
;   1 - ������� �� int 44h
;   2-5 - ������� �� 8x14, 8x8, 8x8 (top), 9x14
;   6 - 8x16
;
; *** �������� �����v ��������v
; i��������� �v��� int 10h (�����������)
; � �������� AH = 11h (������� ���������������)
; i������� AL = 30 - ���������� ��������� ���������� � EGA
;
; *** ���������
; � ES:BP ��������� ������� �������� (������)
; � CX ��������� ���� �� ������
; � DL ���������� ������v� �����
; TLi=+! i��������� ����� �������� ES
; ( ES ���������� ����v� C000h )

saveFont proc
	push AX
	push BX
	mov AX, 1130h
	mov BX, 0600h
	int 10h
	pop AX
	pop BX
	ret
saveFont endp


;=== +��i�� ���������� �v�������� �������� ����� ��������v ===;
;===
_initTSR:                         	; ����� ���������
	mov AH, 03h
	int 10h
	push DX
	mov AH,00h					; ��������� ����������� (83h  �����  80x25  16/8  CGA,EGA  b800  Comp,RGB,Enhanced), ��� ������� ������
	mov AL,83h
	int 10h
	pop DX
	mov AH, 02h
	int 10h
	
	
    call commandParamsParser    
	mov AX,3509h                    ; �������� � ES:BX ������ 09
    int 21h                         ; ����v�����
	
	;@ === L������� ��������� �� ������ ===
	;@ +��� �� �������� ���������� �v������� �������� �� ���������� ������� ����������, 
	;@ ����� ���������������� �����i�� 3 ������, � �����
	;@ ���������� ����� _finishTSR �-�� commandParamsParser, �� �� ���� �����!
	cmp unloadTSR, true
	je _removingOnParameter
	jmp _notRemovingNow

	_removingOnParameter:
		mov AH, 0FFh
		mov AL, 0
		int 2Fh
		cmp AH, 'i'  ; �������� ����, ��������� �� ��� ���������
		je _remove 
		mov AH, 09h				;@ ��� �v������ ��������� �� ���������� ������� ���������������� ��� ������
		lea DX, notInstalledMsg	;@ ��� �v������ ��������� �� ���������� ������� ���������������� ��� ������
		int 21h					;@ ��� �v������ ��������� �� ���������� ������� ���������������� ��� ������
		int 20h					;@ ��� �v������ ��������� �� ���������� ������� ���������������� ��� ������
	 
	_notRemovingNow:
	
	cmp notLoadTSR, true			; ���� �v�� �v������ �������
	je _exit_tmp						; ������ �v�����

	;@ +��� �� �������� ���������� �v������� �������� �� ���������� �������, �� ������������ 5 ����� ����
	;@ ���� ���������� �v������� �� ��������� ���������� ������, �� ��������� ��
	mov AH, 0FFh
	mov AL, 0
	int 2Fh
	cmp AH, 'i'  ; �������� ����, ��������� �� ��� ���������
	je _alreadyInstalled
    
	jmp _tmp
	
	_exit_tmp:
		jmp _exit
	
	_tmp:
	push ES
    mov AX, DS:[2Ch]                ; psp
    mov ES, AX
    mov AH, 49h                     ; ������ ������ ���� ��������
    int 21h                         ; ����������?
    pop ES
    jc _notMem                      ; �� ������� - �v�����
	
	;== int 09h ==;

	mov	word ptr CS:old_int9hOffset, BX
	mov	word ptr CS:old_int9hSegment, ES
    mov AX, 2509h                   ; ��������� ������ �� 09
    mov DX, offset new_int9h            ; ����v�����
    int 21h
	
	;== int 1Ch ==;
	mov AX,351Ch                    ; �������� � ES:BX ������ 1C
    int 21h                         ; ����v�����
	mov	word ptr CS:old_int1ChOffset, BX
	mov	word ptr CS:old_int1ChSegment, ES
	mov AX, 251Ch                   ; ��������� ������ �� 1C
	mov DX, offset new_int1Ch            ; ����v�����
	int 21h
	
	;== int 2Fh ==;
	mov AX,352Fh                    ; �������� � ES:BX ������ 1C
    int 21h                         ; ����v�����
	mov	word ptr CS:old_int2FhOffset, BX
	mov	word ptr CS:old_int2FhSegment, ES
	mov AX, 252Fh                   ; ��������� ������ �� 2F
	mov DX, offset new_int2Fh            ; ����v�����
	int 21h

	call changeFx
    mov DX, offset installedMsg         ; �v����� ��� ��� ��
    mov AH, 9
    int 21h
    mov DX, offset _initTSR       ; �������� � ������ ����������
    int 27h                         ; � �v�����
    ; ����� �������� ��������v  
_remove: ; �v������ ��������v �� ������
	mov AH, 0FFh
	mov AL, 1
	int 2Fh
	jmp _exit
_alreadyInstalled:
	mov AH, 09h
	lea DX, alreadyInstalledMsg
	int 21h
	jmp _exit
_notMem:                            ; �� ������� ������, ����v �������� ����������
    mov DX, offset noMemMsg
    mov AH, 9
    int 21h
_exit:                               ; �v���
    int 20h

;=== i�������� �������� ���������� ���. ������ ===;
;===
commandParamsParser proc
	push CS
	pop ES
	mov unloadTSR, 0
	mov notLoadTSR, 0
	
	mov SI, 80h   				;SI=������� ��������� ������.
	lodsb        					;i������ ���-�� ��������.
	or AL, AL     				;+��� 0 �������� �������, 
	jz _exitHelp   				;�� ��� � �������. 

	_nextChar:
	
	inc SI       					;T����� SI ����v���� �� ����v� ������ ������.
	
	cmp [SI], BYTE ptr 13
	je _exitHelp
	
	
		lodsw       				;i������� ��� �������
		cmp AX, '?/' 				;i�� '/?' (����v� ����������v � �������� ������, �.�. AL:AH ������ AH:AL)
		je _question
		cmp AX, 'u/'
		je _finishTSR
		
		;cmp AH, '/'
		;je _errorParam
		
		jmp _exitHelp
   
	_question:
		; �v��� ������ �����
			mov AH,03
			int 10h	
			lea BP, helpMsg
			mov CX, helpMsg_length
			mov BL, 0111b
			mov AX, 1301h
			int 10h
		; ����� �v���� ������ �����
		not notLoadTSR	        ;���� ����, ��� ���������� �� ��������� ��������
		jmp _nextChar
	
	;@ === L������� ��������� �� ������ ===
	;@ +��� �� �������� ���������� �v������� �������� �� ��������� '/u' ���������� ������, 
	;@ ����� ������������ �����i�� ���, � �������v� ������� ���������� ���������������� 
	;@ ���� ���, ����� �������� �����! (�� ������i ����� ���������� � �� �����, �� ��������� ����������� �������������)
	_finishTSR:
		not unloadTSR		      ;���� ����, ��� ���������� �v������ ��������
		jmp _nextChar

	jmp _exitHelp

	_errorParam:
		;�v��� ������
			mov AH,03
			int 10h	
			lea BP, CS:errorParamMsg
			mov CX, errorParamMsg_length
			mov BL, 0111b
			mov AX, 1301h
			int 10h
		;����� �v���� ������
	_exitHelp:
	ret
commandParamsParser endp

code ends
end _start