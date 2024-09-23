section .data
    array_size equ 100000
    alignment equ 32

    fmt_time_simd db "SIMD addition time (aligned): %lld nanoseconds", 10, 0
    fmt_time_regular db "Regular addition time: %lld nanoseconds", 10, 0
    fmt_result db "Sample result: %d", 10, 0
    fmt_compare db "Results match: %s", 10, 0
    str_true db "true", 0
    str_false db "false", 0

section .bss
    array1 resq 1
    array2 resq 1
    result_regular resq 1
    result_simd resq 1
    start_time resq 2
    end_time resq 2

section .text
    global _start
    extern printf
    extern posix_memalign
    extern free
    extern clock_gettime
    extern exit

_start:
    ; Call main function
    call main
    
    ; Exit program
    mov rdi, 0
    call exit

main:
    push rbp
    mov rbp, rsp

    ; Allocate aligned memory for array1
    mov rdi, array1
    mov esi, alignment
    mov edx, array_size * 4
    call posix_memalign
    test eax, eax
    jnz error_exit

    ; Allocate aligned memory for array2
    mov rdi, array2
    mov esi, alignment
    mov edx, array_size * 4
    call posix_memalign
    test eax, eax
    jnz error_exit

    ; Allocate aligned memory for result_regular
    mov rdi, result_regular
    mov esi, alignment
    mov edx, array_size * 4
    call posix_memalign
    test eax, eax
    jnz error_exit

    ; Allocate aligned memory for result_simd
    mov rdi, result_simd
    mov esi, alignment
    mov edx, array_size * 4
    call posix_memalign
    test eax, eax
    jnz error_exit

    ; Initialize arrays
    mov rcx, array_size
    xor rax, rax
.init_loop:
    mov rdx, [array1]
    mov [rdx + rax * 4], eax
    mov ebx, array_size
    sub ebx, eax
    mov rdx, [array2]
    mov [rdx + rax * 4], ebx
    inc rax
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

    call add_arrays_simd_aligned

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
    mov rdi, fmt_result
    mov rsi, [result_simd]
    mov rsi, [rsi]
    xor eax, eax
    call printf

    ; Compare results
    call compare_results
    mov rdi, fmt_compare
    mov rsi, rax
    xor eax, eax
    call printf

    ; Free allocated memory
    mov rdi, [array1]
    call free
    mov rdi, [array2]
    call free
    mov rdi, [result_regular]
    call free
    mov rdi, [result_simd]
    call free

    ; Exit program
    xor eax, eax
    leave
    ret

error_exit:
    ; Handle memory allocation error
    mov edi, 1
    call exit

add_arrays_regular:
    mov rax, [array1]
    mov rbx, [array2]
    mov rcx, [result_regular]
    mov rdx, array_size
.loop:
    mov esi, [rax]
    add esi, [rbx]
    mov [rcx], esi
    add rax, 4
    add rbx, 4
    add rcx, 4
    dec rdx
    jnz .loop
    ret

add_arrays_simd_aligned:
    mov rax, [array1]
    mov rbx, [array2]
    mov rcx, [result_simd]
    mov rdx, array_size
    shr rdx, 3  ; divide by 8 (process 8 integers at a time)
.loop:
    vmovdqa ymm0, [rax]
    vpaddd ymm0, ymm0, [rbx]
    vmovdqa [rcx], ymm0
    add rax, 32
    add rbx, 32
    add rcx, 32
    dec rdx
    jnz .loop

    ; Handle remaining elements
    mov rdx, array_size
    and rdx, 7
    jz .done
.remainder:
    mov esi, [rax]
    add esi, [rbx]
    mov [rcx], esi
    add rax, 4
    add rbx, 4
    add rcx, 4
    dec rdx
    jnz .remainder
.done:
    vzeroupper
    ret

compare_results:
    mov rax, [result_regular]
    mov rbx, [result_simd]
    mov rcx, array_size
.loop:
    mov edx, [rax]
    cmp edx, [rbx]
    jne .not_equal
    add rax, 4
    add rbx, 4
    dec rcx
    jnz .loop
    mov rax, str_true
    ret
.not_equal:
    mov rax, str_false
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
