;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;cursovaya.asm
;
; Tборка:
;  tasm.exe /l cursovaya.asm
;  tlink /t /x cursovaya.obj
;
; Lвторv:
;  i+TL им. =.i. +аумана, LL5-44, 2020 г.
;  +пак L.-.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

code segment	'code'
	assume	CS:code, DS:code
	org	100h
	_start:
	
	jmp _initTSR ; на начало программv
	
	; даннvе
   	f5changeChars1				DB	'abcdefghijklmnopqrstuvwxyz'	;@ список игнорируемvх символов
   	f5changeLength1 				equ	$-f5changeChars1		; длина строки f5changeChars1	      
 	f5changeChars2			DB	'ABCDEFGHIJKLMNOPQRSTUVWXYZ'	;@ список игнорируемvх символо
  	f5changeLength2 				equ	$-f5changeChars2		; длина строки f5changeChars2	                       
	changeEnabled 				DB	0							; флаг функции игнорирования ввода
	 changeTo1				DB 'абвгдеёжхийклмнопрсуфхцчшщЪыьэюя'     
	 changeTo2				DB 'АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ-'     
	
	translateFrom 				DB	'{WXIO'						;@ символv для заменv (L+T+- на англ. раскладке)
	translateTo 					DB	'-?++-'						;@ символv на которvе будет идти замена
	translateLength				equ	$-translateTo					; длина строки trasnlateFrom
	translateEnabled				DB	0							; флаг функции перевода
	
	signaturePrintingEnabled 		DB	0							; флаг функции вvвода информации об авторе
	cursiveEnabled 				DB	0							; флаг перевода символа в курсив

	cursiveSymbol 				DB 00000000b						;@ символ, составленнvй из единичек (его курсивнvй вариант)
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
	
	charToCursiveIndex 			DB 'i'							; символ для заменv
	savedSymbol 					DB 16 dup(0FFh)					; переменная для хранения старого символа
	
	true 						equ	0FFh							; константа истинности
	old_int9hOffset 				DW	?							; адрес старого обработчика int 9h
	old_int9hSegment 				DW	?							; сегмент старого обработчика int 9h
	old_int1ChOffset 				DW	?							; адрес старого обработчика int 1Ch
	old_int1ChSegment 			DW	?							; сегмент старого обработчика int 1Ch
	old_int2FhOffset 				DW	?							; адрес старого обработчика int 2Fh
	old_int2FhSegment 			DW	?							; сегмент старого обработчика int 2Fh
	
	unloadTSR					DB	0 							; 1 - вvгрузить резидент
	notLoadTSR					DB	0							; 1 - не загружать
	counter	  					DW	0
	printDelay					equ	2 							;@ задержка перед вvводом "подписи" в секундах
	printPos						DW	1 							;@ положение подписи на экране. 0 - верх, 1 - центр, 2 - низ
	
	;@ заменить на собственнvе даннvе. формирование таблицv идет по строке большей длинv (1я строка).
	signatureLine1				DB	179, '+пак Lгорь -енисович', 179
	Line1_length 					equ	$-signatureLine1
	signatureLine2				DB	179, 'LL5-44                                            ', 179
	Line2_length 					equ	$-signatureLine2
	signatureLine3				DB	179, 'Tариант i22                                        ', 179
	Line3_length 					equ	$-signatureLine3
	helpMsg DB '>tsr.com [/?] [/u]', 10, 13
			DB ' [/?] - вvвод данной справки', 10, 13
			DB '  F1  - вvвод LL+ и группv по таймеру в центре экрана', 10, 13
			DB '  F2  - вклiчение и отклiчения курсивного вvвода русского символа i', 10, 13
			DB '  F3  - вклiчение и отклiчение частичной русификации клавиатурv({WXIO-> -?++-)', 10, 13
			DB '  F4  - вклiчение и отклiчение режима блокировки ввода латинских строчнvх букв', 10, 13			
	helpMsg_length				equ  $-helpMsg                                                                                                                 
	
	errorParamMsg					DB	'+шибка параметров коммандной строки', 10, 13
	errorParamMsg_length			equ	$-errorParamMsg
	
	tableTop						DB	218, Line1_length-2 dup (196), 191
	tableTop_length 				equ	$-tableTop
	tableBottom					DB	192, Line1_length-2 dup (196), 217
	tableBottom_length 			equ  $-tableBottom
	
	; сообения		
	installedMsg					DB  'iезидент загружен!$'
	alreadyInstalledMsg			DB  'iезидент уже загружен$'
	noMemMsg						DB  '=едостаточно памяти$'
	notInstalledMsg				DB  '=е удалось загрузить резидент$'
	
	removedMsg					DB  'iезидент вvгружен'
	removedMsg_length				equ	$-removedMsg
	
	noRemoveMsg					DB  '=е удалось вvгрузить резидент'
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
	
    ;новvй обработчик
    new_int9h proc far
		; сохраняем значения всех, изменяемvх регистров в стэке
		push SI
		push AX
		push BX
		push CX
		push DX
		push ES
		push DS
		; синхронизируем CS и DS
		push CS
		pop	DS

		mov	AX, 40h ; 40h-сегмент,где хранятся флаги сост-я клавиатурv, кольц. буфер ввода 
		mov	ES, AX
		in	AL, 60h	; записvваем в AL скан-код нажатой клавиши
		
		;проверка F2-F5
		_test_Fx:
		sub AL, 58 ; в AL теперь номер функциональной клавиши
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
			call setCursive ; перевод символа в курсив и обратно в зависимости от флага cursiveEnabled
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
				
		;игнорирование и перевод
		_change_translate:
		
		pushf
		call dword ptr CS:[old_int9hOffset] ; вvзvваем стандартнvй обработчик прерvвания
		mov	AX, 40h 	; 40h-сегмент,где хранятся флаги сост-я клавv,кольц. буфер ввода 
		mov	ES, AX
		mov	BX, ES:[1Ch]	; адрес хвоста
		dec	BX	; сместимся назад к последнему
		dec	BX	; введїнному символу
		cmp	BX, 1Eh	; не вvшли ли мv за пределv буфера?
		jae	_go
		mov	BX, 3Ch	; хвост вvшел за пределv буфера, значит последний введїннvй символ
				    ; находится	в конце буфера

	_go:		
		mov DX, ES:[BX] ; в DX 0 введїннvй символ
		;вклiчен ли режим блокировки ввода?
		cmp changeEnabled, true
		jne _check_translate
		
		; да, вклiчен
		mov SI, 0
		mov CX, f5changeLength1 ;кол-во игнорируемvх символов
		
		; проверяем, присутствует ли текуий символ в списке игнорируемvх
	_check_change1:
		cmp DL,f5changeChars1[SI]
		je _change1
		inc SI
	loop _check_change1                   
		mov CX, f5changeLength2 ;кол-во игнорируемvх символов
	_check_change2:
		cmp DL,f5changeChars2[SI]
		je _change2
		inc SI
	loop _check_change2
		jmp _check_translate
		
	; блокируем
	_change1:
		
		;@ если по варианту нужно не блокировать ввод символа,
		;@ а заменять одни символv другими,
		;@ замените строку вvше строкой
		;@  mov ES:[BX], AX
		;@ на месте AX может бvть '*' для заменv всех символов множества ignoredChars на звїздочки
		;@ или, для перевода одних символов в другие - завести массив
		;@ replaceWith DB '...', где перечислить символv, на которvе пойдїт замена
		;@ и раскомментировать строки ниже:
		xor AX, AX
		mov AL,  changeTo1[SI]
		mov ES:[BX], AX	; замена символа
		jmp _quit
	
	_change2:
		xor AX, AX
		mov AL,  changeTo2[SI]
		mov ES:[BX], AX	; замена символа
		jmp _quit
	
	_check_translate:
		; вклiчен ли режим перевода?
		cmp translateEnabled, true
		jne _quit
		
		; да, вклiчен
		mov SI, 0
		mov CX, translateLength ; кол-во символов для перевода
		; проверяем, присутствует ли текуий символ в списке для перевода
		_check_translate_loop:
			cmp DL, translateFrom[SI]
			je _translate
			inc SI
		loop _check_translate_loop
		jmp _quit
		
		; переводим
		_translate:		
			xor AX, AX
			mov AL, translateTo[SI]
			mov ES:[BX], AX	; замена символа
			
	_quit:
		; восстанавливаем все регистрv
		pop	DS
		pop	ES
		pop DX
		pop CX
		pop	BX
		pop	AX
		pop SI
		iret
