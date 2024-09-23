#include <iostream>
#include <immintrin.h>  // Для AVX-інструкцій
#include <chrono>
#include <memory>
#include <cstdlib>

// Звичайна функція для множення векторів
void multiply_vectors(const float* a, const float* b, float* result, int size) {
    for (int i = 0; i < size; ++i) {
        result[i] = a[i] * b[i];
    }
}

// Функція для множення векторів з використанням AVX
void multiply_vectors_avx(const float* a, const float* b, float* result, int size) {
    int i = 0;
    for (; i <= size - 8; i += 8) {
        __m256 va = _mm256_loadu_ps(&a[i]);
        __m256 vb = _mm256_loadu_ps(&b[i]);
        __m256 v_mul = _mm256_mul_ps(va, vb);
        _mm256_storeu_ps(&result[i], v_mul);
    }
    for (; i < size; ++i) {
        result[i] = a[i] * b[i];
    }
}

// Перевірка результатів
bool check_results(const float* result1, const float* result2, int size) {
    for (int i = 0; i < size; ++i) {
        if (result1[i] != result2[i]) {
            return false;
        }
    }
    return true;
}

// Вимір часу
template<typename Func>
void measure_time(Func func, const float* a, const float* b, float* result, int size, const std::string& label) {
    auto start = std::chrono::high_resolution_clock::now();
    func(a, b, result, size);
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::milli> elapsed = end - start;
    std::cout << label << " took " << elapsed.count() << " ms" << std::endl;
}

int main() {
    const int size = 1000000;

    auto a = std::make_unique<float[]>(size);
    auto b = std::make_unique<float[]>(size);
    auto result = std::make_unique<float[]>(size);
    auto result_avx = std::make_unique<float[]>(size);

    // Ініціалізація випадковими значеннями
    for (int i = 0; i < size; ++i) {
        a[i] = static_cast<float>(std::rand()) / RAND_MAX * 100.0f;
        b[i] = static_cast<float>(std::rand()) / RAND_MAX * 100.0f;
    }

    // Вимір часу для звичайної функції
    measure_time(multiply_vectors, a.get(), b.get(), result.get(), size, "Regular vector multiplication");

    // Вимір часу для AVX-функції
    measure_time(multiply_vectors_avx, a.get(), b.get(), result_avx.get(), size, "AVX vector multiplication");

    // Перевірка результатів
    if (check_results(result.get(), result_avx.get(), size)) {
        std::cout << "Results match!" << std::endl;
    }
    else {
        std::cout << "Results do not match!" << std::endl;
    }

    return 0;
}
