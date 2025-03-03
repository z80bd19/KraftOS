; -----------------------------------------------------------------------------
; KRAFTWERK BOOTLOADER
; -----------------------------------------------------------------------------

;==============================================================================
; Filename:     boot-sect0.asm
; Author:       z80bd19
; Date:         2025-02-27
; Version:      1.0
;==============================================================================
; Description:
;   My own private bootloader
;
; Dependencies:
;   A BIOS loader or emulator (QEMU)
;
; Notes:
;   Compile via:
;     nasm boot-sect0.asm -f bin -o boot.bin
;   
;   Run with:
;     qemu-system-i386 -drive format=raw,file=boot.bin
;   or start in debug mode with:
;     qemu-system-i386 -s -S -drive format=raw,file=boot.bin
;   and connect radare using:
;     r2 -a x86 -b 16 -d gdb://localhost:1234
;
;   Useful Radare commands:
;     dcu 0x7c00            - Run until first instruction of boot image at 7x00
;     dso 1;                - Step 1 opcode
;     pd 12;                - Print disassembly of next 12 opcodes
;     dr?                   - Display register values
;     ...or do all 3 together:
;     dso 1; pd 12; dr?eax;dr?ebx;dr?ecx;dr?edx;dr?esi
;   
;==============================================================================

[org 0x7c00]

[bits 16]

; Constants for the Boot Loader
KRNL_OFFSET         equ 0x1000 ;
READ_SECTOR_FUNC    equ 0x02   ; Bios Read Sector Function
SECTOR_COUNT        equ 30     ; No. of sectors to read (increase if needed)
DISK_CYLINDER       equ 0x00   ; Select Cylinder 0 from harddisk
DISK_HEAD           equ 0x00   ; Select head 0 from hard disk
DISK_START_SECTOR   equ 0x02   ; Start Reading from Second sector(Sector just after boot sector)

; Constants for BIOS interrupts and functions
VIDEO_INT           equ 0x10
DISK_INT            equ 0x12
SET_VIDEO_MODE      equ 0x00    ; Function to set video mode
SET_CURSOR_FUNC     equ 0x02    ; Function to set cursor position
WRITE_CHAR_FUNC     equ 0x09    ; Function to write character
SET_BG_COLOR        equ 0x0b    ; Funtion to set background color
TELETYPE_OUTPUT     equ 0x0E    ; Function for teletype output
PAGE_NUMBER         equ 0x00    ; Default page number
COLOR_RED           equ 0x44    ; Default background color
 
; Video mode settings
SQUARE_CHAR_MODE    equ 0x01    ; 80x25 text mode with 8x8 square characters

; Display settings
TITLE_ROW           equ 0x01    ; Row for title text
TITLE_COL           equ 0x0A    ; Column for title text
START_ROW           equ 0x0A
START_COL           equ 0x00
GRAPHIC_HEIGHT      equ 0x0C
GRAPHIC_WIDTH       equ 0x08
CHAR_COLOR          equ 0x8E
TITLE_COLOR         equ 0x1F    ; Title color attribute (white on blue)
CHAR_TO_DISPLAY     equ ' '
CHARS_TO_WRITE      equ 0x01

; Memory addressing
MBR_LOAD_ADDR       equ 0x7C00

; Band member offsets
BAND_OFFSET_INC     equ 10

; ---------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------
    org 0x7C00                  ; Set origin to MBR load address

    jmp main                    ; Jump to main program entry

; ---------------------------------------------------------------------------
; Function: set_cursor_position
; Parameters:
;   - DH: Row
;   - DL: Column
;   - BH: Offset (band member position)
; Returns: None
; ---------------------------------------------------------------------------
set_cursor_position:
    push ax
    push bx
    push dx
    
    mov ah, SET_CURSOR_FUNC     ; Set cursor position function
    add dl, bh                  ; Add band member offset
    mov bh, PAGE_NUMBER         ; Page number
    int VIDEO_INT               ; Call BIOS video service
    
    pop dx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; Function: draw_character
