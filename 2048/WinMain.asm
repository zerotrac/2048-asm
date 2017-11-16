.386
.model flat, stdcall
option casemap:none

include windows.inc
include gdi32.inc
include user32.inc
include kernel32.inc

includelib gdi32.lib
includelib user32.lib
includelib kernel32.lib

;===== Menu definitions =====
IDM_MAIN     equ   2000h
IDA_MAIN     equ   2000h
IDM_PLAYER   equ   4101h
IDM_TRAIN    equ   4102h
IDM_NEW      equ   4103h
IDM_LOAD     equ   4104h
IDM_SAVE     equ   4105h
IDM_ABOUT    equ   4106h
IDM_EXIT     equ   4107h
;===== Menu definitions =====

;===== Icon definitions =====
ICO_2048     equ   2048h
;============================

;==== Window definitions ====
WINDOW_WIDTH equ 600
WINDOW_HEIGHT equ 950
WINDOW_BIAS equ 10
BOARD_EDGE equ 502
CELL_EDGE equ 108
PATH_WIDTH equ 14
SCORE_WIDTH equ 138
SCORE_HEIGHT equ 55
SCORE_PATH equ 5
NEW_WIDTH equ 128
NEW_HEIGHT equ 40
;============================

;==== Timeer deinitions =====
ID_GLOBAL_TIMER equ 1
MOVE_COUNT equ 5
MOVE_BIG equ 2333
;============================

.data?
hInstance dd ?
hWinMain dd ?
hMenu dd ?
hIcon dd ?

hFont0 dd ?
hFont1 dd ?
hFont2 dd ?
hFont3 dd ?
hFont4 dd ?

hFont_d1 dd ?
hFont_d3 dd ?
hFont_d4 dd ?

hBrush_d2 dd ?
hBrush_d4 dd ?
hBrush_d8 dd ?
hBrush_d16 dd ?
hBrush_d32 dd ?
hBrush_d64 dd ?
hBrush_d128 dd ?
hBrush_d256 dd ?
hBrush_d512 dd ?
hBrush_d1024 dd ?
hBrush_d2048 dd ?

globalTimer dd ?
animationCount dd ?
directions dd ?

.data
gameBoard dd 0, 0, 0, 0,
             0, 0, 0, 0,
             0, 0, 0, 0,
             0, 0, 0, 0
gameBoardBackup dd 0, 0, 0, 0,
                   0, 0, 0, 0,
                   0, 0, 0, 0,
                   0, 0, 0, 0
moveDelta dd 16 DUP(0)
gameScore dd 0
gameOver dd 0
bestScore dd 0
random_seed dd 0

hColor_d1 dd 0656e77h
hColor_d2 dd 0f2f6f9h

.const
direction SBYTE -4, -16, 4, 16
iterate_direction SBYTE 16, 4, -16, -4

szClassName db 'MyClass', 0
szCaptionMain db '2048-asm', 0
szButton db 'button', 0
szButtonText db '&OK', 0
szAboutTitle db '关于游戏', 0
szAboutText db '一个使用汇编的简单2048小游戏', 0dh, 0ah, '使用方向键控制方块的移动', 0
szFormat db '%d', 0
szFontName db 'Clear Sans', 0

sent0 db '2048'
sent1_1 db 'SCORE'
sent1_2 db 'BEST'
sent2 db 'Join the numbers and get to the 2048 tile!'
sent3 db 'New Game'
sent4_1 db 'HOW TO PLAY: Use your arrow keys to move the tiles. When '
sent4_2 db 'two tiles with the same number touch, they merge into one!'

.code
rand PROC
	mov eax, random_seed
	mov ebx, 1103515245
	mul ebx
	add eax, 12345
	mov random_seed, eax
	mov ebx, 65536
	mov edx, 0
	div ebx
	mov ebx, 32768
	mov edx, 0
	div ebx
	mov eax, edx
	ret
rand ENDP

CopyBoard PROC source: DWORD, dest: DWORD
	mov ecx, 16
	mov esi, source
	mov edi, dest
	CopyBoardLoop:
		lodsd
		stosd
	loop CopyBoardLoop
	ret
CopyBoard ENDP

GameClearBoard PROC board: DWORD
	mov edi, board
	mov eax, 0
	mov ecx, 16
	ClearSetZero:
	stosd
	loop ClearSetZero
	ret
GameClearBoard ENDP

GameCountEmptyCell PROC board: DWORD
	mov ebx, 0
	mov esi, board
	mov ecx, 16
	CountEmptyCellLoop:
		lodsd
		.if eax == 0
			inc ebx
		.endif
	loop CountEmptyCellLoop
	mov eax, ebx
	ret
GameCountEmptyCell ENDP

