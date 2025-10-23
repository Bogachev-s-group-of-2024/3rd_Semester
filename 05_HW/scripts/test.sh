#!/bin/bash

# Скрипт для тестирования программы с расширением .out
# Запускается в папке с исполняемым файлом

# Создаем папку logs если её нет
mkdir -p logs

# Константа для количества выводимых элементов
N=100

# Получаем текущее время в формате ССММЧЧ_ДДММГГГГ
TIMESTAMP=$(date +"%H%M%S_%d%m%Y")
OUTPUT_CONSOLE=/dev/stdout
K_FROM=-2
K_TO=4

# Функция для запуска теста
run_test() {
    local test_file=$1
    local k=$2

    echo "==========================================" >> $LOG_FILE
    echo "Тест: $test_file, параметр k=$k" >> $LOG_FILE
    echo "==========================================" >> $LOG_FILE
    echo "" >> $LOG_FILE

    # Запускаем программу и записываем результат
    $EXECUTABLE $N $test_file $k >> $LOG_FILE 2>&1

    echo "" >> $LOG_FILE
}

# Проверяем аргументы командной строки
if [ $# -eq 1 ]; then
    # Если передан аргумент от 1 до 8, ищем конкретный файл a0N.out
    if [[ $1 =~ ^[1-8]$ ]]; then
        EXECUTABLE="./a0$1.out"
        if [ ! -f "$EXECUTABLE" ]; then
            echo "Ошибка: файл $EXECUTABLE не найден в текущей директории"
            exit 1
        fi
        echo "Используем конкретный файл: $EXECUTABLE"
    else
        echo "Ошибка: аргумент должен быть числом от 1 до 8"
        echo "Использование: $0 [номер_программы]"
        echo "  номер_программы: 1-8 (опционально)"
        exit 1
    fi
else
    # Ищем любой исполняемый файл с расширением .out
    EXECUTABLE=$(find . -maxdepth 1 -name "*.out" -type f | head -1)
    
    # Проверяем существование исполняемого файла
    if [ -z "$EXECUTABLE" ]; then
        echo "Ошибка: файл с расширением .out не найден в текущей директории"
        echo "Использование: $0 [номер_программы]"
        echo "  номер_программы: 1-8 (опционально)"
        exit 1
    fi
fi

LOG_FILE="logs/${EXECUTABLE}_${TIMESTAMP}.log"

# Очищаем лог-файл перед началом тестирования
> $LOG_FILE

# Проверяем существование папки tests
if [ ! -d "tests" ]; then
    echo "Ошибка: папка tests не найдена"
    exit 1
fi

# Получаем список всех файлов в папке tests и сортируем их
test_files=$(find tests -type f | sort -V)

# Проверяем, есть ли файлы для тестирования
if [ -z "$test_files" ]; then
    echo "Ошибка: в папке tests не найдено файлов для тестирования"
    exit 1
fi

# Записываем заголовок в лог-файл
echo "==========================================" >> $OUTPUT_CONSOLE
echo "Количество выводимых элементов: $N" >> $OUTPUT_CONSOLE
echo "Параметры k: от $K_FROM до $K_TO" >> $OUTPUT_CONSOLE
echo "==========================================" >> $OUTPUT_CONSOLE
echo "" >> $OUTPUT_CONSOLE

# Счетчики для статистики
total_tests=0
successful_tests=0

# Запускаем тесты для каждого файла и каждого параметра k
for test_file in $test_files; do
    echo "Тестируем файл: $test_file"

    for ((k = K_FROM; k <= K_TO; k++)); do
        run_test "$test_file" $k
        total_tests=$((total_tests + 1))
    done
done

echo ""
echo "Тестирование завершено!"
echo "Результаты сохранены в: $LOG_FILE"