; Parameters:
;   - DH: Row
;   - DL: Column
;   - BH: Offset (band member position)
; Returns: None
; ---------------------------------------------------------------------------
draw_character:
    push ax
    push bx
    push cx
    
    mov ah, WRITE_CHAR_FUNC     
    mov al, CHAR_TO_DISPLAY     
    mov bl, CHAR_COLOR          
    mov bh, PAGE_NUMBER         
    mov cx, CHARS_TO_WRITE      ; Number of characters to write
    int VIDEO_INT               
    
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; Function: check_bit
; Parameters:
;   - AL: Byte containing bits to check
;   - DL: Bit position to check
; Returns:
;   - Zero flag: Set if bit is 0, cleared if bit is 1
; ---------------------------------------------------------------------------
check_bit:
    push ax
    push cx
    
    mov cl, dl                  ; Column number for bit shift
    mov ah, 0x01                ; Start with bit pattern 00000001
    shl ah, 7                   ; Shift to 10000000
    shr ah, cl                  ; Shift right by column number
    test al, ah                 ; Test if bit is set
    
    pop cx
    pop ax
    ret

; ---------------------------------------------------------------------------
; Function: draw_graphic_row
; Parameters:
;   - AL: Byte containing graphic row data
;   - DH: Starting row
;   - BH: Band member offset
; Returns: None
; ---------------------------------------------------------------------------
draw_graphic_row:
    push ax
    push dx
    
    mov dl, START_COL           ; Start at column 0
    
.bit_loop:
    push ax
    call check_bit              ; Check if DL'th bit is set
    jz .skip                    ; Skip drawing if bit is not set
    
    call draw_character         ; Draw character at current position
    
.skip:
    pop ax
    
    ; Move to next column
    inc dl
    call set_cursor_position
    
    ; Check if we've reached the end of the row
    cmp dl, GRAPHIC_WIDTH
    jnz .bit_loop               ; Continue if not at end of row
    
    pop dx
    pop ax
    ret

; ---------------------------------------------------------------------------
; Function: draw_band_member
; Parameters:
;   - SI: Pointer to graphic data
;   - BH: Band member offset
; Returns:
;   - SI: Updated to point after the processed graphic
; ---------------------------------------------------------------------------
draw_band_member:
    push ax
    push cx
    push dx
    
    mov cx, GRAPHIC_HEIGHT      ; Graphic is 12 rows in height
    mov dh, START_ROW           ; Start at defined row
    
.row_loop:
    lodsb                       ; Load byte into AL and increment SI
    
    call draw_graphic_row       
    
    ; Move to next row
    inc dh
    mov dl, START_COL
    call set_cursor_position
    
    loop .row_loop              ; Decrement CX and loop if not zero
    
    pop dx
    pop cx
    pop ax
    ret

; ---------------------------------------------------------------------------
; Function: set_video_mode
; Description: Sets the video mode to use square characters
; Parameters: None
; Returns: None
; ---------------------------------------------------------------------------
set_video_mode:
    push ax
    
    mov ah, SET_VIDEO_MODE      
    mov al, SQUARE_CHAR_MODE    ; 80x25 text, 16 colors, 8x8 square characters
    int VIDEO_INT               
    
    pop ax
    ret

; ---------------------------------------------------------------------------
; Function: set_background_color
; Description: Sets the background color to red
; Parameters: None
; Returns: None
; ---------------------------------------------------------------------------                
set_background_color:
    push ax
    push bx

    mov ah, SET_BG_COLOR        
    mov bh, 0x00                
    mov bl, COLOR_RED           
    int 0x10

    pop bx
    pop ax

; ---------------------------------------------------------------------------
; Function: print_title
; Description: Prints "Kraftwerk BIOS 1.0" at the specified position
; Parameters: None
; Returns: None
; ---------------------------------------------------------------------------
print_title:
    push ax
    push bx
    push dx
    push si
    
    ; Set cursor position for title
    mov dh, TITLE_ROW           
    mov dl, TITLE_COL           
    mov bh, PAGE_NUMBER         
    mov ah, SET_CURSOR_FUNC     
    int VIDEO_INT
    
    ; Print the title
    mov si, title_text          
    mov bl, TITLE_COLOR         
    
.print_char:
    lodsb                       ; Load byte from SI into AL and increment SI
    test al, al                 ; Check if we've reached the end of the string
    jz .end                     
    
    mov ah, TELETYPE_OUTPUT     
    mov bh, PAGE_NUMBER         
    int VIDEO_INT               
    
    jmp .print_char             ; Continue with next character
    