GameProduceNumber PROC board: DWORD, num_empty: DWORD
	local board_end
	call rand
	mov ebx, num_empty
	mov edx, 0
	div ebx

	mov esi, board
	mov ecx, 0

	mov eax, board
	add eax, 64
	mov board_end, eax

	.while esi < board_end
		mov ebx, [esi]
		.if ebx == 0
			.if ecx == edx
				mov ebx, 10
				mov edx, 0
				div ebx
				.if edx == 0
					mov DWORD PTR [esi], 4
				.else
					mov DWORD PTR [esi], 2
				.endif
				ret
			.endif
			inc ecx
		.endif
		add esi, 4
	.endw
	ret
GameProduceNumber ENDP

GameCheckOver PROC board: DWORD
	mov esi, board
	mov ecx, 4
	CheckOverOuterLoop1:
		push ecx
		push esi

		mov ecx, 3
		CheckOverInnerLoop1:
			mov eax, [esi + 4]
			.if [esi] == eax
				pop esi
				pop ecx
				mov eax, 0
				ret
			.endif
			add esi, 4
		loop CheckOverInnerLoop1
		
		pop esi
		pop ecx

		add esi, 16
	loop CheckOverOuterLoop1
	
	mov esi, board
	mov ecx, 4
	CheckOverOuterLoop2:
		push ecx
		push esi

		mov ecx, 3
		CheckOverInnerLoop2:
			mov eax, [esi + 16]
			.if [esi] == eax
				pop esi
				pop ecx
				mov eax, 0
				ret
			.endif
			add esi, 16
		loop CheckOverInnerLoop2
		
		pop esi
		pop ecx

		add esi, 4
	loop CheckOverOuterLoop2

	mov eax, 1
	ret
GameCheckOver ENDP

GameMove PROC board: DWORD, opr: DWORD
	LOCAL operation_success: BYTE
	mov esi, board
	.if opr >= 2
		add esi, 60
	.endif
	mov operation_success, 0
	
	mov eax, opr
	movsx ebx, direction[eax]

	mov ecx, 0
	.while ecx < 4
		push ecx
		push esi

		mov edi, esi
		mov ecx, 0
		
		.while ecx < 3
			sub esi, ebx
			mov eax, [esi]
			.if eax != 0
				.if eax != [edi]
					mov eax, [edi]
					.if eax != 0
						sub edi, ebx
					.endif

					.if edi != esi
						mov operation_success, 1
						mov eax, [esi]
						mov [edi], eax
						mov eax, 0
						mov [esi], eax
					.endif
				.else
					mov edx, 2
					mul edx
					mov DWORD PTR [edi], eax
					add gameScore, eax

					mov eax, 0
					mov [esi], eax
					sub edi, ebx
					mov operation_success, 1
				.endif
			.endif
			inc ecx
		.endw

		pop esi
		mov eax, opr
		movsx ecx, iterate_direction[eax]
		add esi, ecx

		pop ecx
		inc ecx
	.endw

	mov al, operation_success
	ret
GameMove ENDP

GameOperate PROC board: DWORD, opr: DWORD
	LOCAL operation_success: BYTE

	invoke GameMove, board, opr
	mov operation_success, al

	mov eax, gameScore
	.if eax > bestScore
		mov bestScore, eax
	.endif

	.if operation_success == 1
		invoke GameCountEmptyCell, board
		push eax
		invoke GameProduceNumber, board, eax
		pop eax
		dec eax
		.if eax == 0
			invoke GameCheckOver, board
			mov gameOver, eax
		.endif
	.endif
	ret
GameOperate ENDP

GameLazyOperate PROC opr: DWORD
	local oprDir: DWORD, oprIterDir: DWORD
	invoke GameClearBoard, offset moveDelta
	mov esi, offset gameBoard
	mov edi, offset moveDelta
	.if opr >= 2
		add esi, 60
		add edi, 60
	.endif
	
	mov eax, opr
	movsx ebx, direction[eax]
	mov oprDir, ebx

	mov eax, opr
	movsx ebx, iterate_direction[eax]
	mov oprIterDir, ebx

	mov ecx, 0
	.while ecx < 4
		push ecx
		push esi
		push edi

		mov ecx, 1
		mov edx, 0  ; Move distance
		mov ebx, [esi]  ; Last number
		.if ebx == 0
			inc edx
		.endif
		
		.while ecx <= 3
			sub esi, oprDir
			sub edi, oprDir
			mov eax, [esi]
			.if eax != 0
				.if eax != ebx
					mov [edi], edx
					mov ebx, eax
				.else
					inc edx
					mov [edi], edx
					mov ebx, 0
				.endif
			.else
				inc edx
			.endif
			inc ecx
		.endw

		pop edi
		add edi, oprIterDir

		pop esi
		add esi, oprIterDir

		pop ecx
		inc ecx
	.endw
	ret
