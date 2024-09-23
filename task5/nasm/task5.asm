section .data
    string db "this is a simple string for testing SIMD substring search", 0
    substring db "simple", 0
    result_fmt db "Occurrences found: %d", 10, 0
    fmt_time_simd db "SIMD search took %lld ms", 10, 0
    fmt_time_regular db "Regular search took %lld ms", 10, 0
    str_true db "Substring found!", 10, 0
    str_false db "Substring not found.", 10, 0

section .bss
    align 32
    count resd 1
    simd_count resd 1
    start_time resq 2
    end_time resq 2

section .text
    global _start
    extern printf
    extern exit
    extern clock_gettime

_start:
    ; Обычный поиск подстроки
    call get_time
    mov [start_time], rax
    mov [start_time + 8], rdx
    call search_regular
    call get_time
    mov [end_time], rax
    mov [end_time + 8], rdx
    mov rdi, end_time
    mov rsi, start_time
    call time_diff
    mov rdi, fmt_time_regular
    mov rsi, rax
    xor eax, eax
    call printf

    ; Поиск с использованием SIMD
    call get_time
    mov [start_time], rax
    mov [start_time + 8], rdx
    call search_simd
    call get_time
    mov [end_time], rax
    mov [end_time + 8], rdx
    mov rdi, end_time
    mov rsi, start_time
    call time_diff
    mov rdi, fmt_time_simd
    mov rsi, rax
    xor eax, eax
    call printf

    ; Печать результата
    mov eax, [count]
    mov edi, result_fmt
    mov esi, eax
    xor eax, eax
    call printf

    ; Завершение программы
    mov edi, 0
    call exit

search_regular:
    ; Стандартный поиск подстроки
    mov rsi, string  ; Указатель на строку
    mov rdi, substring  ; Указатель на подстроку
    xor eax, eax
    xor ebx, ebx  ; Счетчик вхождений
.loop:
    mov al, [rsi]
    test al, al
    jz .done
    cmp al, [rdi]
    jne .next_char
    ; Проверка всей подстроки
    mov rcx, rsi
    mov rdx, rdi
.check_loop:
    mov al, [rdx]
    test al, al
    jz .found
    cmp al, [rcx]
    jne .next_char
    inc rcx
    inc rdx
    jmp .check_loop
.found:
    inc ebx  ; Увеличиваем счетчик вхождений
.next_char:
    inc rsi
    jmp .loop
.done:
    mov [count], ebx
    ret

search_simd:
    ; Поиск подстроки с использованием SIMD
    mov rsi, string  ; Указатель на строку
    mov rdi, substring  ; Указатель на подстроку
    xor eax, eax
    xor ebx, ebx  ; Счетчик вхождений
    mov r8d, 6  ; Длина подстроки (для примера, длина 'simple')

.loop_simd:
    ; Загружаем данные для сравнения (используем AVX2)
    vmovdqu ymm0, [rsi]  ; Загружаем 32 байта из строки
    vmovdqu ymm1, [rdi]  ; Загружаем 32 байта из подстроки
    vpcmpeqb ymm2, ymm0, ymm1  ; Сравниваем байты
    vpmovmskb rax, ymm2  ; Преобразуем результат в битовую маску
    test rax, rax
    jz .next_chunk  ; Если нет совпадений, перейти к следующему блоку

    ; Проверяем совпадение всей подстроки
    mov rcx, rsi
    mov rdx, rdi
    mov r9d, r8d
.check_simd_loop:
    mov al, [rdx]
    test al, al
    jz .simd_found
    cmp al, [rcx]
    jne .next_chunk
    inc rcx
    inc rdx
    dec r9d
    jnz .check_simd_loop
.simd_found:
    inc ebx  ; Увеличиваем счетчик вхождений

.next_chunk:
    add rsi, 32
    test byte [rsi], 0
    jz .done_simd
    jmp .loop_simd
.done_simd:
    mov [simd_count], ebx
    ret

get_time:
    ; Получение времени
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
    ; Вычисление разницы во времени
    mov rax, [rdi]
    sub rax, [rsi]
    imul rax, 1000000000
    mov rcx, [rdi + 8]
    sub rcx, [rsi + 8]
    add rax, rcx
    ret