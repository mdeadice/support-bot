# Инструкция по установке через GitHub

## Для установщика (вас)

1. Замените в `README.md` строку `https://github.com/ваш-username/support-bot.git` на URL вашего репозитория
2. Загрузите проект на GitHub
3. Другие пользователи смогут установить бота командой:

```bash
git clone https://github.com/ваш-username/support-bot.git
cd support-bot
```

Затем:
- **Windows**: `powershell -ExecutionPolicy Bypass -File install.ps1`
- **Linux/Mac**: `bash install.sh`

## Для пользователей

После клонирования репозитория просто запустите соответствующий установщик для вашей ОС.

