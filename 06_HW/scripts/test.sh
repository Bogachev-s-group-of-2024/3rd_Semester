#!/usr/bin/env bash

set -u -o pipefail

# Fixed R value
R_VAL=8

SCRIPT_DIR=$(pwd)
DEFAULT_TESTS_DIR="${SCRIPT_DIR}/tests"
CUSTOM_TESTS_DIR=""
LOGS_DIR="${SCRIPT_DIR}/logs"

usage() {
  echo "Usage: $0 [--tests-dir PATH] [N]"
  echo "  --tests-dir PATH: путь к папке с тестами (приоритетнее переменной TESTS_DIR)"
  echo "  TESTS_DIR: переменная окружения с путем к папке тестов (по умолчанию ./tests)"
  echo "  N: номер программы 1..5 (запускает только ./a0N.out)"
}

# Optional: parse args --tests-dir and N
SELECT_N=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tests-dir)
      if [[ $# -lt 2 ]]; then
        echo "Ошибка: для --tests-dir нужен PATH"
        usage
        exit 1
      fi
      CUSTOM_TESTS_DIR="$2"
      shift 2
      ;;
    1|2|3|4|5)
      if [[ -n "${SELECT_N}" ]]; then
        echo "Ошибка: номер программы уже задан"
        usage
        exit 1
      fi
      SELECT_N="$1"
      shift 1
      ;;
    *)
      echo "Неизвестный аргумент: $1"
      usage
      exit 1
      ;;
  esac
done

# Resolve tests dir with priority: --tests-dir > env TESTS_DIR > default
TESTS_DIR="${CUSTOM_TESTS_DIR:-${TESTS_DIR:-${DEFAULT_TESTS_DIR}}}"

if [[ ! -d "${TESTS_DIR}" ]]; then
  echo "Не найдена папка tests: ${TESTS_DIR}"
  exit 1
fi

mkdir -p "${LOGS_DIR}"

realpath_compat() {
  # realpath may not exist in minimal envs; fallback
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
  else
    echo "$(cd "$(dirname -- "$1")" && pwd -P)/$(basename -- "$1")"
  fi
}

extract_nv_number() {
  # From filename like nv_12345_something.txt -> 12345
  # Prints number or empty
  local base
  base=$(basename -- "$1")
  if [[ ${base} =~ ^nv_([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}

collect_tests() {
  # Echo absolute paths for all *.txt tests in tests dir
  shopt -s nullglob
  local f
  for f in "${TESTS_DIR}"/*.txt; do
    realpath_compat "$f"
  done
  shopt -u nullglob
}

sort_nv_tests_by_number() {
  # Input: list of absolute file paths (nv_*.txt)
  # Output: sorted ascending by leading nv_ number; lex tie-breaker
  while IFS= read -r path; do
    base=$(basename -- "$path")
    if [[ $base =~ ^nv_([0-9]+) ]]; then
      num=${BASH_REMATCH[1]}
    else
      num=999999999
    fi
    printf "%012d\t%s\n" "$num" "$path"
  done |
  sort -t $'\t' -k1,1n -k2,2 |
  cut -f2-
}

run_for_program() {
  local N="$1"
  local prog="${SCRIPT_DIR}/a0${N}.out"

  if [[ ! -x "${prog}" ]]; then
    echo "Программа не найдена или не исполняема: ${prog} — пропуск"
    return
  fi

  local ts
  ts=$(date +%F_%H-%M-%S)
  local log_file="${LOGS_DIR}/a0${N}.out_${ts}.log"

  # Collect tests
  mapfile -t all_tests < <(collect_tests)

  # Partition tests
  nv_tests=()
  other_tests=()
  for t in "${all_tests[@]}"; do
    base=$(basename -- "$t")
    if [[ ${base} == nv_*.txt ]]; then
      nv_tests+=("$t")
    else
      other_tests+=("$t")
    fi
  done

  # Filter nv tests for first 3 programs: number <= 100000
  nv_selected=()
  if [[ "$N" =~ ^[1-3]$ ]]; then
    # Keep only nv_* with numeric part <= 100000
    for t in "${nv_tests[@]}"; do
      num=$(extract_nv_number "$t")
      if [[ -n "$num" && "$num" -le 100000 ]]; then
        nv_selected+=("$t")
      fi
    done
    # Для a01-a03: включаем также прочие (не nv) тесты; nv > 100000 исключаем
    include_other=true
  else
    # a04-a05: include all nv_* tests
    nv_selected=("${nv_tests[@]}")
    include_other=true
  fi

  # Sort nv_selected by numeric nv_ prefix
  mapfile -t nv_sorted < <(printf '%s\n' "${nv_selected[@]}" | sort_nv_tests_by_number)

  # For a04-a05, append other tests after nv tests (as requested)
  final_tests=("${nv_sorted[@]}")
  if [[ "$include_other" == true ]]; then
    # Keep other tests in lex order
    if [[ ${#other_tests[@]} -gt 0 ]]; then
      mapfile -t others_sorted < <(printf '%s\n' "${other_tests[@]}" | sort)
      final_tests+=("${others_sorted[@]}")
    fi
  fi

  # Run
  {
    echo "Program: ${prog}"
    echo
  } >>"${log_file}"

  for file in "${final_tests[@]}"; do
    base_file=$(basename -- "${file}")
    echo "--- R = ${R_VAL} FILE = ${base_file} ---" | tee -a "${log_file}"
    # Run from tests dir, pass relative filename; use stdbuf if available to preserve output order
    if command -v stdbuf >/dev/null 2>&1; then
      ( cd "${TESTS_DIR}" && stdbuf -oL -eL "${prog}" "${R_VAL}" "${base_file}" ) >>"${log_file}" 2>&1 || true
    else
      ( cd "${TESTS_DIR}" && "${prog}" "${R_VAL}" "${base_file}" ) >>"${log_file}" 2>&1 || true
    fi
    echo >>"${log_file}"
  done

  {
    echo
  } >>"${log_file}"

  echo "Лог сохранён: ${log_file}"
}

main() {
  if [[ -n "${SELECT_N}" ]]; then
    run_for_program "${SELECT_N}"
    return
  fi

  # No selection: iterate over all existing from 1..5
  for n in 1 2 3 4 5; do
    run_for_program "$n"
  done
}

main "$@"


