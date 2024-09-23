section .data
    matrix_size equ 1024  ; Уменьшим размер матрицы для отладки
    element_size equ 4
    align 32
    matrix_a times (matrix_size * matrix_size) dd 1.0
    matrix_b times (matrix_size * matrix_size) dd 1.0
    matrix_result times (matrix_size * matrix_size) dd 0.0
    matrix_result_simd times (matrix_size * matrix_size) dd 0.0
    fmt_time_simd db "SIMD matrix multiplication time: %lld nanoseconds", 10, 0
    fmt_time_regular db "Regular matrix multiplication time: %lld nanoseconds", 10, 0
    fmt_result db "Sample result (0,0): %f", 10, 0
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
    ; Initialize matrices
    call init_matrices

    ; Measure time for regular matrix multiplication
    call get_time
    mov [start_time], rax
    mov [start_time + 8], rdx
    call multiply_matrices_regular
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

    ; Measure time for SIMD matrix multiplication
    call get_time
    mov [start_time], rax
    mov [start_time + 8], rdx
    call multiply_matrices_simd
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
    movss xmm0, [matrix_result_simd]
    cvtss2sd xmm0, xmm0
    mov eax, 1
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

init_matrices:
    ; Matrices are already initialized with 1.0
    ret

multiply_matrices_regular:
    mov r8d, matrix_size  ; rows
    xor edi, edi  ; i
.outer_loop:
    xor esi, esi  ; j
.middle_loop:
    xorps xmm0, xmm0  ; sum
    xor edx, edx  ; k
.inner_loop:
    mov eax, edi
    imul eax, matrix_size
    add eax, edx
    movss xmm1, [matrix_a + eax * 4]
    mov eax, edx
    imul eax, matrix_size
    add eax, esi
    movss xmm2, [matrix_b + eax * 4]
    mulss xmm1, xmm2
    addss xmm0, xmm1
    inc edx
    cmp edx, matrix_size
    jl .inner_loop
    mov eax, edi
    imul eax, matrix_size
    add eax, esi
    movss [matrix_result + eax * 4], xmm0
    inc esi
    cmp esi, matrix_size
    jl .middle_loop
    inc edi
    cmp edi, matrix_size
    jl .outer_loop
    ret

multiply_matrices_simd:
    mov r8d, matrix_size  ; rows
    xor edi, edi  ; i
.outer_loop:
    xor esi, esi  ; j
.middle_loop:
    vxorps ymm0, ymm0, ymm0  ; Initialize 8 sums to 0
    xor edx, edx  ; k
.inner_loop:
    mov eax, edi
    imul eax, matrix_size
    add eax, edx
    vbroadcastss ymm1, [matrix_a + eax * 4]  ; Broadcast a[i][k] to all elements
    mov eax, edx
    imul eax, matrix_size
    add eax, esi
    vmovups ymm2, [matrix_b + eax * 4]  ; Load 8 elements of b[k][j]
    vfmadd231ps ymm0, ymm1, ymm2  ; ymm0 += ymm1 * ymm2
    inc edx
    cmp edx, matrix_size
    jl .inner_loop
    mov eax, edi
    imul eax, matrix_size
    add eax, esi
    vmovups [matrix_result_simd + eax * 4], ymm0  ; Store 8 results
    add esi, 8
    cmp esi, matrix_size
    jl .middle_loop
    inc edi
    cmp edi, matrix_size
    jl .outer_loop
    vzeroupper
    ret

compare_results:
    mov ecx, matrix_size * matrix_size
.loop:
    dec ecx
    movss xmm0, [matrix_result + ecx * 4]
    movss xmm1, [matrix_result_simd + ecx * 4]
    ucomiss xmm0, xmm1
    jne .not_equal
    jnz .loop
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