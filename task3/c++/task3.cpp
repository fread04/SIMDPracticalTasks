#include <iostream>
#include <immintrin.h>  // Для AVX-інтринсик-функцій
#include <chrono>
#include <memory>  // Для динамічного виділення пам'яті
#include <random>  // Для генерації випадкових чисел

// Проста версія функції додавання векторів (без SIMD)
void add_vectors(const float* a, const float* b, float* result, int size) {
    for (int i = 0; i < size; ++i) {
        result[i] = a[i] + b[i];
    }
}

// Проста версія функції для обчислення скалярного добутку (без SIMD)
float dot_product(const float* a, const float* b, int size) {
    float dot = 0.0f;
    for (int i = 0; i < size; ++i) {
        dot += a[i] * b[i];
    }
    return dot;
}

// Функція для додавання двох векторів з використанням AVX
// Ця функція використовує AVX для додавання векторів з 8 елементів (256 біт)
void add_vectors_avx(const float* a, const float* b, float* result, int size) {
    int i = 0;
    // Обробка даних в блоках по 8 елементів за раз (AVX використовує 256-бітні регістри)
    for (; i <= size - 8; i += 8) {
        // Завантажуємо 8 елементів з масивів a і b в AVX-регістри
        __m256 va = _mm256_loadu_ps(&a[i]);
        __m256 vb = _mm256_loadu_ps(&b[i]);

        // Складаємо вектори (по 8 елементів одночасно)
        __m256 v_sum = _mm256_add_ps(va, vb);

        // Зберігаємо результат назад у масив result
        _mm256_storeu_ps(&result[i], v_sum);
    }

    // Обробляємо залишкові елементи, які не діляться на 8
    for (; i < size; ++i) {
        result[i] = a[i] + b[i];
    }
}

// Функція для обчислення скалярного добутку двох векторів з використанням AVX
// Ця функція використовує AVX для виконання обчислень на 8 елементах за раз
float dot_product_avx(const float* a, const float* b, int size) {
    __m256 v_sum = _mm256_setzero_ps();  // Ініціалізуємо регістр суми нулями
    int i = 0;

    // Обробка даних в блоках по 8 елементів за раз (AVX використовує 256-бітні регістри)
    for (; i <= size - 8; i += 8) {
        // Завантажуємо 8 елементів з масивів a і b в AVX-регістри
        __m256 va = _mm256_loadu_ps(&a[i]);
        __m256 vb = _mm256_loadu_ps(&b[i]);

        // Обчислюємо добуток елементів (по 8 елементів одночасно)
        __m256 v_product = _mm256_mul_ps(va, vb);

        // Додаємо результати добутків
        v_sum = _mm256_add_ps(v_sum, v_product);
    }

    // Сумуємо елементи в регістрі
    float sum[8];
    _mm256_storeu_ps(sum, v_sum);
    float dot = 0.0f;
    for (int j = 0; j < 8; ++j) {
        dot += sum[j];
    }

    // Обробляємо залишкові елементи, які не діляться на 8
    for (; i < size; ++i) {
        dot += a[i] * b[i];
    }

    return dot;
}

// Функція для вимірювання часу виконання
template<typename Func>
void measure_time(Func func, const float* a, const float* b, float* result, int size, const std::string& label) {
    auto start = std::chrono::high_resolution_clock::now();
    func(a, b, result, size);
    auto end = std::chrono::high_resolution_clock::now();

    std::chrono::duration<double, std::milli> elapsed = end - start;
    std::cout << label << " took " << elapsed.count() << " ms" << std::endl;
}

// Функція для перевірки збігу результатів
bool check_results(const float* result1, const float* result2, int size) {
    for (int i = 0; i < size; ++i) {
        if (result1[i] != result2[i]) {
            return false;  // Якщо знайшли відмінність, повертаємо false
        }
    }
    return true;  // Якщо всі результати співпадають, повертаємо true
}

// Функція для обчислення процентного відхилення
float calculate_percentage_difference(float value1, float value2) {
    return std::abs(value1 - value2) / std::abs(value1) * 100.0f;
}

int main() {
    const int size = 1000000;  // Розмір масиву

    // Генератор випадкових чисел
    std::mt19937 generator(std::random_device{}());
    std::uniform_real_distribution<float> distribution(0.0f, 100.0f);  // Діапазон випадкових чисел

    // Динамічне виділення пам'яті для масивів
    auto a = std::make_unique<float[]>(size);
    auto b = std::make_unique<float[]>(size);
    auto result = std::make_unique<float[]>(size);
    auto result_avx = std::make_unique<float[]>(size);  // Масив для результатів AVX

    // Ініціалізація масивів випадковими значеннями
    for (int i = 0; i < size; ++i) {
        a[i] = distribution(generator);  // Заповнюємо перший масив випадковими значеннями
        b[i] = distribution(generator);  // Заповнюємо другий масив випадковими значеннями
    }

    // Вимірювання часу виконання звичайної функції додавання векторів
    measure_time(add_vectors, a.get(), b.get(), result.get(), size, "Regular vector addition");

    // Вимірювання часу виконання AVX-функції додавання векторів
    measure_time(add_vectors_avx, a.get(), b.get(), result_avx.get(), size, "AVX vector addition");

    // Перевірка результатів
    if (check_results(result.get(), result_avx.get(), size)) {
        std::cout << "Results match!" << std::endl;  // Якщо результати співпадають
    }
    else {
        std::cout << "Results do not match!" << std::endl;  // Якщо результати не співпадають
    }

    // Вимірювання часу виконання звичайної функції обчислення скалярного добутку
    float dot_result = dot_product(a.get(), b.get(), size);
    std::cout << "Regular dot product: " << dot_result << std::endl;

    // Вимірювання часу виконання AVX-функції обчислення скалярного добутку
    float avx_dot_result = dot_product_avx(a.get(), b.get(), size);
    std::cout << "AVX dot product: " << avx_dot_result << std::endl;

    // Перевірка правильності результатів
    if (std::abs(dot_result - avx_dot_result) < 1e-5) {
        std::cout << "Dot product results match!" << std::endl;  // Якщо результати співпадають
    }
    else {
        std::cout << "Dot product results do not match!" << std::endl;  // Если результаты не совпадают
        // Виводимо процентне відхилення
        float percentage_difference = calculate_percentage_difference(dot_result, avx_dot_result);
        std::cout << "Percentage difference: " << percentage_difference << "%" << std::endl;
    }

    return 0;
}