GameLazyOperate ENDP

GameInit PROC
	invoke GameClearBoard, offset gameBoard
	invoke GameProduceNumber, offset gameBoard, 16
	invoke GameProduceNumber, offset gameBoard, 15
	mov gameScore, 0
	mov gameOver, 0
	ret
GameInit ENDP

GameTreeSearchOperate PROTO board: DWORD, depth: DWORD

GameTreeSearchRandom PROC board: DWORD, depth: DWORD
	local new_board[16]: DWORD, num_empty_cell: DWORD, node_score: DWORD

	invoke GameCountEmptyCell, board
	mov num_empty_cell, eax
	mov node_score, 0

	mov ecx, 10
	GameTreeSearchRandomLoop:
		push ecx

		invoke CopyBoard, board, addr new_board
		invoke GameProduceNumber, addr new_board, num_empty_cell
		mov eax, depth
		inc eax
		invoke GameTreeSearchOperate, addr new_board, eax
		add node_score, eax

		pop ecx
	loop GameTreeSearchRandomLoop

	mov eax, node_score
	mov ebx, 10
	mov edx, 0
	div ebx
	ret
GameTreeSearchRandom ENDP

GameTreeSearchOperate PROC board: DWORD, depth: DWORD
	local new_board[16]: DWORD, board_score: DWORD, num_empty_cell: DWORD
	local max_score: DWORD, operation: DWORD, board_game_over: BYTE
	invoke GameCountEmptyCell, board
	mov num_empty_cell, eax
	mov max_score, 0
	mov board_game_over, 0

	mov eax, gameScore
	mov board_score, eax

	.if num_empty_cell == 0
		invoke GameCheckOver, board
		mov board_game_over, al
	.endif

	.if depth >= 6 || board_game_over == 1
		mov eax, num_empty_cell
		mov ebx, gameScore
		bsr edx, ebx
		add eax, edx
		ret
	.endif

	mov ecx, 0
	.while ecx < 4
		mov operation, ecx

		invoke CopyBoard, board, addr new_board

		invoke GameMove, addr new_board, operation
		.if al == 1
			mov eax, depth
			inc eax
			invoke GameTreeSearchRandom, addr new_board, eax

			.if eax > max_score
				mov max_score, eax
			.endif
		.endif

		mov eax, board_score
		mov gameScore, eax
		
		mov ecx, operation
		inc ecx
	.endw

	mov eax, max_score
	ret
GameTreeSearchOperate ENDP

GameAutoStep PROC
	local board[16]: DWORD, board_score: DWORD, max_score: DWORD
	local operation: DWORD, best_operation: DWORD
	mov max_score, 0
	mov best_operation, 0

	mov eax, gameScore
	mov board_score, eax

	mov ecx, 0
	.while ecx < 4
		mov operation, ecx

		invoke CopyBoard, offset gameBoard, addr board

		invoke GameMove, addr board, operation
		.if al == 1
			invoke GameTreeSearchRandom, addr board, 1
			.if eax > max_score
				mov max_score, eax
				mov ecx, operation
				mov best_operation, ecx
			.endif
		.endif
		
		mov eax, board_score
		mov gameScore, eax
		
		mov ecx, operation
		inc ecx
	.endw

	invoke GameOperate, offset gameBoard, best_operation

	ret
GameAutoStep ENDP

_DisplayAbout proc
    pushad
    invoke MessageBox, hWinMain, addr szAboutText, addr szAboutTitle, MB_OK
    popad
    ret
_DisplayAbout endp

 _Quit proc
    invoke DestroyWindow, hWinMain
    invoke PostQuitMessage, NULL
    ret
_Quit endp

_GetPosition proc,
    _StartX, _StartY, _dX, _dY
    
    local @RetX, @RetY

    mov eax, _StartX
    mov @RetX, eax
    add @RetX, PATH_WIDTH
    mov eax, _StartY
    mov @RetY, eax
    add @RetY, PATH_WIDTH

    .while _dX > 0
        add @RetX, CELL_EDGE
        add @RetX, PATH_WIDTH
        dec _dX
    .endw
    .while _dY > 0
        add @RetY, CELL_EDGE
        add @RetY, PATH_WIDTH
        dec _dY
    .endw

    mov eax, @RetX
    mov ebx, @RetY
    ret
_GetPosition endp