new_int9h endp  

;=== +бработчик прерvвания int 1Ch ===;
;=== Tvзvвается каждvе 55 мс ===;
new_int1Ch proc far
	push AX
	push CS
	pop DS
	
	pushf
	call dword ptr CS:[old_int1ChOffset]
	
	cmp signaturePrintingEnabled, true ; если нажата управляiая клавиша (в данном случае F1)
	jne _notToPrint		
	
		cmp counter, printDelay*1000/55 + 1 ; если кол-во "тактов" эквивалентно %printDelay% секундам
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

;=== +бработчик прерvвания int 2Fh ===;
;=== Tлужит для:
;===  1) проверки факта присутствия TSR в памяти (при AH=0FFh, AL=0)
;===     будет возвраїн AH='i' в случае, если TSR уже загружен
;===  2) вvгрузки TSR из памяти (при AH=0FFh, AL=1)
;===     
new_int2Fh proc
	cmp	AH, 0FFh	;наша функция?
	jne	_2Fh_std	;нет - на старvй обработчик
	cmp	AL, 0	;подфункция проверки, загружен ли резидент в память?
	je	_already_installed
	cmp	AL, 1	;подфункция вvгрузки из памяти?
	je	_uninstall	
	jmp	_2Fh_std	;нет - на старvй обработчик
	
