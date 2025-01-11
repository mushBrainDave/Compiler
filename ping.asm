EXTERN ExitProcess : PROC
EXTERN IcmpCreateFile : PROC
EXTERN IcmpSendEcho : PROC
EXTERN IcmpCloseHandle : PROC
EXTERN inet_addr : PROC
EXTERN printf : PROC
EXTERN GetLastError : PROC

.DATA
    ; ICMP data
    ReplyBuffer db 1024  dup(0)
    ReplySize   dd 1024          ; Changed to dd (32-bit)
    SendData    db "Ping Request", 0
    SendSize    dd 12          ; Changed to dd (32-bit)
    IPAddress   db "8.8.8.8", 0
    
    ; Messages
    msgError    db "Error: Could not send ping. Error code: %d", 13, 10, 0
    msgSuccess  db "Reply from %s: bytes=%d time=%ldms", 13, 10, 0
    msgTimeout  db "Request timed out. Error code: %d", 13, 10, 0
    msgHandle   db "ICMP Handle created: %llx", 13, 10, 0
    msgIPAddr   db "IP Address converted to: %lx", 13, 10, 0
    msgStatus db "ICMP Status Code: %d", 13, 10, 0

    ; ICMP Options
    IcmpOptions dd 128   ; TTL
                dd 0   ; TOS
                dd 0   ; Flags
                dd 0   ; OptionsSize
                dq 0   ; OptionsData pointer

.CODE
main PROC
    ; Allocate shadow space and preserve non-volatile registers
    push rbx
    push r12
    sub rsp, 38h    ; 32 bytes shadow space + 8 bytes alignment
    
    ; Create ICMP handle
    call IcmpCreateFile
    test rax, rax      ; Check if handle is valid
    jz error
    mov rbx, rax       ; Save handle
    
    ; Print handle value (debug)
    lea rcx, msgHandle
    mov rdx, rax
    call printf
    
    ; Convert IP string to network order
    lea rcx, IPAddress
    call inet_addr
    mov r12d, eax      ; Save IP address in r12d (32-bit)
    
    ; Print converted IP (debug)
    lea rcx, msgIPAddr
    mov edx, r12d
    call printf
    
    ; Prepare for IcmpSendEcho
    sub rsp, 40h          ; Allocate 64 bytes (32 shadow + 32 params)
    
    mov rcx, rbx          ; IcmpHandle
    mov edx, r12d         ; DestinationAddress
    lea r8, SendData      ; RequestData
    mov r9d, [SendSize]   ; RequestSize
    
    lea rax, IcmpOptions
    mov [rsp+20h], rax    ; RequestOptions
    lea rax, ReplyBuffer
    mov [rsp+28h], rax    ; ReplyBuffer
    mov eax, [ReplySize]
    mov [rsp+30h], eax    ; ReplySize
    mov dword ptr [rsp+38h], 1000  ; Timeout
    
    call IcmpSendEcho
    add rsp, 40h          ; Restore stack

    
    test eax, eax         ; Check if ping successful
    jz ping_failed
    
    ; Print success message
    lea rcx, msgSuccess
    lea rdx, IPAddress
    mov r8d, dword ptr [ReplyBuffer + 12]
    mov r9d, dword ptr [ReplyBuffer + 8]  ; Round trip time offset
    call printf
    lea rcx, msgStatus
    mov edx, dword ptr [ReplyBuffer + 4]  ; ICMP Status offset

    call printf

    jmp cleanup
    
ping_failed:
    call GetLastError     ; Get error code
    mov rdx, rax          ; Error code for printf
    lea rcx, msgTimeout
    call printf
    
cleanup:
    ; Close ICMP handle
    mov rcx, rbx
    call IcmpCloseHandle
    
    ; Restore non-volatile registers and stack
    add rsp, 8h
    pop r12
    pop rbx
    
    ; Exit program
    xor ecx, ecx          ; Return 0
    call ExitProcess

error:
    call GetLastError     ; Get error code
    mov rdx, rax          ; Error code for printf
    lea rcx, msgError
    call printf
    mov ecx, 1            ; Return error code 1
    call ExitProcess

main ENDP

END