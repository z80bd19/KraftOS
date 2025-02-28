; Kraftwerk themed bootloader!

mov ah, 0x0b            ; SET BACKGROUND/BORDER COLOR
mov bh, 0x00            ; SET BACKGROUND/BORDER COLOR
mov bl, 0x44            ; background/border color 
int 0x10

;--------------------
mov ah, 0x0e            ; TELETYPE OUTPUT 

mov al, 0x0D            ; CR
int 0x10

mov al, 0x0A            ; LF
int 0x10

mov al, 'K'
int 0x10

mov al, 'R'
int 0x10

mov al, 'A'
int 0x10

mov al, 'F'
int 0x10

mov al, 'T'
int 0x10

mov al, 'W'
int 0x10

mov al, 'E'
int 0x10

mov al, 'R'
int 0x10

mov al, 'K'
int 0x10

;-------Draw musician to screen---------------
mov ah, 0x02            ; Set Cursor Position
mov dh, 0x0A            ; Row
mov dl, 0x00            ; Col
int 0x10                ; Cursor position should be set before entering loop

mov cx, 0x0C            ; Graphic is 12 rows in height
mov si, graphic1        ; Load location of data into si
add si, 0x7c00          ; MBR is loaded at location 0x7c00 so need to offset si

mov bh, 0x00            ; The zeroth band member (0,10,20,30)
outerdraw: lodsb        ; Loads a byte into AL from location SI and increments SI

;-------Loop 'invariants'...
;DH has the row number 
;DL has the col number
;CX INDEXES the outer loop (we DEC CX and INC DH each iteration)
;SI current data location

innerdraw:

push ax
push bx
push cx

; Note: SHL/SHR can only use CL/DL for shifts

mov  cl, dl              ; Will shift bits left by the column number  

mov  ah, 0x01
shl  ah, 7              ; Yeah, I could have done mov ah, 0x80 but this way is clearer
shr  ah, cl             ; Want something like 01000000 is col=DL=2
test al ,ah             ; Is the cl'th bit set?

jz skip                 ;if there is a 0 at bit position dl (=cl) then skip writing a char

mov ah, 0x09            ; We want to Write text
mov al, ' '             ; well... a space
mov bl, 0x8e            ; Set color     
mov bh, 0x00            ; This seems neccessary too
mov cx, 0x01
int 0x10                ; Now write the ascii character

skip:

pop cx
pop bx
pop ax

;------- Need to offset column pos by bh*10

; Move cursor to next position
mov ah, 0x02            ; Set cursor position
inc dl                  ; Increase col number

push bx
push dx
add dl, bh              ; Add horizontal offset (0,10,20,30) 
mov bh, 0x00            ; Page zero
int 0x10
pop dx
pop bx

; if dl < 8 then loop, otherwise get a new byte
cmp dl,8 
jnz innerdraw  

mov dl,0                ; Col = 0 (for drawing next line)
inc dh                  ; Inc Row number

;-------------------------------------------
;Need to place cursor at start of next row
push bx
push dx
mov ah, 0x02            ; Set cursor position
add dl, bh              ; Add offset (0,10,20,30) 
mov bh, 0x00            ; Page zero
int 0x10
pop dx
pop bx
;-------------------------------------------

cmp dh,0x0A + 0x0C      ; Each person is 12 blocks high, head at poistion 0A
jnz outerdraw

; End of drawing a person, move onto next
mov dh,0x0A
add bh,10

cmp si, 0x7cce          ; Ugly, hardcoded position (how to autogenerate in nasm\?) 
jnz outerdraw 

jmp $   ;-----End of code


;--------------------Data Below-------------
graphic1 db 0x10, 0x50, 0x78, 0x3C, 0x1A, 0xFF, 0x18, 0x18, 0x18, 0x18, 0x18, 0x10
graphic2 db 0x10, 0x10, 0x38, 0x38, 0x1C, 0xFF, 0x18, 0x18, 0x18, 0x18, 0x10, 0x08
graphic3 db 0x08, 0x08, 0x1C, 0x1C, 0x28, 0xFF, 0x18, 0x18, 0x18, 0x18, 0x08, 0x18
graphic4 db 0x08, 0x08, 0x1C, 0x1C, 0x18, 0xFF, 0x18, 0x18, 0x18, 0x18, 0x10, 0x08

;--------------------Test Data Below (stripes)-------------
;graphic1 db 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55
;graphic2 db 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55
;graphic3 db 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55
;graphic4 db 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55

times 510-($-$$) db 0
dw 0xaa55
