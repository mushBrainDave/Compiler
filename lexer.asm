;INCLUDE structures\structures.inc   ; Include structure definitions
;INCLUDE tokens\tokens.inc      ; Include token definitions

; Structure definition - goes before any section
KeywordEntry STRUCT
    lengthField  BYTE ?              ; Length of keyword
    keywordField BYTE 15 dup(?)      ; Keyword string (15 bytes max)
    tokenField   BYTE ?              ; Token type
KeywordEntry ENDS

.DATA
    ; Token types (constants)
    PUBLIC TOKEN_EOF
    PUBLIC TOKEN_IDENTIFIER
    PUBLIC TOKEN_STRING
    PUBLIC TOKEN_EQUALS
    PUBLIC TOKEN_LPAREN
    PUBLIC TOKEN_RPAREN
    PUBLIC TOKEN_COMMENT
    PUBLIC TOKEN_NEWLINE
    PUBLIC TOKEN_FUNCTION
    PUBLIC TOKEN_FSTRING
    PUBLIC TOKEN_LCURLY_BRACE
    PUBLIC TOKEN_RCURLY_BRACE

    ; Token type strings for debugging
    token_type_0 db "EOF", 0
    token_type_1 db "IDENTIFIER", 0
    token_type_2 db "STRING", 0
    token_type_3 db "EQUALS", 0
    token_type_4 db "LPAREN", 0
    token_type_5 db "RPAREN", 0
    token_type_6 db "COMMENT", 0
    token_type_7 db "NEWLINE", 0
    token_type_8 db "FUNCTION", 0
    token_type_9 db "FSTRING", 0
    token_type_10 db "LCURLY_BRACE", 0
    token_type_11 db "RCURLY_BRACE", 0

    ; Array of pointers to token type strings
    token_type_ptrs dq token_type_0
                    dq token_type_1
                    dq token_type_2
                    dq token_type_3
                    dq token_type_4
                    dq token_type_5
                    dq token_type_6
                    dq token_type_7
                    dq token_type_8
                    dq token_type_9
                    dq token_type_10
                    dq token_type_11

    ; Token types (constants)
    TOKEN_EOF       equ 0
    TOKEN_IDENTIFIER equ 1
    TOKEN_STRING    equ 2
    TOKEN_EQUALS    equ 3
    TOKEN_LPAREN    equ 4
    TOKEN_RPAREN    equ 5
    TOKEN_COMMENT   equ 6
    TOKEN_NEWLINE   equ 7
    TOKEN_FUNCTION  equ 8
    TOKEN_FSTRING   equ 9
    TOKEN_LCURLY_BRACE equ 10
    TOKEN_RCURLY_BRACE equ 11

    ; First fix the keyword table definition
    KEYWORD_COUNT    equ 2                  ; We have 2 keywords
    MAX_KEYWORD_LEN  equ 16
    
    ; Revised keyword table structure - make it simpler and more explicit
    keyword_table KeywordEntry <5, "print", TOKEN_FUNCTION>    ; Initialize first entry
                  KeywordEntry <5, "input", TOKEN_FUNCTION>     ; Initialize second entry

    ; Debug messages
    msg_token_type db "Token Type: ", 0
    msg_token_value db ", Value: ", 0
    msg_newline db 13, 10, 0
    msg_debug_length db "Debug: Source length = ", 0
    msg_debug_buffer db "Debug: Buffer contents = ", 0
    debug_looking_up db "Looking up keyword: ", 0
    debug_comparing db "Comparing with: ", 0
    debug_length db "Length: ", 0
    debug_found db "Found keyword, type: ", 0
    debug_not_found db "Not found in keyword table", 13, 10, 0

    ; Lexer state
    PUBLIC current_pos 
    PUBLIC token_buffer
    current_pos dq 0
    token_buffer db 256 dup(0)    ; Buffer for current token value

    ; External references
    EXTERN buffer:BYTE
    EXTERN sourceLength:QWORD

