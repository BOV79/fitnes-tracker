#!/bin/bash

echo "🚀 Настройка Fitness Tracker v2..."

# Проверяем доступные версии Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    PYTHON_CMD="python3"
    echo "✅ Используем python3 (версия: $PYTHON_VERSION)"
else
    echo "❌ Python не найден"
    exit 1
fi

# Создание виртуального окружения
if [ -d "venv" ]; then
    echo "⚠️  Виртуальное окружение уже существует"
    echo "Удаляем старое окружение..."
    rm -rf venv
fi

echo "📦 Создаем виртуальное окружение..."
$PYTHON_CMD -m venv venv
echo "✅ Виртуальное окружение создано"

# Активация и установка зависимостей
echo "📦 Активируем окружение и устанавливаем зависимости..."
source venv/bin/activate

pip install --upgrade pip
echo "✅ pip обновлен"

pip install pip-tools
echo "✅ pip-tools установлен"

echo "📦 Компилируем зависимости..."
pip-compile requirements.in

echo "📦 Устанавливаем зависимости..."
pip install -r requirements.txt

echo "✅ Зависимости установлены"

# Git инициализация
if [ ! -d ".git" ]; then
    git init
    echo "✅ Git репозиторий инициализирован"
fi

echo ""
echo "🎉 Настройка завершена!"
echo ""
echo "Следующие шаги:"
echo "1. source venv/bin/activate"
echo "2. uvicorn app.main:app --reload"
echo "3. open http://localhost:8000"
echo ""
echo "🧪 Для тестирования:"
echo "pytest tests/ -v"