_GetPositionPlus proc,
    _StartX, _StartY, _dX, _dY, _dT

    local @RetX, @RetY, @RetT

    mov eax, _StartX
    mov @RetX, eax
    add @RetX, PATH_WIDTH
    mov eax, _StartY
    mov @RetY, eax
    add @RetY, PATH_WIDTH

    .while _dX > 0
        add @RetX, CELL_EDGE
        add @RetX, PATH_WIDTH
        dec _dX
    .endw
    .while _dY > 0
        add @RetY, CELL_EDGE
        add @RetY, PATH_WIDTH
        dec _dY
    .endw

    mov @RetT, 0
    .while _dT > 0
        add @RetT, CELL_EDGE
        add @RetT, PATH_WIDTH
        dec _dT
    .endw
    
    mov eax, @RetT
    mov edx, 0
    mov ebx, MOVE_COUNT
    div ebx
    mov edx, 0
    mov ebx, animationCount
    sub ebx, MOVE_COUNT
    neg ebx
    mul ebx

    .if directions == 0
        sub @RetX, eax
    .elseif directions == 1
        sub @RetY, eax
    .elseif directions == 2
        add @RetX, eax
    .else
        add @RetY, eax
    .endif

    mov eax, @RetX
    mov ebx, @RetY
    ret
_GetPositionPlus endp

_DrawDigit proc,
    _hDc, _cellStartX, _cellStartY, _num

    local @cellEndX, @cellEndY
    local @digitStartX, @digitStartY
    local @szBuffer[10]: byte

    .if _num == 0
        ret
    .endif

    pushad
    
    mov eax, _cellStartX
    mov @cellEndX, eax
    add @cellEndX, CELL_EDGE
    mov eax, _cellStartY
    mov @cellEndY, eax
    add @cellEndY, CELL_EDGE
    
    .if _num == 2
        invoke SelectObject, _hDc, hBrush_d2
    .elseif _num == 4
        invoke SelectObject, _hDc, hBrush_d4
    .elseif _num == 8
        invoke SelectObject, _hDc, hBrush_d8
    .elseif _num == 16
        invoke SelectObject, _hDc, hBrush_d16
    .elseif _num == 32
        invoke SelectObject, _hDc, hBrush_d32
    .elseif _num == 64
        invoke SelectObject, _hDc, hBrush_d64
    .elseif _num == 128
        invoke SelectObject, _hDc, hBrush_d128
    .elseif _num == 256
        invoke SelectObject, _hDc, hBrush_d256
    .elseif _num == 512
        invoke SelectObject, _hDc, hBrush_d512
    .elseif _num == 1024
        invoke SelectObject, _hDc, hBrush_d1024
    .else
        invoke SelectObject, _hDc, hBrush_d2048
    .endif
    invoke RoundRect, _hDc, _cellStartX, _cellStartY, @cellEndX, @cellEndY, 3, 3
            
    .if _num < 8
        invoke SetTextColor, _hDc, hColor_d1
    .else
        invoke SetTextColor, _hDc, hColor_d2
    .endif

    mov eax, _cellStartX
    mov @digitStartX, eax
    mov eax, _cellStartY
    mov @digitStartY, eax

    .if _num < 10
        invoke SelectObject, _hDc, hFont_d1
        add @digitStartX, 37
        add @digitStartY, 18
    .elseif _num < 100
        invoke SelectObject, _hDc, hFont_d1
        add @digitStartX, 21
        add @digitStartY, 18
    .elseif _num < 1000
        invoke SelectObject, _hDc, hFont_d3
        add @digitStartX, 13
        add @digitStartY, 24
    .else
        invoke SelectObject, _hDc, hFont_d4
        add @digitStartX, 12
        add @digitStartY, 31
    .endif

    invoke wsprintf, addr @szBuffer, addr szFormat, _num
    invoke TextOut, _hDc, @digitStartX, @digitStartY, addr @szBuffer, eax

    popad
    ret
_DrawDigit endp

