.DATA
    EXTERN print_error:PROC
    EXTERN print_string:PROC
    EXTERN print_number:PROC
    
    ; Debug messages
    debug_parsing_comment db "DEBUG: Parsing comment", 13, 10, 0
    debug_parsing_identifier db "DEBUG: Parsing identifier: ", 0
    debug_parsing_print db "DEBUG: Parsing print statement", 13, 10, 0
    debug_var_in_print db "DEBUG: Found variable in print: ", 0
    debug_fstring_start db "DEBUG: Found f-string start", 13, 10, 0
    debug_rparen db "DEBUG: Found right parenthesis", 13, 10, 0
    debug_newline db 13, 10, 0

    EXTERN token_buffer:BYTE
    EXTERN current_pos:QWORD
    EXTERN get_next_token:PROC

    ; Import token types from lexer
    EXTERN TOKEN_EOF:ABS
    EXTERN TOKEN_IDENTIFIER:ABS
    EXTERN TOKEN_STRING:ABS
    EXTERN TOKEN_EQUALS:ABS
    EXTERN TOKEN_LPAREN:ABS
    EXTERN TOKEN_RPAREN:ABS
    EXTERN TOKEN_COMMENT:ABS
    EXTERN TOKEN_NEWLINE:ABS
    EXTERN TOKEN_FUNCTION:ABS
    EXTERN TOKEN_FSTRING:ABS
    EXTERN TOKEN_LCURLY_BRACE:ABS
    EXTERN TOKEN_RCURLY_BRACE:ABS

    ; Operation types
    OP_INPUT    equ 1
    OP_PRINT    equ 2

    ; Data structures (simplified)
    operations  db 32 * 72 dup(0)  ; Each operation: type(8) + var_count(8) + var_indices(8*8)
    op_count    dq 0
    
    string_table db 32 * 256 dup(0)
    string_count dq 0
    
    symbol_table db 32 * 256 dup(0)
    symbol_count dq 0

    current_token dq 0

    ; Make these public for the code generator
    PUBLIC operations
    PUBLIC op_count
    PUBLIC string_table
    PUBLIC string_count
    PUBLIC symbol_table
    PUBLIC symbol_count

.CODE

; Simplified add_symbol - assumes valid input
add_symbol PROC
    push rbp
    mov rbp, rsp        ; Create stack frame
    sub rsp, 20h        ; Allocate shadow space + alignment
    
    push rbx
    push rsi
    push rdi
    
    ; Save pointer parameter to local variable
    mov [rbp-8], rdx    ; Store original rdx value safely on stack
    
    ; Get destination in symbol table
    mov rax, [symbol_count]
    mov rbx, 256
    mul rbx             ; RAX = offset into symbol table, RDX modified here
    lea rdi, symbol_table
    add rdi, rax
    
    mov rdx, [rbp-8]    ; Restore original pointer from stack
    mov rsi, rdx        ; source string in rdx/rsi
    
    ; First verify rdx is not null
    test rdx, rdx
    jz add_symbol_error
    
    ; Add safety bounds check
    cmp QWORD PTR [symbol_count], 32
    jae add_symbol_error
    
copy_sym:
    ; Bounds check for source string
    mov al, [rsi]
    mov [rdi], al
    test al, al
    jz copy_done
    inc rsi
    inc rdi
    ; Bounds check - ensure we don't exceed 256 bytes
    mov rcx, rdi
    sub rcx, rax    ; Calculate how many bytes we've copied
    cmp rcx, 256
    jae copy_done   ; If we've copied 256 bytes, force termination
    jmp copy_sym
    
copy_done:
    mov rax, [symbol_count]    ; Return current index
    inc QWORD PTR [symbol_count]
    
    pop rdi
    pop rsi
    pop rbx
    mov rsp, rbp
    pop rbp
    ret
    
add_symbol_error:
    mov rax, -1     ; Return -1 to indicate error
    pop rdi
    pop rsi
    pop rbx
    mov rsp, rbp
    pop rbp
    ret
add_symbol ENDP

; Find symbol - returns index in RAX, -1 if not found
find_symbol PROC
    push rbp
    mov rbp, rsp
    sub rsp, 20h        ; Shadow space + alignment

    push rbx
    push rsi
    push rdi
    
    ; Save input pointer
    mov [rbp-8], rdx    ; Store original pointer safely
    
    xor rbx, rbx        ; Initialize counter

find_loop:
    cmp rbx, [symbol_count]
    jae not_found
    
    mov rax, rbx
    mov rcx, 256
    mul rcx             ; This modifies RDX
    lea rdi, symbol_table
    add rdi, rax
    
    mov rdx, [rbp-8]    ; Restore original pointer
    mov rsi, rdx        ; Set up source pointer
    
compare:
    mov al, [rsi]
    mov ah, [rdi]
    test al, al
    jz check_end
    cmp al, ah
    jne next_sym
    inc rsi
    inc rdi
    jmp compare
    
check_end:
    test ah, ah
    jnz next_sym
    mov rax, rbx
    jmp find_done
    
next_sym:
    inc rbx
    jmp find_loop
    
not_found:
    mov rax, -1
    
find_done:
    pop rdi
    pop rsi
    pop rbx
    mov rsp, rbp
    pop rbp
    ret
find_symbol ENDP

