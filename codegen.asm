.DATA
    ; Make buffer and position public for other modules
    PUBLIC string_buffer
    PUBLIC output_pos

    ; Buffer for generated code
    string_buffer db 8192 dup(0)  ; 8KB buffer for generated code
    output_pos dq 0               ; Current position in output buffer

    ; Code templates
    data_section db ".DATA", 13, 10, 0
    code_section db ".CODE", 13, 10, 0
    main_proc db "main PROC", 13, 10, 0
    main_endp db "main ENDP", 13, 10, 0
    end_directive db "END", 13, 10, 0
    
    ; Variable declarations
    buffer_decl db "    buffer db 256 dup(0)", 13, 10, 0
    prompt_decl db "    prompt db ""Enter something: "", 0", 13, 10, 0
    bytes_read_decl db "    bytesRead dq 0", 13, 10, 0
    bytes_written_decl db "    bytesWritten dq 0", 13, 10, 0
    
    ; Import templates
    extern_write db "EXTERN WriteConsoleA:PROC", 13, 10, 0
    extern_read db "EXTERN ReadConsoleA:PROC", 13, 10, 0
    extern_handle db "EXTERN GetStdHandle:PROC", 13, 10, 0
    extern_exit db "EXTERN ExitProcess:PROC", 13, 10, 0

    ; Code snippets
    stack_setup db "    sub rsp, 48", 13, 10, 0    ; 32 bytes shadow space + 16 alignment
    
    get_stdin db "    ; Get handle for standard input", 13, 10
              db "    mov rcx, -10", 13, 10
              db "    call GetStdHandle", 13, 10
              db "    mov rbx, rax", 13, 10, 0
              
    get_stdout db "    ; Get handle for standard output", 13, 10
               db "    mov rcx, -11", 13, 10
               db "    call GetStdHandle", 13, 10
               db "    mov rdi, rax", 13, 10, 0

    print_prompt db "    ; Print prompt", 13, 10
                db "    mov rcx, rdi", 13, 10
                db "    lea rdx, prompt", 13, 10
                db "    mov r8, 17", 13, 10    ; Length of "Enter something: "
                db "    lea r9, bytesWritten", 13, 10
                db "    call WriteConsoleA", 13, 10, 0

    read_input db "    ; Read user input", 13, 10
              db "    mov rcx, rbx", 13, 10
              db "    lea rdx, buffer", 13, 10
              db "    mov r8, 255", 13, 10
              db "    lea r9, bytesRead", 13, 10
              db "    mov QWORD PTR [rsp+32], 0", 13, 10
              db "    call ReadConsoleA", 13, 10, 0

    print_input db "    ; Echo input back", 13, 10
               db "    mov rcx, rdi", 13, 10
               db "    lea rdx, buffer", 13, 10
               db "    mov r8, [bytesRead]", 13, 10
               db "    lea r9, bytesWritten", 13, 10
               db "    call WriteConsoleA", 13, 10, 0

    program_exit db "program_exit:", 13, 10
                db "    xor ecx, ecx", 13, 10
                db "    call ExitProcess", 13, 10, 0

    ; Import parser data structures
    EXTERN operations:BYTE
    EXTERN op_count:QWORD
    EXTERN string_table:BYTE
    EXTERN string_count:QWORD
    EXTERN symbol_table:BYTE
    EXTERN symbol_count:QWORD
    
    ; Operation types from parser
    OP_INPUT    equ 1
    OP_PRINT    equ 2

.CODE

; Helper to append string to buffer
; Input: RCX = string to append
append_string PROC
    push rbx
    push rsi
    push rdi
    
    mov rsi, rcx            ; Source string
    lea rdi, string_buffer  
    add rdi, [output_pos]   ; Destination = buffer + current position
    
    ; Copy string
copy_loop:
    mov al, [rsi]
    test al, al            ; Check for null terminator
    jz copy_done
    mov [rdi], al
    inc rsi
    inc rdi
    inc QWORD PTR [output_pos]
    jmp copy_loop
    
copy_done:
    pop rdi
    pop rsi
    pop rbx
    ret
append_string ENDP

; Generate code for the program
generate_code PROC
    push rbp
    mov rbp, rsp
    sub rsp, 40h        ; Shadow space + local vars
    
    ; Initialize buffer position
    mov QWORD PTR [output_pos], 0
    
    ; Generate .DATA section
    lea rcx, data_section
    call append_string
    
    ; Add variable declarations
    lea rcx, buffer_decl
    call append_string
    lea rcx, prompt_decl
    call append_string
    lea rcx, bytes_read_decl
    call append_string
    lea rcx, bytes_written_decl
    call append_string
    
    ; Generate .CODE section
    lea rcx, code_section
    call append_string
    
    ; Add imports
    lea rcx, extern_handle
    call append_string
    lea rcx, extern_read
    call append_string
    lea rcx, extern_write
    call append_string
    lea rcx, extern_exit
    call append_string
    
    ; Start main procedure
    lea rcx, main_proc
    call append_string
    
    ; Set up stack frame
    lea rcx, stack_setup
    call append_string
    
    ; Get handles
    lea rcx, get_stdin
    call append_string
    lea rcx, get_stdout
    call append_string
    
    ; Process operations
    xor rbx, rbx        ; Operation counter
process_ops:
    cmp rbx, [op_count]
    jae ops_done
    
    ; Calculate operation address
    mov rax, rbx
    mov rcx, 72         ; Size of operation record
    mul rcx
    lea rsi, operations
    add rsi, rax
    
    ; Check operation type
    mov al, [rsi]       ; Get operation type
    cmp al, OP_INPUT
    je gen_input
    cmp al, OP_PRINT
    je gen_print
    jmp next_op
    
gen_input:
    ; Generate input code sequence
    lea rcx, print_prompt
    call append_string
    lea rcx, read_input
    call append_string
    jmp next_op
    
gen_print:
    ; Generate print code sequence
    lea rcx, print_input
    call append_string
    
next_op:
    inc rbx
    jmp process_ops
    
ops_done:
    ; Add program exit
    lea rcx, program_exit
    call append_string
    
    ; End main procedure
    lea rcx, main_endp
    call append_string
    
    ; Add END directive
    lea rcx, end_directive
    call append_string
    
    mov rsp, rbp
    pop rbp
    ret
generate_code ENDP

END