_2Fh_std:
	jmp	dword ptr CS:[old_int2FhOffset]	;вvзов старого обработчика
	
_already_installed:
		mov	AH, 'i'	;вернїм 'i', если резидент загружен	в память
		iret
	
_uninstall:
	push	DS
	push	ES
	push	DX
	push	BX
	
	xor BX, BX
	
	; CS = ES, для доступа к переменнvм
	push CS
	pop ES
	
	mov	AX, 2509h
	mov DX, ES:old_int9hOffset         ; возврааем вектор прерvвания
    mov DS, ES:old_int9hSegment        ; на место
	int	21h
	
	mov	AX, 251Ch
	mov DX, ES:old_int1ChOffset         ; возврааем вектор прерvвания
    mov DS, ES:old_int1ChSegment        ; на место
	int	21h

	mov	AX, 252Fh
	mov DX, ES:old_int2FhOffset         ; возврааем вектор прерvвания
    mov DS, ES:old_int2FhSegment        ; на место
	int	21h

	mov	ES, CS:2Ch	; загрузим в ES адрес окружения			
	mov	AH, 49h		; вvгрузим из памяти окружение
	int	21h
	jc _notRemove
	
	push	CS
	pop	ES	;в ES - адрес резидентной программv
	mov	AH, 49h  ;вvгрузим из памяти резидент
	int	21h
	jc _notRemove
	jmp _unloaded
	
_notRemove: ; не удалось вvполнить вvгрузку
    ; вvвод сообения о неудачной вvгрузке
	mov AH, 03h					; получаем позициi курсора
	int 10h
	lea BP, noRemoveMsg
	mov CX, noRemoveMsg_length
	mov BL, 0111b
	mov AX, 1301h
	int 10h
	jmp _2Fh_exit
	
_unloaded: ; вvгрузка прошла успешно
    ; вvвод сообения об удачной вvгрузке
	mov AH, 03h					; получаем позициi курсора
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

