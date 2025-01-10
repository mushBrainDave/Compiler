.DATA
    ; Make these symbols available to lexer_test.asm
    PUBLIC buffer
    PUBLIC sourceLength
    PUBLIC print_error
    
    ; Windows constants
    GENERIC_READ     equ 80000000h     ; Access mode for CreateFileA
    GENERIC_WRITE    equ 40000000h     ; Access mode for CreateFileA
    FILE_SHARE_READ  equ 1h            ; File share mode
    FILE_SHARE_WRITE equ 2h            ; File share write
    CREATE_ALWAYS    equ 2h            ; Create new file, overwrite if exists
    OPEN_EXISTING    equ 3h            ; Open only if exists
    INVALID_HANDLE_VALUE equ -1        ; Error return value

    ; File paths
    sourcePath db "C:/Users/mushbrain/source/repos/assembly/x64/Debug/source.dython", 0
    outputPath db "C:/Users/mushbrain/source/repos/assembly/x64/Debug/output.asm", 0

    ; Buffers
    buffer db 4096 dup(0)              ; Buffer for source file
    sourceLength dq 0                  ; Length of source file
    bytesRead dq 0                     ; Bytes read from file
    bytesWritten dq 0                  ; Bytes written to file

    ; Messages
    errorOpen db "Error: Could not open source file", 13, 10, 0
    errorRead db "Error: Could not read source file", 13, 10, 0
    error_write db "Error: Could not write output file", 13, 10, 0
    success_msg db "Successfully generated code", 13, 10, 0
    bytes_written_msg db "Bytes written: ", 0

.CODE
    EXTERN run_lexer:PROC        ; From Lexer.asm
    EXTERN parse_program:PROC     ; From parser.asm
    EXTERN generate_code:PROC     ; From codegen.asm
    EXTERN string_buffer:BYTE     ; From codegen.asm
    EXTERN output_pos:QWORD      ; From codegen.asm
    EXTERN current_pos:QWORD     ; From lexer.asm
    EXTERN ExitProcess:PROC
    EXTERN CreateFileA:PROC
    EXTERN ReadFile:PROC
    EXTERN CloseHandle:PROC
    EXTERN GetStdHandle:PROC
    EXTERN WriteConsoleA:PROC
    EXTERN WriteFile:PROC
    EXTERN print_string:PROC
    EXTERN print_number:PROC

print_error PROC
    push rbp
    mov rbp, rsp
    sub rsp, 40

    ; Get handle to stdout
    mov rcx, -11        ; STD_OUTPUT_HANDLE
    call GetStdHandle
    mov rcx, rax        ; Console handle

    ; Get string length
    mov rdx, rbp        ; Error message pointer is in RDX
    xor r8, r8          ; Length counter
count_loop:
    cmp BYTE PTR [rdx + r8], 0
    je count_done
    inc r8
    jmp count_loop
count_done:

    ; Write error message
    mov rdx, rbp        ; Error message
    lea r9, [rsp + 32]  ; Bytes written
    mov QWORD PTR [rsp + 32], 0
    call WriteConsoleA

    mov rsp, rbp
    pop rbp
    ret
print_error ENDP

main PROC
    push rbp
    mov rbp, rsp
    sub rsp, 40h        ; Reserve shadow space + alignment

    ; Open source file
    lea rcx, sourcePath ; File path
    mov rdx, GENERIC_READ   ; Access mode
    mov r8, FILE_SHARE_READ ; Share mode
    xor r9, r9          ; Security attributes (NULL)
    mov QWORD PTR [rsp+32], OPEN_EXISTING  ; Creation disposition
    mov QWORD PTR [rsp+40], 0      ; Flags and attributes
    mov QWORD PTR [rsp+48], 0      ; Template file
    call CreateFileA

    ; Check for error
    cmp rax, INVALID_HANDLE_VALUE
    je open_error

    ; Save file handle
    mov rbx, rax

    ; Read file
    mov rcx, rbx        ; File handle
    lea rdx, buffer     ; Buffer
    mov r8, 4096        ; Buffer size
    lea r9, bytesRead   ; Bytes read
    mov QWORD PTR [rsp+32], 0  ; Overlapped (NULL)
    call ReadFile

    ; Check for error
    test rax, rax
    jz read_error

    ; Save length
    mov rax, bytesRead
    mov [sourceLength], rax

    ; Close file
    mov rcx, rbx
    call CloseHandle

    ; Step 1: Lexical analysis
    call run_lexer

    ; Step 2: Parsing
    ; Reset the current position for the parser
    mov QWORD PTR [current_pos], 0
    call parse_program
    
    ; Step 3: Code generation
    call generate_code
    
    ; Step 4: Write generated code to output file
    ; Open output file
    lea rcx, outputPath
    mov rdx, GENERIC_WRITE
    xor r8, r8          ; No sharing
    xor r9, r9          ; No security
    mov QWORD PTR [rsp+32], CREATE_ALWAYS
    mov QWORD PTR [rsp+40], 0
    mov QWORD PTR [rsp+48], 0
    call CreateFileA

;    cmp rax, INVALID_HANDLE_VALUE
    je write_error
    mov rbx, rax        ; Save handle
    
    ; Write the generated code
    mov rcx, rbx
    lea rdx, string_buffer
    mov r8, [output_pos]   ; Length of generated code
    lea r9, bytesWritten
    mov QWORD PTR [rsp+32], 0
    call WriteFile
    test rax, rax
    jz write_error

    ; Print success message
    lea rcx, success_msg
    call print_string
    
    ; Print bytes written
    lea rcx, bytes_written_msg
    call print_string
    mov rdx, [bytesWritten]
    call print_number

    ; Close output file
    mov rcx, rbx
    ;call CloseHandle

    ; Success exit
    xor ecx, ecx        ; Exit code 0
    jmp exit_prog

open_error:
    lea rcx, errorOpen
    call print_error
    mov ecx, 1          ; Exit code 1
    jmp exit_prog

read_error:
    lea rcx, errorRead
    call print_error
    mov ecx, 2          ; Exit code 2
    jmp exit_prog

write_error:
    lea rcx, error_write
    call print_error
    mov ecx, 3          ; Exit code 3

exit_prog:
    ; Ensure stack is aligned before calling ExitProcess
    push rcx            ; Save exit code
    sub rsp, 20h        ; Allocate shadow space and align stack (32 bytes total)
    call ExitProcess    ; Never returns

main ENDP

END