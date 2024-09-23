section .data
    array_size equ 100000
    align 32
    array1 times array_size dd 1.0    ; Инициализируем массивы одинаковыми значениями
    array2 times array_size dd 1.0    ; для простоты тестирования
    result_regular times array_size dd 0
    result_simd times array_size dd 0
    fmt_time_simd_add db "SIMD addition time: %lld nanoseconds", 10, 0
    fmt_time_regular_add db "Regular addition time: %lld nanoseconds", 10, 0
    fmt_time_simd_dot db "SIMD dot product time: %lld nanoseconds", 10, 0
    fmt_time_regular_dot db "Regular dot product time: %lld nanoseconds", 10, 0
    fmt_result_add db "Sample addition result: %d", 10, 0
    fmt_result_dot db "Dot product result: %f", 10, 0
    fmt_compare db "Results match: %s", 10, 0
    str_true db "true", 0
    str_false db "false", 0

section .bss
    align 32
    start_time resq 2
    end_time resq 2
    dot_product_regular resq 1
    dot_product_simd resq 1

section .text
    global main
    extern printf
    extern exit
    extern clock_gettime

main:
    ; Инициализация массивов
    mov ecx, array_size
    xor eax, eax
.init_loop:
    mov dword [array1 + eax * 4], 0x3f800000  ; float 1.0
    mov dword [array2 + eax * 4], 0x3f800000  ; float 1.0
    inc eax
    cmp eax, ecx
    jl .init_loop

    ; Тестируем сложение и скалярное произведение
    ; Оставим весь остальной код таким же, так как исправления касаются только корректной инициализации данных


    ; Vector Addition
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
    mov rdi, fmt_time_regular_add
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
    mov rdi, fmt_time_simd_add
    mov rsi, rax
    xor eax, eax
    call printf

    ; Print a sample result
    mov edi, fmt_result_add
    mov esi, [result_simd]
    xor eax, eax
    call printf

    ; Compare addition results
    call compare_results
    mov edi, fmt_compare
    mov esi, eax
    xor eax, eax
    call printf

    ; Dot Product
    ; Measure time for regular dot product
    call get_time
    mov [start_time], rax
    mov [start_time + 8], rdx
    call dot_product_regular_calc
    call get_time
    mov [end_time], rax
    mov [end_time + 8], rdx
    ; Calculate and print regular time
    mov rdi, end_time
    mov rsi, start_time
    call time_diff
    mov rdi, fmt_time_regular_dot
    mov rsi, rax
    xor eax, eax
    call printf

    ; Measure time for SIMD dot product
    call get_time
    mov [start_time], rax
    mov [start_time + 8], rdx
    call dot_product_simd_calc
    call get_time
    mov [end_time], rax
    mov [end_time + 8], rdx
    ; Calculate and print SIMD time
    mov rdi, end_time
    mov rsi, start_time
    call time_diff
    mov rdi, fmt_time_simd_dot
    mov rsi, rax
    xor eax, eax
    call printf

    ; Print dot product result
    mov edi, fmt_result_dot
    movss xmm0, [dot_product_simd]
    cvtss2sd xmm0, xmm0
    mov eax, 1
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

dot_product_regular_calc:
    xor ecx, ecx
    vxorps xmm0, xmm0, xmm0
.loop:
    movss xmm1, [array1 + ecx * 4]
    mulss xmm1, [array2 + ecx * 4]
    addss xmm0, xmm1
    inc ecx
    cmp ecx, array_size
    jl .loop
    movss [dot_product_regular], xmm0
    ret

dot_product_simd_calc:
    xor ecx, ecx                   ; Обнуляем счётчик
    vxorps ymm0, ymm0, ymm0         ; Обнуляем регистр для накопления суммы

.loop:
    vmovups ymm1, [array1 + ecx * 4] ; Загружаем элементы массива array1
    vmovups ymm2, [array2 + ecx * 4] ; Загружаем элементы массива array2
    vmulps ymm1, ymm1, ymm2          ; Перемножаем элементы
    vaddps ymm0, ymm0, ymm1          ; Добавляем к сумме
    add ecx, 8                       ; Увеличиваем счетчик на 8 элементов (256 бит)
    cmp ecx, array_size              ; Проверяем конец массива
    jl .loop

    ; Суммируем все элементы в ymm0
    vextractf128 xmm1, ymm0, 1       ; Извлекаем старшую половину ymm0 в xmm1
    vaddps xmm0, xmm0, xmm1          ; Складываем старшую и младшую половины ymm0
    vhaddps xmm0, xmm0, xmm0         ; Горизонтальное сложение (сумма пар)
    vhaddps xmm0, xmm0, xmm0         ; Еще раз горизонтальное сложение

    ; Обрабатываем оставшиеся элементы
.remainder:
    cmp ecx, array_size
    jge .done
    movss xmm1, [array1 + ecx * 4]   ; Загружаем оставшийся элемент
    mulss xmm1, [array2 + ecx * 4]   ; Умножаем
    addss xmm0, xmm1                 ; Добавляем к итоговой сумме
    inc ecx
    jmp .remainder

.done:
    movss [dot_product_simd], xmm0   ; Сохраняем результат
    vzeroupper                       ; Обнуляем верхнюю часть YMM регистров
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

section .data
    ns_to_ms dq 1000000.0  ; Наносекунды в миллисекунды