;=== iроцедура вvвода подписи (LL+, группа)
;=== =астраивается значениями переменнvх в начале исходника
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
	
	mov AH, 03h						;чтение текуей позиции курсора
	int 10h
	push DX							;помеаем информациi о положении курсора в стек
	
	cmp printPos, 0
	je _printTop
	
	cmp printPos, 1
	je _printCenter
	
	cmp printPos, 2
	je _printBottom
	
	;все числа подобранv на глаз...
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
		mov AH, 0Fh					;чтение текуего видеорежима. в BH - текуая страница
		int 10h

		push CS						
		pop ES						;указvваем ES на CS
		
		;вvвод 'верхушки' таблицv
		push DX
		lea BP, tableTop				;помеаем в BP указатель на вvводимуi строку
		mov CX, tableTop_length		;в CX - длина строки
		mov BL, 0111b 				;цвет вvводимого текста ref: http://en.wikipedia.org/wiki/BIOS_color_attributes
		mov AX, 1301h					;AH=13h - номер ф-ии, AL=01h - курсор перемеается при вvводе каждого из символов строки
		int 10h
		pop DX
		inc DH
		
		
		;вvвод первой линии
		push DX
		lea BP, signatureLine1
		mov CX, Line1_length
		mov BL, 0111b
		mov AX, 1301h
		int 10h
		pop DX
		inc DH
		
		;вvвод второй линии
		push DX
		lea BP, signatureLine2
		mov CX, Line2_length
		mov BL, 0111b
		mov AX, 1301h
		int 10h
		pop DX
		inc DH
		
		;вvвод третьей линии
		push DX
		lea BP, signatureLine3
		mov CX, Line3_length
		mov BL, 0111b
		mov AX, 1301h
		int 10h
		pop DX
		inc DH
		
		;вvвод 'низа' таблицv
		push DX
		lea BP, tableBottom
		mov CX, tableBottom_length
		mov BL, 0111b
		mov AX, 1301h
		int 10h
		pop DX
		inc DH
		
		xor BX, BX
		pop DX						;восстанавливаем из стека прежнее положение курсора
		mov AH, 02h					;меняем положение курсора на первоначальное
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

;=== Lункция, которая в зависимости от флага cursiveEnabled меняет начертание символа с курсива на обvчное и наоброт
;=== Tама смена происходит в процедуре changeFont, а здесь подготавливаiтся даннvе
setCursive proc
	push ES ; сохраняем регистрv
	push AX
	push CS
	pop ES

	cmp cursiveEnabled, true
	jne _restoreSymbol
	; если флаг равен true, вvполняем замену символа на курсивнvй вариант,
	; предварительно сохраняя старvй символ в savedSymbol
	
	call saveFont
	mov CL, charToCursiveIndex
_shifTtable:
	; мv получаем в BP таблицу всех символов. адрес указvвает на символ 0
	; поэтому нуэно совершить сдвиг 16*X - где X - код символа
	add BP, 16
	loop _shiftTable
	
	; пpи savefont смеается pегистp ES
	; поэтомy пpиходится делать такие махинации, чтобv 
	; записать полyченнvй элемент в savedSymbol
	; swap(ES, DS) и сохранение старого значения DS
	push DS
	pop AX
	push ES
	pop DS
	push AX
	pop ES
	push AX

	mov SI, BP
	lea DI, savedSymbol
	; сохpаняем в пеpеменнyi savedSymbol
	; таблицy нyжного символа
	mov CX, 16
	; movsb из DS:SI в ES:DI
	rep movsb
	; исходнvе позиции сегментов возвpаенv	
	pop DS ; восстановление DS

	; заменим написание символа на кypсив
	mov CX, 1
	mov DH, 0
	mov DL, charToCursiveIndex
	lea BP, cursiveSymbol
	call changeFont
	jmp _exitSetCursive
	
_restoreSymbol:	
	; если флаг равен 0, вvполняем замену курсивного символа на старvй вариант

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
	