.CODE
    PUBLIC run_lexer
    PUBLIC print_string
    PUBLIC print_number
    PUBLIC get_next_token
    EXTERN WriteConsoleA:PROC
    EXTERN GetStdHandle:PROC

; Helper function to check if character is whitespace
is_whitespace PROC
    ; Input: AL = character to check
    ; Output: ZF set if whitespace, clear if not
    cmp al, ' '
    je is_space
    cmp al, 9  ; Tab
    je is_space
    cmp al, 13 ; CR
    je is_space
    cmp al, 10 ; LF
is_space:
    ret
is_whitespace ENDP

; Helper function to check if character is letter
is_letter PROC
    ; Input: AL = character to check
    ; Output: Carry flag set if letter
    cmp al, '_'
    je is_letter_true
    cmp al, 'a'
    jb not_lowercase
    cmp al, 'z'
    jbe is_letter_true
not_lowercase:
    cmp al, 'A'
    jb not_letter
    cmp al, 'Z'
    jbe is_letter_true
not_letter:
    clc     ; Clear carry flag - not a letter
    ret
is_letter_true:
    stc     ; Set carry flag - is a letter
    ret
is_letter ENDP

; Helper function to check if character is digit
; Input: AL = character to check
; Output: ZF set if digit
is_digit PROC
    sub al, '0'
    cmp al, 10   ; Check if in range '0'-'9'
    ret
is_digit ENDP

; Helper to look up keyword in table
; Input: RCX = pointer to identifier
; Output: RAX = token type if found, -1 if not found
    lookup_keyword PROC
        push rbp
        mov rbp, rsp
        sub rsp, 20h
        
        push rbx
        push rsi
        push rdi
        
        mov rsi, rcx                ; Source string pointer
        lea rdi, keyword_table      ; Keyword table pointer
        xor rbx, rbx                ; Counter for keywords
        
        ; Get input string length
        xor rdx, rdx                ; Length counter
    str_len:
        cmp BYTE PTR [rcx + rdx], 0
        je str_len_done
        inc rdx
        jmp str_len
    str_len_done:
        
    keyword_loop:
        cmp rbx, KEYWORD_COUNT
        jae not_found
        
        ; Compare lengths first - using structure field
        movzx rcx, (KeywordEntry PTR [rdi]).lengthField   ; Get keyword length
        cmp rcx, rdx                ; Compare with input length
        jne next_keyword            ; If lengths don't match, try next
        
        ; Do string comparison
        push rsi                    ; Save string pointer
        push rdi                    ; Save table pointer
        lea rdi, [rdi + 1]         ; Skip length byte, point to keyword field
        mov rcx, rdx               ; Length to compare
        repe cmpsb                ; Compare strings
        je found_keyword          ; Jump if match found
        
        pop rdi                    ; Restore pointers
        pop rsi
        
    next_keyword:
        add rdi, SIZEOF KeywordEntry ; Move to next table entry using structure size
        inc rbx
        jmp keyword_loop
        
    found_keyword:
        pop rdi                     ; Restore table pointer
        pop rsi                     ; Restore string pointer
        movzx rax, (KeywordEntry PTR [rdi]).tokenField    ; Get token type from structure
        jmp lookup_done
        
    not_found:
        mov rax, -1                 ; Return -1 if not found
        
    lookup_done:
        pop rdi
        pop rsi
        pop rbx
        mov rsp, rbp
        pop rbp
        ret
    lookup_keyword ENDP


; Main lexer function
; Output: RAX = token type
get_next_token PROC
    push rbp
    mov rbp, rsp
    sub rsp, 20h
    
    ; Clear token buffer
    lea rdi, token_buffer
    mov rcx, 256
    xor al, al
    rep stosb

    ; Check if we're at end of input
    mov rax, [current_pos]
    cmp rax, [sourceLength]
    jae return_eof

    ; Get current character
    lea rdx, buffer
    add rdx, [current_pos]
    mov al, [rdx]

    ; Skip whitespace
