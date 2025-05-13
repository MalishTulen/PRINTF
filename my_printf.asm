; Supported specifiers: %%, %c, %s, %d, %x, %o, %b.

section .data

NUM_BUFFER        db  64 dup(0)                 ;buffer for converting numbers to chars
NUM_BUFFER_SIZE   equ $ - NUM_BUFFER

PRINT_BUFFER      db  64 dup (0)                ;buffer for chars to print
PRINT_BUFFER_SIZE equ $ - PRINT_BUFFER

CONVERT_ARRAY     db  "0123456789abcdef"        ;array for converting numbers

JUMP_TABLE:                                     ;jump table for handling specifiers
            dq indefined_handle ; a
            dq handle_binary    ; b
            dq handle_char      ; c
            dq handle_decimal   ; d
            dq indefined_handle ; e
            dq indefined_handle ; f
            dq indefined_handle ; g
            dq indefined_handle ; h
            dq indefined_handle ; i
            dq indefined_handle ; j
            dq indefined_handle ; k
            dq indefined_handle ; l
            dq indefined_handle ; m
            dq indefined_handle ; n
            dq handle_octal     ; o
            dq indefined_handle ; p
            dq indefined_handle ; q
            dq indefined_handle ; r
            dq handle_string    ; s
            dq indefined_handle ; t
            dq indefined_handle ; u
            dq indefined_handle ; v
            dq indefined_handle ; w
            dq handle_hex       ; x
            dq indefined_handle ; y
            dq indefined_handle ; z

section .text
global my_printf


; ----------------------------------------------------------------------------------------
;for easier assess to specifiers it is better to make a wrapper for my_printf
;
; Entry(for 6 and more args): rdi   = format
;        rsi   = 1st argument
;        rdx   = 2nd argument
;        rcx   = 3d  argument
;        r8    = 4th argument
;        r9    = 5th argument
;        stack = rsp —> |6th arg|—|7th arg|— ...
;
; Exit:  eax = amount of format elements
;
; Destr: r10, r11, rdi, rcx
; ----------------------------------------------------------------------------------------
my_printf:
    pop r10

    push r9                     ;push all arguments in stack
    push r8                     ;now arguments are in stack in the opposite order
    push rcx
    push rdx
    push rsi

    call my_stack_printf

    add rsp, 40                 ;correcting rsp by adding 40 (we pushed 5 registers size 8 bytes)

    jmp r10                     ;ret (analogy to push r10 ret)

; ----------------------------------------------------------------------------------------
; Analog of libC's function printf
;
; Entry: rdi = format
;        on stack: additional parameters
;
; Exit:  eax = amount of format elements
;
; Destr: rdi, rcx, r11
; ----------------------------------------------------------------------------------------
my_stack_printf:
    push rbp
    mov rbp, rsp

    add rbp, 16                 ;make rbp point to 1 argument

    push r10                    ;we will use r10 as a char counter, but rn it has a return adress
    xor r10, r10

    xor eax, eax                ;init amount of specifiers

.reader_loop:
    cmp byte [rdi], 0           ;no symbol -> exit loop
    je .terminate

    cmp byte [rdi], '%'         ;check for specifier
    jne .default_char

    inc rdi                     ;increment if specifier to check next symbol

    cmp byte [rdi], '%'         ;if symbol is '%' => print '%'
    je .default_char

    call parse_specifier

    cmp eax, -1                 ;'-1' at eax means error
    je .terminate

    jmp .next_iteration

.default_char:
    mov cl, [rdi]
    call putchar

.next_iteration:
    inc rdi                     ;next symbol after just read one
    jmp .reader_loop

.terminate:
    call buffer_flush

    pop r10                     ;restore r10 and rbp
    pop rbp
    ret

; ------------- ---------------------------------------------------------------------------
; Parse specifier after '%' symbol in the string to print via function 'my_printf'
;
; Entry: [rdi] = specifier
;        rbp   = argument
;
; Exit:  eax  = -1, if invalid specifier.
;        eax++; rbp += 8, if everything ok.
;
; Destr: rcx
; ----------------------------------------------------------------------------------------
parse_specifier:
    cmp byte [rdi], 'a'
    jb indefined_handle         ;specifier is being checked for letter, if it is not a letter->
    cmp byte [rdi], 'z'         ;->error
    ja indefined_handle

    xor rcx, rcx
    mov cl, [rdi]               ;cl = letter from jmp table

    mov rcx, [JUMP_TABLE - 'a' * 8 + rcx * 8]   ;jmp to correct parser with formula
    jmp rcx

routine_after_handling_specifier:
    inc eax                     ;inc specifiers amnt

    add rbp, 8                  ;rbp points to next argument in stack
    ret

indefined_handle:
    mov eax, -1                 ;-1 is an error return code.
    ret

; ----------------------------------------------------------------------------------------
; Put a char into the PRINTING_BUFFER. If needed, flush it.
;
; Entry:cl  = char_to_print
;        r10 = current amount of chars in buffer
;
; Exit:None
;
; Destr:rcx, r11
; ----------------------------------------------------------------------------------------
putchar:
    cmp r10, PRINT_BUFFER_SIZE  ;check for free space in buffer
    jb .no_flush

    call buffer_flush           ;sets r10 to 0 and flushs buffer