.end:
    pop si
    pop dx
    pop bx
    pop ax
    ret


; ---------------------------------------------------------------------------
; Main program
; ---------------------------------------------------------------------------
main:

    call set_video_mode
      
    call set_background_color

    call print_title

    ; Initialize cursor position
    mov dh, START_ROW
    mov dl, START_COL
    mov bh, 0                   ; First band member (offset 0)
    call set_cursor_position
    
    ; Draw all band members
    mov si, graphics_start      ; Start of graphics data
    mov bh, 0                   ; First band member offset
    
.band_member_loop:
    call draw_band_member       ; Draw current band member
    
    ; Move to next band member
    add bh, BAND_OFFSET_INC     ; Increase offset for next band member
    
    ; Check if we've processed all graphics
    cmp si, graphics_end
    jb .band_member_loop        ; Continue if more graphics remain

    ; Final cursor position
    mov dh, START_ROW + 12
    mov dl, 0
    mov bh, 0                   ; First band member (offset 0)
    call set_cursor_position

    ;Boot Loader

    mov bx , KRNL_OFFSET        ; Memory offset to which kernel will be loaded
    mov ah , READ_SECTOR_FUNC   
    mov al , SECTOR_COUNT       ; Number of sectors to read
    mov ch , DISK_CYLINDER      ; Select Cylinder 0 from harddisk
    mov dh , DISK_HEAD          ; Select head 0 from hard disk
    mov cl , DISK_START_SECTOR  ; Start Reading from Second sector(Sector just after boot sector)

    int DISK_INT                ; Bios Interrupt Relating to Disk functions


    ;Switch To Protected Mode
    cli ; Turns Interrupts off
    lgdt [GDT_DESC] ; Loads Our GDT

    mov eax , cr0
    or  eax , 0x1
    mov cr0 , eax ; Switch To Protected Mode

    jmp  CODE_SEG:INIT_PM ; Jumps To Our 32 bit Code

    [bits 32]

    INIT_PM:
    mov ax , DATA_SEG
    mov ds , ax
    mov ss , ax
    mov es , ax
    mov fs , ax
    mov gs , ax

    mov ebp , 0x90000
    mov esp , ebp ; Updates Stack Segment


    call 0x1000
        
    ; End of program
    jmp $                       ; Infinite loop

; ---------------------------------------------------------------------------
; Data section
; ---------------------------------------------------------------------------

title_text:  db "Kraftwerk BIOS 1.0", 0   

graphics_start:
graphic1: db 0x10, 0x50, 0x78, 0x3C, 0x1A, 0xFF, 0x18, 0x18, 0x18, 0x18, 0x18, 0x10
graphic2: db 0x10, 0x10, 0x38, 0x38, 0x1C, 0xFF, 0x18, 0x18, 0x18, 0x18, 0x10, 0x08
graphic3: db 0x08, 0x08, 0x1C, 0x1C, 0x28, 0xFF, 0x18, 0x18, 0x18, 0x18, 0x08, 0x18
graphic4: db 0x08, 0x08, 0x1C, 0x1C, 0x18, 0xFF, 0x18, 0x18, 0x18, 0x18, 0x10, 0x08
graphics_end:

GDT_BEGIN:

GDT_NULL_DESC:  ;The  Mandatory  Null  Descriptor
	dd 0x0
	dd 0x0

GDT_CODE_SEG:
	dw 0xffff		;Limit
	dw 0x0			;Base
	db 0x0			;Base
	db 10011010b	;Flags
	db 11001111b	;Flags
	db 0x0			;Base

GDT_DATA_SEG:
	dw 0xffff		;Limit
	dw 0x0			;Base
	db 0x0			;Base
	db 10010010b	;Flags
	db 11001111b	;Flags
	db 0x0			;Base

GDT_END:

GDT_DESC:
	dw GDT_END - GDT_BEGIN - 1
	dd GDT_BEGIN

CODE_SEG equ GDT_CODE_SEG - GDT_BEGIN
DATA_SEG equ GDT_DATA_SEG - GDT_BEGIN

; MBR boot signature
times 510-($-$$) db 0
dw 0xaa55