skip_whitespace:
    call is_whitespace
    jne check_comment
    inc QWORD PTR [current_pos]
    mov rax, [current_pos]
    cmp rax, [sourceLength]
    jae return_eof
    lea rdx, buffer
    add rdx, [current_pos]
    mov al, [rdx]
    jmp skip_whitespace

check_comment:
    ; Check for comment
    cmp al, '#'
    jne check_newline
    ; Handle comment - read until newline
    mov rdi, OFFSET token_buffer
    mov [rdi], al    ; Store '#'
    inc rdi
comment_loop:
    inc QWORD PTR [current_pos]
    mov rax, [current_pos]
    cmp rax, [sourceLength]
    jae end_comment
    lea rdx, buffer
    add rdx, [current_pos]
    mov al, [rdx]
    cmp al, 10    ; Check for newline
    je end_comment
    mov [rdi], al
    inc rdi
    jmp comment_loop
end_comment:
    mov rax, TOKEN_COMMENT
    jmp exit_get_token

check_newline:
    ; Check for newline
    cmp al, 13    ; CR
    je handle_newline
    cmp al, 10    ; LF
    jne check_string
handle_newline:
    inc QWORD PTR [current_pos]
    mov rax, TOKEN_NEWLINE
    jmp exit_get_token


check_string:
    ; Check for f-string
    mov rdx, [current_pos]
    lea rsi, buffer
    add rsi, rdx
    
    ; First check if current char is 'f' and next is quote
    cmp BYTE PTR [rsi], 'f'
    jne regular_string
    
    ; Get next character position
    inc rdx
    cmp rdx, [sourceLength]  ; Bounds check
    jae regular_string
    
    ; Check if next char is quote
    mov al, BYTE PTR [rsi + 1]
    cmp al, '"'
    je handle_fstring
    jmp regular_string

handle_fstring:
    mov rdi, OFFSET token_buffer
    mov BYTE PTR [rdi], 'f'    ; Store f
    inc rdi
    mov BYTE PTR [rdi], '"'    ; Store opening quote
    inc rdi
    add QWORD PTR [current_pos], 2  ; Skip 'f' and opening quote

fstring_content_loop:
    mov rax, [current_pos]
    cmp rax, [sourceLength]
    jae exit_get_token
    lea rdx, buffer
    add rdx, [current_pos]
    mov al, [rdx]

    ; Check for special characters
    cmp al, '"'      ; End of f-string
    je found_fstring_end
    cmp al, '{'      ; Start of interpolation
    je found_curly_start
    
    ; Regular character - add to buffer
    mov [rdi], al
    inc rdi
    inc QWORD PTR [current_pos]
    jmp fstring_content_loop

found_curly_start:
    ; If we've collected some string content before the {, return it as FSTRING
    lea rax, token_buffer    ; Get base address
    add rax, 2              ; Add 2 to point after 'f"'
    cmp rdi, rax            ; Compare with current position
    je return_curly         ; If equal, buffer only has f"
    
    ; Otherwise, terminate the current string and return it
    mov BYTE PTR [rdi], '"'    ; Add closing quote
    mov rax, TOKEN_FSTRING
    jmp exit_get_token

return_curly:
    mov BYTE PTR [token_buffer], '{'
    inc QWORD PTR [current_pos]
    mov rax, TOKEN_LCURLY_BRACE
    jmp exit_get_token

found_fstring_end:
    mov [rdi], al    ; Store closing quote
    inc QWORD PTR [current_pos]
    mov rax, TOKEN_RCURLY_BRACE
    jmp exit_get_token

regular_string:
    ; Check for string (both single and double quotes)
    cmp al, '"'
    je handle_string
    cmp al, "'"
    je handle_string
    jmp check_identifier        ; Unrecognized character, skip it

handle_string:
    mov bl, al        ; Save quote character
    mov rdi, OFFSET token_buffer
    mov [rdi], al     ; Store opening quote
    inc rdi
