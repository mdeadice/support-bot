FROM python:3.11-slim

WORKDIR /app

# Установка зависимостей
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копирование файлов бота (из подпапки bot/)
COPY bot/ .

# Запуск бота
CMD ["python", "bot.py"]

