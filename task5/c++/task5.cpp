#include <iostream>
#include <immintrin.h>
#include <chrono>
#include <string>
#include <cstring>
#include <random>

// Функція для підрахунку входжень підрядка за допомогою простого циклу
int count_substring_loop(const char* str, size_t str_len, const char* substr, size_t substr_len) {
    int count = 0;
    for (size_t i = 0; i <= str_len - substr_len; ++i) {
        if (memcmp(str + i, substr, substr_len) == 0) {
            ++count;
        }
    }
    return count;
}

// Функція для підрахунку входжень підрядка за допомогою AVX2
int count_substring_avx2(const char* str, size_t str_len, const char* substr, size_t substr_len) {
    int count = 0;
    size_t i = 0;

    // Завантажуємо перший символ підрядка в усі елементи YMM-регістра
    __m256i first_char = _mm256_set1_epi8(substr[0]);

    // Обробляємо 32 символи за раз
    for (; i <= str_len - 32; i += 32) {
        __m256i str_chunk = _mm256_loadu_si256((__m256i*)(str + i));
        __m256i cmp_result = _mm256_cmpeq_epi8(str_chunk, first_char);
        int mask = _mm256_movemask_epi8(cmp_result);

        while (mask) {
            int index = _tzcnt_u32(mask);
            if (i + index + substr_len <= str_len &&
                memcmp(str + i + index, substr, substr_len) == 0) {
                ++count;
            }
            mask = mask & (mask - 1); // Очищуємо найменш значущу встановлену биту
        }
    }

    // Обробляємо залишкові символи
    for (; i <= str_len - substr_len; ++i) {
        if (memcmp(str + i, substr, substr_len) == 0) {
            ++count;
        }
    }

    return count;
}

// Шаблонна функція для вимірювання часу виконання
template<typename Func>
void measure_time(Func func, const char* str, size_t str_len, const char* substr, size_t substr_len, const std::string& label) {
    auto start = std::chrono::high_resolution_clock::now();
    int result = func(str, str_len, substr, substr_len);
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::milli> elapsed = end - start;
    std::cout << label << " took " << elapsed.count() << " ms" << std::endl;
    std::cout << "Occurrences found: " << result << std::endl;
}

// Функція для генерації випадкового підрядка
void generate_random_substring(char* substr, size_t substr_len) {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(97, 122); // ASCII-значення для малих літер

    for (size_t i = 0; i < substr_len; ++i) {
        substr[i] = static_cast<char>(dis(gen));
    }
    substr[substr_len] = '\0';
}

int main() {
    const size_t str_len = 10000000;
    const size_t substr_len = 4;

    // Виділяємо пам'ять з вирівнюванням для рядка та підрядка
    char* str = static_cast<char*>(_aligned_malloc(str_len + 1, 32));
    char* substr = static_cast<char*>(_aligned_malloc(substr_len + 1, 32));

    if (!str || !substr) {
        std::cerr << "Memory allocation failed" << std::endl;
        return 1;
    }

    // Генеруємо випадковий рядок
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(97, 122); // ASCII-значення для малих літер

    for (size_t i = 0; i < str_len; ++i) {
        str[i] = static_cast<char>(dis(gen));
    }
    str[str_len] = '\0';

    // Генеруємо випадковий підрядок
    generate_random_substring(substr, substr_len);
    std::cout << "Random substring: " << substr << std::endl;

    // Вимірюємо час для функції на основі циклу
    measure_time(count_substring_loop, str, str_len, substr, substr_len, "Loop-based search");

    // Вимірюємо час для функції AVX2
    measure_time(count_substring_avx2, str, str_len, substr, substr_len, "AVX2 search");

    // Звільняємо виділену пам'ять
    _aligned_free(str);
    _aligned_free(substr);

    return 0;
}
