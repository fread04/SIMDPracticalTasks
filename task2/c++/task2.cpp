#include <iostream>
#include <immintrin.h>  // Для AVX-інтринсик-функцій
#include <chrono>       // Для вимірювання часу виконання
#include <malloc.h>     // Для _aligned_malloc і _aligned_free
#include <random>       // Для генерації випадкових чисел

// Звичайна функція додавання масивів без використання SIMD
// Додавання виконується поелементно
void add_arrays(const int* a, const int* b, int* result, int size) {
    for (int i = 0; i < size; ++i) {
        result[i] = a[i] + b[i];
    }
}

// SIMD-функція додавання масивів із використанням AVX та вирівнювання
// Використовує 256-бітні AVX-регістри для паралельної обробки 8 елементів
void add_arrays_avx_aligned(const int* a, const int* b, int* result, int size) {
    int i = 0;
    // Обробка даних блоками по 8 елементів (AVX використовує 256-бітні регістри)
    for (; i <= size - 8; i += 8) {
        // Завантажуємо 8 елементів з масивів a і b в AVX-регістри
        __m256i va = _mm256_load_si256((__m256i*) & a[i]);  // Завантажує вирівняні дані
        __m256i vb = _mm256_load_si256((__m256i*) & b[i]);  // Завантажує вирівняні дані

        // Складаємо 8 елементів одночасно
        __m256i vsum = _mm256_add_epi32(va, vb);

        // Зберігаємо результат додавання назад у масив result
        _mm256_store_si256((__m256i*) & result[i], vsum);  // Зберігає вирівняні дані
    }

    // Обробляємо залишкові елементи, які не діляться на 8
    for (; i < size; ++i) {
        result[i] = a[i] + b[i];
    }
}

// Шаблонна функція для вимірювання часу виконання
// Приймає функцію func і вимірює час її виконання
template<typename Func>
void measure_time(Func func, const int* a, const int* b, int* result, int size, const std::string& label) {
    auto start = std::chrono::high_resolution_clock::now();  // Засікаємо час початку
    func(a, b, result, size);  // Виконуємо функцію
    auto end = std::chrono::high_resolution_clock::now();    // Засікаємо час завершення
    std::chrono::duration<double, std::milli> elapsed = end - start;  // Обчислюємо різницю
    std::cout << label << " took " << elapsed.count() << " ms" << std::endl;  // Виводимо результат
}

// Функція для перевірки збігу результатів
bool check_results(const int* result1, const int* result2, int size) {
    for (int i = 0; i < size; ++i) {
        if (result1[i] != result2[i]) {
            return false;  // Якщо знайшли відмінність, повертаємо false
        }
    }
    return true;  // Якщо всі результати співпадають, повертаємо true
}

int main() {
    const int size = 100000;  // Розмір масиву

    // Генератор випадкових чисел
    std::mt19937 generator(std::random_device{}());
    std::uniform_int_distribution<int> distribution(0, 100);  // Діапазон випадкових чисел

    // Виділення пам'яті для трьох масивів з вирівнюванням 32 байта
    // Вирівнювання 32 байта необхідне для AVX інструкцій
    int* a = (int*)_aligned_malloc(size * sizeof(int), 32);
    int* b = (int*)_aligned_malloc(size * sizeof(int), 32);
    int* result = (int*)_aligned_malloc(size * sizeof(int), 32);
    int* result_simd = (int*)_aligned_malloc(size * sizeof(int), 32);  // Масив для результатів SIMD

    // Ініціалізація масивів випадковими значеннями
    for (int i = 0; i < size; ++i) {
        a[i] = distribution(generator);  // Заповнюємо перший масив випадковими значеннями
        b[i] = distribution(generator);  // Заповнюємо другий масив випадковими значеннями
    }

    // Вимірювання часу виконання звичайної функції додавання масивів
    measure_time(add_arrays, a, b, result, size, "Regular addition");

    // Вимірювання часу виконання SIMD-функції додавання масивів з вирівнюванням
    measure_time(add_arrays_avx_aligned, a, b, result_simd, size, "AVX addition (aligned)");

    // Перевірка результатів
    if (check_results(result, result_simd, size)) {
        std::cout << "Results match!" << std::endl;  // Якщо результати співпадають
    }
    else {
        std::cout << "Results do not match!" << std::endl;  // Якщо результати не співпадають
    }

    // Звільнення виділеної пам'яті
    _aligned_free(a);
    _aligned_free(b);
    _aligned_free(result);
    _aligned_free(result_simd);

    return 0;
}
