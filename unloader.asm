;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; unloader.asm
;
; ���ઠ:
;  tasm.exe /l unloader.asm
;  tlink /t /x unloader.obj
;
; �ணࠬ�� ��� ���㧪� TSR �� �����
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

code segment	'code'
	assume	CS:code, DS:code
	org	100h
	_start:
	
	mov AH, 0FFh
	mov AL, 1
	int 2Fh ; ��� ���뢠���
	int 20h	; ��室��
	
code ends
end _start