string_loop:
    inc QWORD PTR [current_pos]
    mov rax, [current_pos]
    cmp rax, [sourceLength]
    jae end_string
    lea rdx, buffer
    add rdx, [current_pos]
    mov al, [rdx]
    cmp al, bl        ; Check for matching quote
    je end_string
    mov [rdi], al
    inc rdi
    jmp string_loop
end_string:
    mov [rdi], bl     ; Store closing quote
    inc QWORD PTR [current_pos]
    mov rax, TOKEN_STRING
    jmp exit_get_token

check_identifier:
    ; Check for identifier
    call is_letter
    jnc check_equals
    ; Handle identifier
    mov rdi, OFFSET token_buffer
identifier_loop:
    mov [rdi], al
    inc rdi
    inc QWORD PTR [current_pos]
    mov rax, [current_pos]
    cmp rax, [sourceLength]
    jae end_identifier
    lea rdx, buffer
    add rdx, [current_pos]
    mov al, [rdx]
    call is_letter
    jc identifier_loop
end_identifier:   
    ; Look up the identifier in keyword table
    lea rcx, token_buffer
    call lookup_keyword    ; Result in RAX
    
    cmp rax, -1           ; Check if it's not a keyword
    je return_identifier
    
    ; It's a keyword, return its token type from RAX
    jmp exit_get_token

return_identifier:
    mov rax, TOKEN_IDENTIFIER
    jmp exit_get_token

check_equals:
    ; Check for equals sign
    cmp al, '='
    jne check_parentheses
    mov BYTE PTR [token_buffer], '='
    inc QWORD PTR [current_pos]
    mov rax, TOKEN_EQUALS
    jmp exit_get_token

check_parentheses:
    ; Check for parentheses
    cmp al, '('
    jne check_right_paren
    mov BYTE PTR [token_buffer], '('
    inc QWORD PTR [current_pos]
    mov rax, TOKEN_LPAREN
    jmp exit_get_token
check_right_paren:
    cmp al, ')'
    jne check_curly_brace
    mov BYTE PTR [token_buffer], ')'
    inc QWORD PTR [current_pos]
    mov rax, TOKEN_RPAREN
    jmp exit_get_token

check_curly_brace:
    cmp al, '{'
    je handle_left_curly
    cmp al, '}'
    je handle_right_curly
    jmp advance_pos

handle_left_curly:
    mov BYTE PTR [token_buffer], '{'
    inc QWORD PTR [current_pos]
    mov rax, TOKEN_LCURLY_BRACE
    jmp exit_get_token

handle_right_curly:
    mov BYTE PTR [token_buffer], '}'
    inc QWORD PTR [current_pos]
    mov rax, TOKEN_RCURLY_BRACE
    
    ; After handling }, return to f-string processing mode
    mov rax, [current_pos]
    cmp rax, [sourceLength]
    jae exit_get_token
    
    lea rdx, buffer
    add rdx, [current_pos]
    mov al, [rdx]
    
    ; If next char is ", we need to continue as f-string
    cmp al, '"'
    jne exit_get_token
    
    ; Return to f-string processing
    jmp fstring_content_loop

advance_pos:
    inc QWORD PTR [current_pos]
    mov rax, TOKEN_IDENTIFIER    ; Default to identifier for unknown chars

exit_get_token:
    mov rsp, rbp
    pop rbp
    ret

return_eof:
    mov rax, TOKEN_EOF
    mov rsp, rbp
    pop rbp
    ret
get_next_token ENDP

run_lexer PROC
    push rbp
    mov rbp, rsp
    sub rsp, 40     ; Shadow space

    ; Print source length
    lea rcx, msg_debug_length
    call print_string
    mov rdx, [sourceLength]
    call print_number
    lea rcx, msg_newline
    call print_string
    
    ; Print buffer contents
    lea rcx, msg_debug_buffer
    call print_string
    lea rcx, buffer
    call print_string
    lea rcx, msg_newline
    call print_string

    ; Initialize current position
    mov QWORD PTR [current_pos], 0