;=== Lункция сменv начертания символа (курсив/нормальное)
;===
; *** входнvе даннvе
; DL = номер символа для заменv
; CX = iол-во символов заменяемvх изображений символов
; (начиная с символа указанного в DX)
; ES:bp = адрес таблицv
;
; *** описание работv процедурv
; iроисходит вvзов int 10h (видеосервис)
; с функцией AH = 11h (функции знакогенератора)
; iараметр AL = 0 сообает, что будет заменено изображение
; символа для текуего шрифта
; T случаях, когда AL = 1 или 2, будет заменено изображение
; только для опредленного шрифта (8x14 и 8x8 соответственно)
; iараметр BH = 0Eh сообает, что на опредление каждого изображения символа
; расходуется по 14 байт (режим 8x14 бит как раз 14 байт)
; iараметр BL = 0 - блок шрифта для загрузки (от 0 до 4)
;
; *** результат
; изображение указанного(vх) символа(ов) будет заменено
; на предложенное пользователем.
; Lзменениi подвергнутся все символv, находяиеся на экране,
; то есть если изображение заменено, старvй вариант нигде уже не проявится

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

;=== Lункция сохранения нормального начертания символа
;===
; *** входнvе даннvе
; BH - тип возврааемой символьной таблицv
;   0 - таблица из int 1fh
;   1 - таблица из int 44h
;   2-5 - таблица из 8x14, 8x8, 8x8 (top), 9x14
;   6 - 8x16
;
; *** описание работv процедурv
; iроисходит вvзов int 10h (видеосервис)
; с функцией AH = 11h (функции знакогенератора)
; iараметр AL = 30 - подфункция получения информации о EGA
;
; *** результат
; в ES:BP находится таблица символов (полная)
; в CX находится байт на символ
; в DL количество экраннvх строк
; TLi=+! iроисходит сдвиг регистра ES
; ( ES становится равнvм C000h )

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


;=== +тсiда начинается вvполнение основной части программv ===;
;===
_initTSR:                         	; старт резидента
	mov AH, 03h
	int 10h
	push DX
	mov AH,00h					; установка видеорежима (83h  текст  80x25  16/8  CGA,EGA  b800  Comp,RGB,Enhanced), без очистки экрана
	mov AL,83h
	int 10h
	pop DX
	mov AH, 02h
	int 10h
	
	
    call commandParamsParser    
	mov AX,3509h                    ; получить в ES:BX вектор 09
    int 21h                         ; прерvвания
	
	;@ === Lдаление резидента из памяти ===
	;@ +сли по варианту необходимо вvгружать резидент по повторному запуску приложений, 
	;@ нужно закомментировать следуiие 3 строки, а также
	;@ содержимое метки _finishTSR ф-ии commandParamsParser, но не саму метку!
	cmp unloadTSR, true
	je _removingOnParameter
	jmp _notRemovingNow

	_removingOnParameter:
		mov AH, 0FFh
		mov AL, 0
		int 2Fh
		cmp AH, 'i'  ; проверка того, загружена ли уже программа
		je _remove 
		mov AH, 09h				;@ для вvгрузки резидента по повторному запуску закомментировать эту строку
		lea DX, notInstalledMsg	;@ для вvгрузки резидента по повторному запуску закомментировать эту строку
		int 21h					;@ для вvгрузки резидента по повторному запуску закомментировать эту строку
		int 20h					;@ для вvгрузки резидента по повторному запуску закомментировать эту строку
	 
	_notRemovingNow:
	
	cmp notLoadTSR, true			; если бvла вvведена справка
	je _exit_tmp						; просто вvходим

	;@ +сли по варианту необходимо вvгружать резидент по повторному запуску, то комментируем 5 строк ниже
	;@ если необходимо вvгружать по параметру коммандной строки, то оставляем их
	mov AH, 0FFh
	mov AL, 0
	int 2Fh
	cmp AH, 'i'  ; проверка того, загружена ли уже программа
	je _alreadyInstalled
    
	jmp _tmp
	
	_exit_tmp:
		jmp _exit
	
	_tmp:
	push ES
    mov AX, DS:[2Ch]                ; psp
    mov ES, AX
    mov AH, 49h                     ; хватит памяти чтоб остаться
    int 21h                         ; резидентом?
    pop ES
    jc _notMem                      ; не хватило - вvходим
	
	;== int 09h ==;

	mov	word ptr CS:old_int9hOffset, BX
	mov	word ptr CS:old_int9hSegment, ES
    mov AX, 2509h                   ; установим вектор на 09
    mov DX, offset new_int9h            ; прерvвание
    int 21h
	
	;== int 1Ch ==;
	mov AX,351Ch                    ; получить в ES:BX вектор 1C
    int 21h                         ; прерvвания
	mov	word ptr CS:old_int1ChOffset, BX
	mov	word ptr CS:old_int1ChSegment, ES
	mov AX, 251Ch                   ; установим вектор на 1C
	mov DX, offset new_int1Ch            ; прерvвание
	int 21h
	
	;== int 2Fh ==;
	mov AX,352Fh                    ; получить в ES:BX вектор 1C
    int 21h                         ; прерvвания
	mov	word ptr CS:old_int2FhOffset, BX
	mov	word ptr CS:old_int2FhSegment, ES
	mov AX, 252Fh                   ; установим вектор на 2F
	mov DX, offset new_int2Fh            ; прерvвание
	int 21h

	call changeFx
    mov DX, offset installedMsg         ; вvводим что все ок
    mov AH, 9
    int 21h
    mov DX, offset _initTSR       ; остаемся в памяти резидентом
    int 27h                         ; и вvходим
    ; конец основной программv  