.no_flush:
    mov byte [PRINT_BUFFER + r10], cl   ;puts char into buffer

    inc r10                     ;next buffer cell

    ret

; ----------------------------------------------------------------------------------------
; Flushes first r10 bytes of PRINT_BUFFER
;
; Entry: r10 = amount of bytes to flush
;
; Exit:  None
;
; Destr: r11
; ----------------------------------------------------------------------------------------
buffer_flush:

    test r10, r10       ;If buffer is empty, don't flush it.
    jz .exit

    push rcx
    push rax
    push rsi
    push rdi
    push rdx

    mov rax, 0x01               ; rax = syscall code of "write"
    mov rsi, PRINT_BUFFER       ; rsi = address of buffer
    mov rdi, 1                  ; rdi = stdout file descriptor
    mov rdx, r10                ; rdx = amount of chars to print

    syscall

    xor r10, r10

    pop rdx
    pop rdi
    pop rsi
    pop rax
    pop rcx

.exit:
    ret

; ----------------------------------------------------------------------------------------
; Handle %c specifier.
;
; Entry: rbp = &char_to_print
;
; Exit:  None
;
; Destr: rcx, r11
; ----------------------------------------------------------------------------------------
handle_char:
; putchar(*rbp)
    mov cl, [rbp]
    call putchar

    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Handle %s specifier.
;
; Entry: [rbp] = &string_to_print[0]
;
; Exit:  None
;
; Destr: rcx, r11
; ----------------------------------------------------------------------------------------
handle_string:
    push rbp
    mov rbp, [rbp]

    xor rcx, rcx

.next_char:
    mov cl, [rbp]
    cmp cl, 0
    je .close
    call putchar
    inc rbp
    jmp .next_char

.close:
    pop rbp
    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Handle %d specifier
;
; Entry: rbp = &decimal_to_print
;
; Exit: None
;
; Destr:
; ----------------------------------------------------------------------------------------
handle_decimal:
    mov rsi, 10                 ;decimal base
    call number_to_ascii
    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Handle %b specifier
;
; Entry: rbp = &decimal_to_print
;
; Exit: None
;
; Destr:
; ----------------------------------------------------------------------------------------
handle_binary:
    mov rsi, 2                  ;binary base
    call number_to_ascii
    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Handle %o specifier
;
; Entry: rbp = &decimal_to_print
;
; Exit: None
;
; Destr:
; ----------------------------------------------------------------------------------------
handle_octal:
    mov rsi, 8                  ;octal base
    call number_to_ascii
    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Handle %x specifier
;
; Entry: rbp = &decimal_to_print
;
; Exit: None
;
; Destr:
; ----------------------------------------------------------------------------------------
handle_hex:
    mov rsi, 16                 ;hex base
    call number_to_ascii
    jmp routine_after_handling_specifier

; ----------------------------------------------------------------------------------------
; Print number in specific base.
;
; Entry: rbp = &number_to_print
;        rsi = base
;
; Exit:  None
;
; Destr: rax, rdi, rcx, rsi, rdx
; ----------------------------------------------------------------------------------------
number_to_ascii:
    push rax            ; Save used registers.
    push rbx
    push rcx
    push rdx
    push rdi

    mov eax, [rbp]      ;rax - decimal to print

    test eax, eax       ;checks for negative rax
    jns .decimal_is_not_negative

.decimal_is_negative:
    mov cl, '-'         ;print minus sign
    call putchar

    neg eax             ;rax = -rax

.decimal_is_not_negative:
    mov rbx, NUM_BUFFER + NUM_BUFFER_SIZE - 1   ; rbx - end of the buffer

    xor rcx, rcx        ;buffer counter

.convert_loop:
    inc rcx
    xor rdx, rdx        ;div r12 <=> (rdx:rax)/r12

    div rsi
    mov dl, [CONVERT_ARRAY + rdx]       ;ascii code to buffer
    mov [rbx], dl

    dec rbx             ;next (previous) buffer cell

    test eax, eax       ;while rax != 0 process converting
    jnz .convert_loop

    push r12            ;r12 = PRINT_BUFFER_SIZE - r10

    mov r12, r10
    sub r12, PRINT_BUFFER_SIZE
    neg r12

    cmp rcx, r12

    jb .merge_buffers   ;if in PRINT_BUFFER is enough space for NUM_BUFFER we put in number, else
                        ;clear PRINT_BUFFER then add NUM_BUFFER

    call buffer_flush

.merge_buffers:

    mov rsi, rcx        ;rsi = NUM_BUFFER + NUM_BUFFER_SIZE - rcx
    sub rsi, NUM_BUFFER + NUM_BUFFER_SIZE
    neg rsi

    lea rdi, [PRINT_BUFFER + r10]

    add r10, rcx

    rep movsb

    pop r12
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
