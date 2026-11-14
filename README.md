# 📚 Link Manager Bot — Telegram-бот «Менеджер посилань»

Telegram-бот на Ruby, який дозволяє зберігати корисні посилання з тегами та швидко знаходити їх за тегом.
Дані зберігаються в локальній базі **SQLite**. Кожен користувач бачить лише власні посилання.

Практична робота №7 з дисципліни «Основні принципи роботи та можливості ШІ».

## Можливості

- збереження посилання з одним або кількома тегами;
- пошук посилань за тегом;
- перегляд усіх тегів і всіх посилань;
- видалення посилання;
- перевірка коректності URL, нормалізація тегів, обробка помилок.

## Технології

| Компонент | Призначення |
|-----------|-------------|
| Ruby 3.0+ | мова програмування |
| [telegram-bot-ruby](https://github.com/atipugin/telegram-bot-ruby) | робота з Telegram Bot API |
| [sqlite3](https://github.com/sparklemotion/sqlite3-ruby) | зберігання даних у файлі `links.db` |
| [dotenv](https://github.com/bkeepers/dotenv) | завантаження токена з файлу `.env` |
| Minitest | автоматичні тести |

## Структура проєкту

```
link_manager_bot/
├── bot.rb                    # точка входу: підключення до Telegram, цикл прослуховування
├── lib/
│   ├── command_handler.rb    # логіка команд (не залежить від Telegram)
│   └── link_storage.rb       # робота з базою SQLite
├── test/                     # тести (Minitest)
├── data/                     # тут створюється links.db
├── Gemfile                   # залежності
├── .env.example              # зразок файлу з токеном
└── README.md
```

## Встановлення

1. Встановіть Ruby 3.0 або новіший (`ruby -v`) та Bundler (`gem install bundler`).
2. Склонуйте репозиторій і встановіть залежності:
   ```bash
   git clone https://github.com/<ваш-логін>/link-manager-bot.git
   cd link-manager-bot
   bundle install
   ```
3. Отримайте токен у [@BotFather](https://t.me/BotFather) командою `/newbot`.
4. Створіть файл `.env` за зразком і вставте токен:
   ```bash
   cp .env.example .env      # Windows: copy .env.example .env
   ```
   ```
   TELEGRAM_BOT_TOKEN=123456789:ABC-ваш-токен
   ```
5. Запустіть бота:
   ```bash
   bundle exec ruby bot.rb
   ```

Зупинити бота: `Ctrl+C`.

## Використання

| Команда | Опис | Приклад |
|---------|------|---------|
| `/start` | привітання та довідка | `/start` |
| `/save <url> <тег> [тег…]` | зберегти посилання | `/save https://ruby-lang.org ruby docs` |
| `/get <тег>` | показати посилання за тегом | `/get ruby` |
| `/tags` | усі ваші теги з кількістю посилань | `/tags` |
| `/list` | усі збережені посилання | `/list` |
| `/delete <id>` | видалити посилання за номером | `/delete 3` |
| `/help` | довідка | `/help` |

Примітки:
- до 5 тегів за одну команду; якщо тег не вказано, використовується `untagged`;
- теги нечутливі до регістру (`Ruby` = `ruby`), символ `#` на початку ігнорується;
- якщо посилання вже збережене, до нього додаються лише нові теги;
- посилання без схеми (`example.com`) автоматично отримують `https://`.

## Тести

```bash
ruby -Ilib test/command_handler_test.rb   # логіка команд (без БД)
ruby -Ilib test/link_storage_test.rb      # SQLite (потрібен gem sqlite3)
```

## Посилання на бота

Telegram: https://t.me/<нікнейм_вашого_бота> *(бот працює лише під час запуску `bot.rb` на комп'ютері автора)*