_remove: ; вvгрузка программv из памяти
	mov AH, 0FFh
	mov AL, 1
	int 2Fh
	jmp _exit
_alreadyInstalled:
	mov AH, 09h
	lea DX, alreadyInstalledMsg
	int 21h
	jmp _exit
_notMem:                            ; не хватает памяти, чтобv остаться резидентом
    mov DX, offset noMemMsg
    mov AH, 9
    int 21h
_exit:                               ; вvход
    int 20h

;=== iроцедура проверки параметров ком. строки ===;
;===
commandParamsParser proc
	push CS
	pop ES
	mov unloadTSR, 0
	mov notLoadTSR, 0
	
	mov SI, 80h   				;SI=смеение командной строки.
	lodsb        					;iолучим кол-во символов.
	or AL, AL     				;+сли 0 символов введено, 
	jz _exitHelp   				;то все в порядке. 

	_nextChar:
	
	inc SI       					;Tеперь SI указvвает на первvй символ строки.
	
	cmp [SI], BYTE ptr 13
	je _exitHelp
	
	
		lodsw       				;iолучаем два символа
		cmp AX, '?/' 				;iто '/?' (даннvе расположенv в обратном порядк, т.е. AL:AH вместо AH:AL)
		je _question
		cmp AX, 'u/'
		je _finishTSR
		
		;cmp AH, '/'
		;je _errorParam
		
		jmp _exitHelp
   
	_question:
		; вvвод строки помои
			mov AH,03
			int 10h	
			lea BP, helpMsg
			mov CX, helpMsg_length
			mov BL, 0111b
			mov AX, 1301h
			int 10h
		; конец вvвода строки помои
		not notLoadTSR	        ;флаг того, что необходимо не загружать резидент
		jmp _nextChar
	
	;@ === Lдаление резидента из памяти ===
	;@ +сли по варианту необходимо вvгружать резидент по параметру '/u' коммандной строки, 
	;@ нужно использовать следуiий код, в остальнvх случаях необходимо закомменитровать 
	;@ этот код, кроме названия метки! (по желаниi можно избавиться и от метки, но аккуратно просмотреть использование)
	_finishTSR:
		not unloadTSR		      ;флаг того, что необходимо вvгузить резидент
		jmp _nextChar

	jmp _exitHelp

	_errorParam:
		;вvвод строки
			mov AH,03
			int 10h	
			lea BP, CS:errorParamMsg
			mov CX, errorParamMsg_length
			mov BL, 0111b
			mov AX, 1301h
			int 10h
		;конец вvвода строки
	_exitHelp:
	ret
commandParamsParser endp

code ends
end _start