_DrawBoard proc,
    _hWnd, hDc

    local @boardStartX, @boardStartY, @boardEndX, @boardEndY
    local @cellStartX, @cellStartY, @cellEndX, @cellEndY
    local @scoreStartX, @scoreStartY, @scoreEndX, @scoreEndY
    local @bestStartX, @bestStartY, @bestEndX, @bestEndY
    local @newStartX, @newStartY, @newEndX, @newEndY
    local @bghDc, @digit
    local @x, @y, @len, @bias
    local @szBuffer[10]: byte
    local _hDc, _cptBmp
    
    pushad

    invoke CreateCompatibleDC, hDc
    mov _hDc, eax
    invoke CreateCompatibleBitmap, hDc, WINDOW_WIDTH, WINDOW_HEIGHT
    mov _cptBmp, eax
    invoke SelectObject, _hDc, _cptBmp

    invoke CreateSolidBrush, 0eff8fah
    invoke SelectObject, _hDc, eax
    invoke DeleteObject, eax
    invoke Rectangle, _hDc, -5, -5, WINDOW_WIDTH, WINDOW_HEIGHT

    mov @boardStartX, (WINDOW_WIDTH - BOARD_EDGE) / 2 - WINDOW_BIAS
    mov @boardStartY, 225
    mov @boardEndX, (WINDOW_WIDTH + BOARD_EDGE) / 2 - WINDOW_BIAS
    mov @boardEndY, BOARD_EDGE + 225
    
    mov eax, @boardEndX
    mov @bestEndX, eax
    sub eax, SCORE_WIDTH
    mov @bestStartX, eax
    mov @bestStartY, 35
    mov @bestEndY, SCORE_HEIGHT + 35

    sub eax, SCORE_PATH
    mov @scoreEndX, eax
    sub eax, SCORE_WIDTH
    mov @scoreStartX, eax
    mov @scoreStartY, 35
    mov @scoreEndY, SCORE_HEIGHT + 35

    mov eax, @boardEndX
    mov @newEndX, eax
    sub eax, NEW_WIDTH
    mov @newStartX, eax
    mov @newStartY, 142
    mov @newEndY, NEW_HEIGHT + 142

    invoke GetStockObject, NULL_PEN
    invoke SelectObject, _hDc, eax
    invoke CreateSolidBrush, 0a0adbbh
    invoke SelectObject, _hDc, eax
    invoke DeleteObject, eax
    invoke RoundRect, _hDc, @boardStartX, @boardStartY, @boardEndX, @boardEndY, 6, 6
    
    invoke SetBkMode, _hDc, TRANSPARENT
    
    invoke SelectObject, _hDc, hFont0
    invoke SetTextColor, _hDc, 0656e77h
    invoke TextOut, _hDc, @boardStartX, 30, addr sent0, lengthof sent0

    invoke RoundRect, _hDc, @scoreStartX, @scoreStartY, @scoreEndX, @scoreEndY, 3, 3
    invoke RoundRect, _hDc, @bestStartX, @bestStartY, @bestEndX, @bestEndY, 3, 3

    invoke SelectObject, _hDc, hFont1
    invoke SetTextColor, _hDc, 0dae4eeh
    mov eax, @scoreStartX
    mov ebx, @scoreStartY
    add eax, 48
    add ebx, 6
    invoke TextOut, _hDc, eax, ebx, addr sent1_1, lengthof sent1_1
    mov eax, @bestStartX
    mov ebx, @bestStartY
    add eax, 53
    add ebx, 6
    invoke TextOut, _hDc, eax, ebx, addr sent1_2, lengthof sent1_2

    invoke SelectObject, _hDc, hFont4
    invoke SetTextColor, _hDc, 0ffffffh
    invoke wsprintf, addr @szBuffer, addr szFormat, gameScore
    mov @len, eax
    mov edx, 0
    mov ebx, 15
    mul ebx
    sub eax, SCORE_WIDTH
    neg eax
    shr eax, 1
    add eax, @scoreStartX
    add eax, 1
    mov @x, eax
    mov @y, 55
    invoke TextOut, _hDc, @x, @y, addr @szBuffer, @len

    invoke SetTextColor, _hDc, 0ffffffh
    invoke wsprintf, addr @szBuffer, addr szFormat, bestScore
    mov @len, eax
    mov edx, 0
    mov ebx, 15
    mul ebx
    sub eax, SCORE_WIDTH
    neg eax
    shr eax, 1
    add eax, @bestStartX
    add eax, 1
    mov @x, eax
    mov @y, 55
    invoke TextOut, _hDc, @x, @y, addr @szBuffer, @len

    invoke SelectObject, _hDc, hFont2
    invoke SetTextColor, _hDc, 0656e77h
    invoke TextOut, _hDc, @boardStartX, 150, addr sent2, lengthof sent2

    invoke CreateSolidBrush, 0667a8fh
    invoke SelectObject, _hDc, eax
    invoke DeleteObject, eax
    invoke RoundRect, _hDc, @newStartX, @newStartY, @newEndX, @newEndY, 3, 3

    invoke SelectObject, _hDc, hFont3
    invoke SetTextColor, _hDc, 0f2f6f9h
    mov eax, @newStartX
    mov ebx, @newStartY
    add eax, 20
    add ebx, 7
    invoke TextOut, _hDc, eax, ebx, addr sent3, lengthof sent3

    invoke SelectObject, _hDc, hFont2
    invoke SetTextColor, _hDc, 0656e77h
    invoke TextOut, _hDc, @boardStartX, 780, addr sent4_1, lengthof sent4_1
    invoke TextOut, _hDc, @boardStartX, 810, addr sent4_2, lengthof sent4_2

    invoke CreateSolidBrush, 0b4c1cdh
    mov @bghDc, eax
    
    mov eax, @boardStartY
    add eax, PATH_WIDTH
    mov @cellStartY, eax
    add eax, CELL_EDGE
    mov @cellEndY, eax

    mov ecx, 0
    .while ecx < 4
        mov eax, @boardStartX
        add eax, PATH_WIDTH
        mov @cellStartX, eax
        add eax, CELL_EDGE
        mov @cellEndX, eax

        push ecx
        mov ecx, 0
        .while ecx < 4
            push ecx
            invoke SelectObject, _hDc, @bghDc
            invoke RoundRect, _hDc, @cellStartX, @cellStartY, @cellEndX, @cellEndY, 3, 3
            pop ecx
            add @cellStartX, CELL_EDGE + PATH_WIDTH
            add @cellEndX, CELL_EDGE + PATH_WIDTH
            inc ecx
        .endw
        pop ecx
        inc ecx
        add @cellStartY, CELL_EDGE + PATH_WIDTH
        add @cellEndY, CELL_EDGE + PATH_WIDTH
    .endw

    mov esi, offset gameBoard
    mov edi, offset moveDelta

    .if animationCount > 0
        .if directions == 0
            mov @y, 0
            .while @y < 4
                mov @x, 3
                .while @x >= 0
                    mov @bias, 0
                    mov eax, @y
                    shl eax, 4
                    add @bias, eax
                    mov eax, @x
                    shl eax, 2
                    add @bias, eax

                    add esi, @bias
                    add edi, @bias
                    invoke _GetPositionPlus, @boardStartX, @boardStartY, @x, @y, DWORD ptr [edi]
                    invoke _DrawDigit, _hDc, eax, ebx, DWORD ptr [esi]
                    sub esi, @bias
                    sub edi, @bias
                    .break .if @x == 0
                    dec @x
                .endw
                inc @y
            .endw
        .elseif directions == 1
            mov @y, 3
            .while @y >= 0
                mov @x, 0
                .while @x < 4
                    mov @bias, 0
                    mov eax, @y
                    shl eax, 4
                    add @bias, eax
                    mov eax, @x
                    shl eax, 2
                    add @bias, eax

                    add esi, @bias
                    add edi, @bias
                    invoke _GetPositionPlus, @boardStartX, @boardStartY, @x, @y, DWORD ptr [edi]
                    invoke _DrawDigit, _hDc, eax, ebx, DWORD ptr [esi]
                    sub esi, @bias
                    sub edi, @bias
                    inc @x
                .endw
                .break .if @y == 0
                dec @y
            .endw
        .elseif directions == 2
            mov @y, 0
            .while @y < 4
                mov @x, 0
                .while @x < 4
                    mov @bias, 0
                    mov eax, @y
                    shl eax, 4
                    add @bias, eax
                    mov eax, @x
                    shl eax, 2
                    add @bias, eax

                    add esi, @bias
                    add edi, @bias
                    invoke _GetPositionPlus, @boardStartX, @boardStartY, @x, @y, DWORD ptr [edi]
                    invoke _DrawDigit, _hDc, eax, ebx, DWORD ptr [esi]
                    sub esi, @bias
                    sub edi, @bias
                    inc @x
                .endw
                inc @y
            .endw
        .else       
            mov @y, 0
            .while @y < 4
                 mov @x, 0
                .while @x < 4
                    mov @bias, 0
                    mov eax, @y
                    shl eax, 4
                    add @bias, eax
                    mov eax, @x
                    shl eax, 2
                    add @bias, eax

                    add esi, @bias
                    add edi, @bias
                    invoke _GetPositionPlus, @boardStartX, @boardStartY, @x, @y, DWORD ptr [edi]
                    invoke _DrawDigit, _hDc, eax, ebx, DWORD ptr [esi]
                    sub esi, @bias
                    sub edi, @bias
                    inc @x
                .endw
                inc @y
            .endw
        .endif
    .else
        mov @y, 0
        .while @y < 4
            mov @x, 0
            .while @x < 4
                mov edi, esi
                mov eax, @y
                shl eax, 4
                add edi, eax
                mov eax, @x
                shl eax, 2
                add edi, eax

                invoke _GetPosition, @boardStartX, @boardStartY, @x, @y
                invoke _DrawDigit, _hDc, eax, ebx, DWORD ptr [edi]
                inc @x
            .endw
            inc @y
        .endw
    .endif
    COMMENT /*
    invoke SelectObject, _hDc, hFont3
    invoke SetTextColor, _hDc, 0000000h
    
    mov esi, offset gameBoard
    mov ecx, 4
    mov @y, 400
    .while ecx > 0
        mov @x, 100
        push ecx
        mov ecx, 4
        .while ecx > 0
            push ecx
            invoke wsprintf, addr @szBuffer, addr szFormat, DWORD ptr [esi]
            invoke TextOut, _hDc, @x, @y, addr @szBuffer, eax
            add esi, type DWORD
            add @x, 20
            pop ecx
            dec ecx
        .endw
        add @y, 20
        pop ecx
        dec ecx
    .endw
    
    mov esi, offset gameBoardBackup
    mov ecx, 4
    mov @y, 400
    .while ecx > 0
        mov @x, 200
        push ecx
        mov ecx, 4
        .while ecx > 0
            push ecx
            invoke wsprintf, addr @szBuffer, addr szFormat, DWORD ptr [esi]
            invoke TextOut, _hDc, @x, @y, addr @szBuffer, eax
            add esi, type DWORD
            add @x, 20
            pop ecx
            dec ecx
        .endw
        add @y, 20
        pop ecx
        dec ecx
    .endw

    mov esi, offset moveDelta
    mov ecx, 4
    mov @y, 400
    .while ecx > 0
        mov @x, 300
        push ecx
        mov ecx, 4
        .while ecx > 0
            push ecx
            invoke wsprintf, addr @szBuffer, addr szFormat, DWORD ptr [esi]
            invoke TextOut, _hDc, @x, @y, addr @szBuffer, eax
            add esi, type DWORD
            add @x, 20
            pop ecx
            dec ecx
        .endw
        add @y, 20
        pop ecx
        dec ecx
    .endw
    */
    invoke BitBlt, hDc, 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, _hDc, 0, 0, SRCCOPY
    
    invoke DeleteObject, @bghDc
    invoke DeleteObject, _cptBmp
    invoke DeleteDC, _hDc
    popad
    ret
