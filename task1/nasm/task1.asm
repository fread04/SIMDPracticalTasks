section .data
    array_size equ 100000
    align 32
    array1 times array_size dd 0
    array2 times array_size dd 0
    result_regular times array_size dd 0
    result_simd times array_size dd 0

    fmt_time_simd db "SIMD addition time: %lld nanoseconds", 10, 0
    fmt_time_regular db "Regular addition time: %lld nanoseconds", 10, 0
    fmt_result db "Sample result: %d", 10, 0
    fmt_compare db "Results match: %s", 10, 0
    str_true db "true", 0
    str_false db "false", 0

section .bss
    align 32
    start_time resq 2
    end_time resq 2

section .text
    global _start
    extern printf
    extern exit
    extern clock_gettime

_start:
    ; Initialize arrays
    mov ecx, array_size
    xor eax, eax
.init_loop:
    mov [array1 + eax * 4], eax
    mov ebx, array_size
    sub ebx, eax
    mov [array2 + eax * 4], ebx
    inc eax
    loop .init_loop

    ; Measure time for regular addition
    call get_time
    mov [start_time], rax
    mov [start_time + 8], rdx

    call add_arrays_regular

    call get_time
    mov [end_time], rax
    mov [end_time + 8], rdx

    ; Calculate and print regular time
    mov rdi, end_time
    mov rsi, start_time
    call time_diff
    mov rdi, fmt_time_regular
    mov rsi, rax
    xor eax, eax
    call printf

    ; Measure time for SIMD addition
    call get_time
    mov [start_time], rax
    mov [start_time + 8], rdx

    call add_arrays_simd

    call get_time
    mov [end_time], rax
    mov [end_time + 8], rdx

    ; Calculate and print SIMD time
    mov rdi, end_time
    mov rsi, start_time
    call time_diff
    mov rdi, fmt_time_simd
    mov rsi, rax
    xor eax, eax
    call printf

    ; Print a sample result
    mov edi, fmt_result
    mov esi, [result_simd]
    xor eax, eax
    call printf

    ; Compare results
    call compare_results
    mov edi, fmt_compare
    mov esi, eax
    xor eax, eax
    call printf

    ; Exit program
    mov edi, 0
    call exit

add_arrays_regular:
    xor ecx, ecx
.loop:
    mov eax, [array1 + ecx * 4]
    add eax, [array2 + ecx * 4]
    mov [result_regular + ecx * 4], eax
    inc ecx
    cmp ecx, array_size
    jl .loop
    ret

add_arrays_simd:
    xor ecx, ecx
.loop:
    vmovdqu ymm0, [array1 + ecx * 4]
    vpaddd ymm0, ymm0, [array2 + ecx * 4]
    vmovdqu [result_simd + ecx * 4], ymm0
    add ecx, 8
    cmp ecx, array_size
    jl .loop
    ; Handle remaining elements
.remainder:
    cmp ecx, array_size
    jge .done
    mov eax, [array1 + ecx * 4]
    add eax, [array2 + ecx * 4]
    mov [result_simd + ecx * 4], eax
    inc ecx
    jmp .remainder
.done:
    vzeroupper
    ret

compare_results:
    xor ecx, ecx
.loop:
    mov eax, [result_regular + ecx * 4]
    cmp eax, [result_simd + ecx * 4]
    jne .not_equal
    inc ecx
    cmp ecx, array_size
    jl .loop
    mov eax, str_true
    ret
.not_equal:
    mov eax, str_false
    ret

get_time:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov edi, 0  ; CLOCK_REALTIME
    mov rsi, rsp
    call clock_gettime
    mov rax, [rsp]
    mov rdx, [rsp + 8]
    leave
    ret

time_diff:
    mov rax, [rdi]
    sub rax, [rsi]
    imul rax, 1000000000
    mov rcx, [rdi + 8]
    sub rcx, [rsi + 8]
    add rax, rcx
    ret