; Handle input statement
parse_input PROC
    push rbx
    push rsi
    push rdi
    
    ; Save variable index
    mov rbx, rax    
    
    ; Skip '('
    call get_next_token
    
    ; Get prompt string
    call get_next_token
    
    ; Store string
    mov rax, [string_count]
    mov rcx, 256
    mul rcx
    lea rdi, string_table
    add rdi, rax
    
    lea rsi, token_buffer

copy_str:
    mov al, [rsi]
    mov [rdi], al
    test al, al
    jz str_done
    inc rsi
    inc rdi
    jmp copy_str
    
str_done:
    ; Create operation record
    mov rax, [op_count]
    mov rcx, 16
    mul rcx
    lea rdi, operations
    add rdi, rax
    
    mov QWORD PTR [rdi], OP_INPUT
    mov QWORD PTR [rdi+8], rbx
    
    inc QWORD PTR [string_count]
    inc QWORD PTR [op_count]
    
    ; Skip ')'
    call get_next_token
    
    pop rdi
    pop rsi
    pop rbx
    ret
parse_input ENDP

; Handle print statement with f-string
parse_print PROC
    push rbp
    mov rbp, rsp
    sub rsp, 40h        ; Allocate shadow space + local variables
    
    push rbx
    push rsi
    push rdi
    
    ; Debug print for print statement start (only once)
    lea rcx, debug_parsing_print
    call print_string
    
    ; Skip '('
    call get_next_token
    
    ; Create operation record
    mov rax, [op_count]
    mov rcx, 72        ; Size: 8 (type) + 8 (var_count) + 8*8 (var_indices)
    mul rcx
    lea rdi, operations
    add rdi, rax
    
    mov QWORD PTR [rdi], OP_PRINT    ; Set operation type
    mov QWORD PTR [rdi+8], 0         ; Initialize var_count to 0
    
    ; Look for f-string
    call get_next_token
    cmp rax, TOKEN_FSTRING
    jne not_fstring
    
    ; Debug print for f-string
    lea rcx, debug_fstring_start
    call print_string
    
    ; Process until ')'
parse_print_loop:
    call get_next_token
    
    cmp rax, TOKEN_RPAREN
    je print_done
    
    cmp rax, TOKEN_LCURLY_BRACE
    jne parse_print_loop
    
    ; Handle variable interpolation
    mov rbx, [rdi+8]    ; Get current var_count
    cmp rbx, 8          ; Check if we have room for another variable
    jae skip_var        ; Skip if too many variables
    
    call get_next_token
    cmp rax, TOKEN_IDENTIFIER
    jne skip_var
    
    ; Debug print for found variable
    push rax
    lea rcx, debug_var_in_print
    call print_string
    lea rcx, token_buffer
    call print_string
    lea rcx, debug_newline
    call print_string
    pop rax
    
    ; Look up variable in symbol table
    lea rdx, token_buffer
    call find_symbol
    
    ; Calculate offset for this variable index
    mov rcx, rbx        ; Current var_count
    shl rcx, 3          ; Multiply by 8
    add rcx, 16         ; Skip past type and var_count
    
    ; Store variable index
    mov [rdi + rcx], rax    ; Store symbol index
    
    inc QWORD PTR [rdi+8]    ; Increment var_count
    
skip_var:
    ; Skip '}'
    call get_next_token
    jmp parse_print_loop
    
print_done:
    ; Debug print for right parenthesis
    lea rcx, debug_rparen
    call print_string
    
    inc QWORD PTR [op_count]
    
    mov rsp, rbp
    pop rbp
    ret

not_fstring:
    mov rsp, rbp
    pop rbp
    ret
parse_print ENDP

; Main parsing procedure
parse_program PROC
    push rbp
    mov rbp, rsp
    
    mov QWORD PTR [current_pos], 0
    
parse_loop:
    call get_next_token
    mov [current_token], rax
    
    ; Check only tokens that can start statements
    cmp rax, TOKEN_EOF
    je parse_done
    
    cmp rax, TOKEN_COMMENT    ; Skip comments
    jne not_comment
    lea rcx, debug_parsing_comment
    call print_string
    jmp parse_loop
not_comment:
    
    cmp rax, TOKEN_NEWLINE    ; Skip newlines
    je parse_loop
    
    cmp rax, TOKEN_FUNCTION   ; print statement
    je handle_print
    
    cmp rax, TOKEN_IDENTIFIER ; variable assignment
    je handle_assignment
    
    jmp parse_loop           ; Skip any other tokens

handle_print:
    lea rcx, debug_parsing_print
    call print_string
    call parse_print
    jmp parse_loop

handle_assignment:
    lea rdx, token_buffer    ; Get variable name
    push rdx
    
    lea rcx, debug_parsing_identifier
    call print_string
    mov rcx, rdx
    call print_string
    lea rcx, debug_newline
    call print_string
    
    call get_next_token      ; Should be '='
    pop rdx
    
    call find_symbol         ; Find or add symbol
    cmp rax, -1
    jne assignment_existing
    call add_symbol
    dec rax
    
assignment_existing:
    call get_next_token      ; Should be 'input'
    call parse_input
    jmp parse_loop
    
parse_done:
    mov rsp, rbp
    pop rbp
    ret
parse_program ENDP

END