token_loop:
    ; Get next token
    call get_next_token
    
    ; Save token type for later comparison
    mov rbx, rax    
    
    ; Print token type label
    lea rcx, msg_token_type
    call print_string
    
    ; Get and print token type string
    cmp rbx, 11              ; Make sure token is in valid range
    ja invalid_token
    
    ; Get pointer to correct token type string
    mov rax, rbx    ; Get token type
    mov rcx, 8      ; Size of pointer
    mul rcx         ; Get offset into pointer array
    lea rdx, token_type_ptrs
    add rdx, rax
    mov rcx, [rdx]  ; Get actual string pointer
    call print_string
    
    ; Print value separator
    lea rcx, msg_token_value
    call print_string
    
    ; Print token value
    lea rcx, token_buffer
    call print_string
    
    ; Print newline
    lea rcx, msg_newline
    call print_string
    
    ; Check if we're done (EOF token is 0)
    cmp rbx, 0      ; Compare saved token type with EOF
    je exit_test
    jmp token_loop  ; Continue if not EOF

invalid_token:
    jmp token_loop  ; Continue processing tokens

exit_test:
    mov rsp, rbp
    pop rbp
    ret
run_lexer ENDP

; [print_string and print_number procedures remain the same]
    print_string PROC
        push rbp
        mov rbp, rsp
        sub rsp, 40
    
        ; Save registers
        push rcx        ; Save string pointer
        push rdx
        push r8
        push r9
    
        ; First verify rcx (string pointer) is not null
        test rcx, rcx
        jz print_string_exit    ; Skip if null pointer
    
        ; Get string length
        mov rdx, rcx    ; Save string pointer
        xor rcx, rcx    ; Length counter
    str_len:
        test rdx, rdx   ; Verify pointer is not null
        jz str_len_done
    
        cmp rcx, 1000   ; Safety limit to prevent infinite loop
        jae str_len_done
    
        cmp BYTE PTR [rdx + rcx], 0
        je str_len_done
        inc rcx
        jmp str_len
    str_len_done:
        test rcx, rcx   ; If length is 0, exit
        jz print_string_exit
    
        mov r8, rcx     ; Length for WriteConsoleA
        mov rcx, rdx    ; Restore string pointer to rcx
    
        ; Get console handle
        push rcx        ; Save string pointer
        push r8         ; Save length
        mov rcx, -11    ; STD_OUTPUT_HANDLE
        call GetStdHandle
        test rax, rax   ; Verify handle
        jz print_string_exit
    
        pop r8          ; Restore length
        pop rdx         ; String pointer now in rdx
    
        ; Write to console
        mov rcx, rax    ; Console handle
        lea r9, [rsp+32]; Bytes written
        mov QWORD PTR [rsp+32], 0 ; Reserved parameter
        call WriteConsoleA

    print_string_exit:    
        ; Restore registers
        pop r9
        pop r8
        pop rdx
        pop rcx
    
        mov rsp, rbp
        pop rbp
        ret
    print_string ENDP

    print_number PROC
        push rbp
        mov rbp, rsp
        sub rsp, 40

        ; Convert number in RDX to string
        push rdx            ; Save number
        mov rax, rdx        ; Number to convert
        mov rcx, 10         ; Base 10
        xor rdx, rdx        ; Clear high bits
        mov rbx, rsp        ; Use stack for temp storage
        sub rbx, 32         ; Allow space for digits
        ; Change this line:
        mov BYTE PTR [rbx], 0   ; Null terminator - MASM syntax needs BYTE PTR

    convert_loop:
        div rcx             ; Divide by 10
        add dl, '0'         ; Convert remainder to ASCII
        dec rbx             ; Move back one char
        ; Change this line:
        mov BYTE PTR [rbx], dl       ; Store digit - MASM syntax needs BYTE PTR
        xor rdx, rdx        ; Clear remainder
        test rax, rax       ; Check if more digits
        jnz convert_loop

        ; Print the string
        mov rcx, rbx
        call print_string

        mov rsp, rbp
        pop rbp
        ret
    print_number ENDP

END