_DrawBoard endp

_ProcWinMain proc uses ebx edi esi,
    hWnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM
    
    local @stPs: PAINTSTRUCT
    local @hDc
                                                                               
    mov eax,uMsg
    .if eax == WM_CREATE
        invoke CheckMenuRadioItem, hMenu, IDM_PLAYER, IDM_TRAIN, IDM_PLAYER, MF_BYCOMMAND
    .elseif eax == WM_COMMAND
        mov eax, wParam
        movzx eax, ax
        .if eax == IDM_EXIT
            invoke _Quit
        .elseif eax == IDM_ABOUT
            invoke _DisplayAbout
        .elseif eax == IDM_PLAYER
            invoke CheckMenuRadioItem, hMenu, IDM_PLAYER, IDM_TRAIN, eax, MF_BYCOMMAND
			invoke GameInit
            invoke CopyBoard, addr gameBoard, addr gameBoardBackup
        .elseif eax == IDM_TRAIN
            invoke CheckMenuRadioItem, hMenu, IDM_PLAYER, IDM_TRAIN, eax, MF_BYCOMMAND
        .endif
        mov animationCount, 0
        invoke InvalidateRect, hWnd, NULL, FALSE
    .elseif eax == WM_KEYDOWN
        mov eax, wParam
        .if eax == VK_UP
            invoke CopyBoard, addr gameBoardBackup, addr gameBoard
            invoke GameLazyOperate, 1
            invoke GameOperate, addr gameBoardBackup, 1
            mov animationCount, MOVE_COUNT
            mov directions, 1
        .elseif eax == VK_DOWN
            invoke CopyBoard, addr gameBoardBackup, addr gameBoard
            invoke GameLazyOperate, 3
            invoke GameOperate, addr gameBoardBackup, 3
            mov animationCount, MOVE_COUNT
            mov directions, 3
        .elseif eax == VK_LEFT
            invoke CopyBoard, addr gameBoardBackup, addr gameBoard
            invoke GameLazyOperate, 0
            invoke GameOperate, addr gameBoardBackup, 0
            mov animationCount, MOVE_COUNT
            mov directions, 0
        .elseif eax == VK_RIGHT
            invoke CopyBoard, addr gameBoardBackup, addr gameBoard
            invoke GameLazyOperate, 2
            invoke GameOperate, addr gameBoardBackup, 2
            mov animationCount, MOVE_COUNT
            mov directions, 2
        .endif
    .elseif eax == WM_TIMER
        .if animationCount > 0 && animationCount <= MOVE_COUNT
            invoke InvalidateRect, hWnd, NULL, FALSE
            dec animationCount
            .if animationCount == 0
                invoke CopyBoard, addr gameBoardBackup, addr gameBoard
            ;invoke InvalidateRect, hWnd, NULL, FALSE
            .endif
        .endif
    .elseif eax == WM_PAINT
        invoke BeginPaint, hWnd, addr @stPs
        mov @hDc, eax
        invoke _DrawBoard, hWnd, @hDc
        invoke EndPaint, hWnd, addr @stPs
    .elseif eax == WM_CLOSE
        invoke _Quit
    .else
        invoke DefWindowProc, hWnd, uMsg, wParam, lParam
        ret
    .endif
                                                                      
    xor eax, eax
    ret
