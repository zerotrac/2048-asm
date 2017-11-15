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
WINDOW_HEIGHT equ 1000
WINDOW_BIAS equ 10
BOARD_EDGE equ 502
CELL_EDGE equ 108
PATH_WIDTH equ 14

;============================

.data?
hInstance dd ?
hWinMain dd ?
hMenu dd ?
hIcon dd ?

.data
gameBoard dd 0, 0, 0, 0,
             0, 0, 0, 0,
             0, 0, 0, 0,
             0, 0, 0, 0
gameScore dd 0
bestScore dd 0
random_seed dd 0

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

GameCountEmptyCell PROC
	mov ebx, 0
	mov esi, offset gameBoard
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

GameProduceNumber PROC num_empty: DWORD
	call rand
	mov ebx, num_empty
	mov edx, 0
	div ebx

	mov esi, offset gameBoard
	mov ecx, 0
	.while esi < offset gameBoard + 64
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

GameCheckOver PROC
	ret
GameCheckOver ENDP

GameOperate PROC opr: DWORD
	LOCAL operation_success: BYTE
	mov esi, offset gameBoard
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

	.if operation_success == 1
		invoke GameCountEmptyCell
		push eax
		invoke GameProduceNumber, eax
		pop eax
		.if eax == 0
			; check_game_end
		.endif
	.endif
	ret
GameOperate ENDP

; game_board is an zero-filled array whose size is 16
GameInit PROC
	mov edi, offset gameBoard
	mov eax, 0
	mov ecx, 16
	InitSetZero:
	stosd
	loop InitSetZero
	invoke GameProduceNumber, 16
	invoke GameProduceNumber, 15
	mov gameScore, 0
	ret
GameInit ENDP

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

_DrawBoard proc,
    _hWnd, _hDc

    local @boardStartX, @boardStartY, @boardEndX, @boardEndY
    local @cellStartX, @cellStartY, @cellEndX, @cellEndY
    local @szBuffer[10]: byte

    mov @boardStartX, (WINDOW_WIDTH - BOARD_EDGE) / 2 - WINDOW_BIAS
    mov @boardStartY, 100
    mov @boardEndX, (WINDOW_WIDTH + BOARD_EDGE) / 2 - WINDOW_BIAS
    mov @boardEndY, BOARD_EDGE + 100

    pushad

    invoke SetBkMode, _hDc, TRANSPARENT
    invoke SetTextColor, _hDc, 0h

    invoke GetStockObject, NULL_PEN
    invoke SelectObject, _hDc, eax
    invoke CreateSolidBrush, 0a0adbbh
    invoke SelectObject, _hDc, eax
    invoke DeleteObject, eax
    invoke RoundRect, _hDc, @boardStartX, @boardStartY, @boardEndX, @boardEndY, 6, 6

    invoke CreateSolidBrush, 0b4c1cdh
    invoke SelectObject, _hDc, eax
    invoke DeleteObject, eax
    
    mov eax, @boardStartY
    add eax, PATH_WIDTH
    mov @cellStartY, eax
    add eax, CELL_EDGE
    mov @cellEndY, eax

    mov ecx, 0
    mov esi, offset gameBoard
    .WHILE ecx < 4
        mov eax, @boardStartX
        add eax, PATH_WIDTH
        mov @cellStartX, eax
        add eax, CELL_EDGE
        mov @cellEndX, eax

        push ecx
        mov ecx, 0
        .WHILE ecx < 4
            push ecx
            invoke RoundRect, _hDc, @cellStartX, @cellStartY, @cellEndX, @cellEndY, 3, 3

            invoke wsprintf, addr @szBuffer, addr szFormat,  DWORD ptr [esi]
            invoke TextOut, _hDc, @cellStartX, @cellStartY, addr @szBuffer, eax
;           	TCHAR	szDist[13];

;	TextOut(hdcBuffer, WNDWIDTH - 100, 15, szDist, wsprintf(szDist, _T("距离:%d"), m_gameStatus.totalDist));
            pop ecx
            add @cellStartX, CELL_EDGE + PATH_WIDTH
            add @cellEndX, CELL_EDGE + PATH_WIDTH
            inc ecx
            add esi, TYPE DWORD
        .ENDW
        pop ecx
        inc ecx
        add @cellStartY, CELL_EDGE + PATH_WIDTH
        add @cellEndY, CELL_EDGE + PATH_WIDTH
    .ENDW

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
        .elseif eax == IDM_TRAIN
            invoke CheckMenuRadioItem, hMenu, IDM_PLAYER, IDM_TRAIN, eax, MF_BYCOMMAND
        .endif
        invoke InvalidateRect, hWnd, NULL, FALSE
    .elseif eax == WM_KEYDOWN
        mov eax, wParam
        .if eax == VK_UP
            invoke GameOperate, 1
            invoke InvalidateRect, hWnd, NULL, FALSE
        .elseif eax == VK_DOWN
            invoke GameOperate, 3
            invoke InvalidateRect, hWnd, NULL, FALSE
        .elseif eax == VK_LEFT
            invoke GameOperate, 0
            invoke InvalidateRect, hWnd, NULL, FALSE
        .elseif eax == VK_RIGHT
            invoke GameOperate, 2
            invoke InvalidateRect, hWnd, NULL, FALSE
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
    invoke CreateSolidBrush, 0eff8fah
    mov @stWndClass.hbrBackground, eax
    mov @stWndClass.lpszClassName, offset szClassName
    push hIcon
    pop @stWndClass.hIcon

    invoke RegisterClassEx, addr @stWndClass
                                                                               
    invoke CreateWindowEx, WS_EX_CLIENTEDGE, offset szClassName, offset szCaptionMain, WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX, 100, 100, WINDOW_WIDTH, WINDOW_HEIGHT, NULL, hMenu, hInstance, NULL
    mov hWinMain, eax

    invoke CreateWindowEx, NULL, offset szButton, offset szButtonText, WS_CHILD or WS_VISIBLE, 10, 10, 65, 22, hWinMain, 1, hInstance, NULL

    invoke ShowWindow, hWinMain, SW_SHOWNORMAL

    invoke UpdateWindow, hWinMain
                                                                               
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
