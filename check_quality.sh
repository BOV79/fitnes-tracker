#!/bin/bash
cd /Users/olegbudakov/fitness-tracker-v2
source venv/bin/activate

echo "🔍 Проверка форматирования кода с Black..."
black --check .
echo "Black status: $?"
echo ""

echo "🔍 Проверка качества кода с Flake8..."
flake8 .
echo "Flake8 status: $?"
echo ""

echo "🔍 Проверка типизации с MyPy..."
mypy app/
echo "MyPy status: $?"
echo ""

echo "✅ Проверка качества кода завершена"