_ProcWinMain endp

_WinMain proc
    local @stWndClass: WNDCLASSEX
    local @stMsg: MSG
    local @hAccelerator
                                                                               
    invoke GetModuleHandle, NULL
    mov hInstance, eax

    invoke LoadIcon, hInstance, ICO_2048
    mov hIcon, eax

    invoke LoadMenu, hInstance, IDM_MAIN
    mov hMenu, eax

    invoke CreateFont, 105, 48, 0, 0, FW_BOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_CHARACTER_PRECIS, CLIP_CHARACTER_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, addr szFontName
    mov hFont0, eax
    invoke CreateFont, 20, 8, 0, 0, FW_BOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_CHARACTER_PRECIS, CLIP_CHARACTER_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, addr szFontName
    mov hFont1, eax
    invoke CreateFont, 26, 11, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_CHARACTER_PRECIS, CLIP_CHARACTER_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, addr szFontName
    mov hFont2, eax
    invoke CreateFont, 26, 11, 0, 0, FW_BLACK, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_CHARACTER_PRECIS, CLIP_CHARACTER_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, addr szFontName
    mov hFont3, eax
    invoke CreateFont, 33, 15, 0, 0, FW_BLACK, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_CHARACTER_PRECIS, CLIP_CHARACTER_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, addr szFontName
    mov hFont4, eax

    invoke CreateFont, 72, 33, 0, 0, FW_BLACK, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_CHARACTER_PRECIS, CLIP_CHARACTER_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, addr szFontName
    mov hFont_d1, eax
    invoke CreateFont, 59, 27, 0, 0, FW_BLACK, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_CHARACTER_PRECIS, CLIP_CHARACTER_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, addr szFontName
    mov hFont_d3, eax
    invoke CreateFont, 46, 21, 0, 0, FW_BLACK, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_CHARACTER_PRECIS, CLIP_CHARACTER_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, addr szFontName
    mov hFont_d4, eax

    invoke CreateSolidBrush, 0dae4eeh
    mov hBrush_d2, eax
    invoke CreateSolidBrush, 0c8e0edh
    mov hBrush_d4, eax
    invoke CreateSolidBrush, 079b1f2h
    mov hBrush_d8, eax
    invoke CreateSolidBrush, 06395f5h
    mov hBrush_d16, eax
    invoke CreateSolidBrush, 05f7cf6h
    mov hBrush_d32, eax
    invoke CreateSolidBrush, 03b5ef6h
    mov hBrush_d64, eax
    invoke CreateSolidBrush, 072cfedh
    mov hBrush_d128, eax
    invoke CreateSolidBrush, 061ccedh
    mov hBrush_d256, eax
    invoke CreateSolidBrush, 050c8edh
    mov hBrush_d512, eax
    invoke CreateSolidBrush, 03fc5edh
    mov hBrush_d1024, eax
    invoke CreateSolidBrush, 02ec2edh
    mov hBrush_d2048, eax

    invoke LoadAccelerators, hInstance, IDA_MAIN
    mov @hAccelerator, eax

    invoke RtlZeroMemory, addr @stWndClass, sizeof @stWndClass
                                                                               
    invoke LoadCursor, 0, IDC_ARROW
    mov @stWndClass.hCursor, eax
    push hInstance
    pop @stWndClass.hInstance
    mov @stWndClass.cbSize, sizeof WNDCLASSEX
    mov @stWndClass.style, CS_HREDRAW or CS_VREDRAW
    mov @stWndClass.lpfnWndProc, offset _ProcWinMain
    mov @stWndClass.lpszClassName, offset szClassName
    push hIcon
    pop @stWndClass.hIcon

    invoke RegisterClassEx, addr @stWndClass
                                                                               
    invoke CreateWindowEx, WS_EX_CLIENTEDGE, offset szClassName, offset szCaptionMain, WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX, 100, 100, WINDOW_WIDTH, WINDOW_HEIGHT, NULL, hMenu, hInstance, NULL
    mov hWinMain, eax

    invoke ShowWindow, hWinMain, SW_SHOWNORMAL

    invoke UpdateWindow, hWinMain

    invoke SetTimer, hWinMain, ID_GLOBAL_TIMER, 10, NULL
                                                                               
    .while TRUE
        invoke GetMessage, addr @stMsg, NULL, 0, 0
        .break .if eax == 0
        invoke TranslateAccelerator, hWinMain, @hAccelerator, addr @stMsg
        invoke TranslateMessage, addr @stMsg
        invoke DispatchMessage, addr @stMsg
    .endw
    ret

_WinMain endp

start:
    call _WinMain
    invoke ExitProcess, NULL
end start
