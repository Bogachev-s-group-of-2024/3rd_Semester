#!/bin/bash

# Папка с тестами
TEST_DIR="$1"

# Параметры по умолчанию
R="${2:-10}"

# Создаём папку для логов, если её нет
mkdir -p ./logs

# Текущее время для имени файлов лога
TS="$(date +"%Y-%m-%d_%H-%M-%S")"

for prog in ./a*.out; do
    # Если файлов нет — пропускаем
    [ -e "$prog" ] || continue

    # Вытащим только имя файла
    base=$(basename "$prog")

    # Лог для конкретной программы
    LOG="./logs/${base}_${TS}.log"

    echo "Лог: $LOG"

    # Тесты в обратном лексикографическом порядке
    for testname in $(ls -1 "$TEST_DIR" | sort -r); do
        test="$TEST_DIR/$testname"

        for ((m = 3; m < 8; m=m+1)); do
            line1="--- TEST = $test ---"
            line2="--- ./$base R=$R M=$m ---"

            # Печать и в лог, и в консоль
            echo "$line1" | tee -a "$LOG"
            echo "$line2" | tee -a "$LOG"

            "$prog" "$R" "$test" "$m" >> "$LOG" 2>&1
        done

        echo "" >> "$LOG"
    done
done

