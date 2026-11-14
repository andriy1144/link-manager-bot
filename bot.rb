# frozen_string_literal: true

# Telegram-бот «Менеджер посилань».
# Запуск: bundle exec ruby bot.rb

require 'bundler/setup'
require 'dotenv/load'
require 'json'
require 'logger'
require 'telegram/bot'

require_relative 'lib/link_storage'
require_relative 'lib/command_handler'

LOGGER = Logger.new($stdout)
RETRY_DELAY = 5 # секунд між спробами перепідключення

BOT_COMMANDS = [
  { command: 'save',   description: 'Зберегти посилання: /save <url> <тег>' },
  { command: 'get',    description: 'Посилання за тегом: /get <тег>' },
  { command: 'tags',   description: 'Усі мої теги' },
  { command: 'list',   description: 'Усі мої посилання' },
  { command: 'delete', description: 'Видалити за номером: /delete <id>' },
  { command: 'help',   description: 'Довідка' }
].freeze

token = ENV['TELEGRAM_BOT_TOKEN'].to_s.strip
if token.empty? || token.include?('your-token')
  abort 'Помилка: не задано TELEGRAM_BOT_TOKEN. Створіть файл .env за зразком .env.example'
end

storage = LinkStorage.new(ENV.fetch('DB_PATH', 'data/links.db'))
handler = CommandHandler.new(storage)

# Обробка одного повідомлення. Помилка в одному повідомленні
# не повинна зупиняти бота для інших користувачів.
def process_message(bot, message, handler)
  return unless message.is_a?(Telegram::Bot::Types::Message)

  chat_id = message.chat.id
  user_id = message.from&.id || chat_id
  LOGGER.info("user=#{user_id} text=#{message.text.inspect}")

  reply =
    if message.text.nil?
      'Надішліть, будь ласка, текстову команду. Список: /help'
    else
      begin
        handler.handle(user_id, message.from&.first_name, message.text)
      rescue SQLite3::Exception => e
        LOGGER.error("Помилка бази даних: #{e.class}: #{e.message}")
        '⚠️ Помилка бази даних. Спробуйте ще раз пізніше.'
      rescue StandardError => e
        LOGGER.error("Непередбачена помилка: #{e.class}: #{e.message}")
        '⚠️ Сталася непередбачена помилка. Спробуйте ще раз.'
      end
    end

  bot.api.send_message(chat_id: chat_id, text: reply, disable_web_page_preview: true)
rescue Telegram::Bot::Exceptions::ResponseError => e
  # Напр. користувач заблокував бота — просто логуємо й йдемо далі
  LOGGER.error("Telegram API відхилив відправку: #{e.message}")
end

# Зовнішній цикл: якщо зник інтернет або Telegram тимчасово недоступний,
# бот чекає кілька секунд і підключається знову.
loop do
  Telegram::Bot::Client.run(token) do |bot|
    LOGGER.info('Бот запущено. Очікую повідомлення... (Ctrl+C — зупинити)')
    begin
      bot.api.set_my_commands(commands: BOT_COMMANDS.to_json)
    rescue StandardError => e
      LOGGER.warn("Не вдалося встановити меню команд: #{e.message}")
    end

    bot.listen { |message| process_message(bot, message, handler) }
  end
rescue Interrupt
  LOGGER.info('Зупинка бота (Ctrl+C).')
  storage.close
  exit
rescue Telegram::Bot::Exceptions::ResponseError => e
  if e.message.include?('401')
    abort 'Помилка 401: токен недійсний. Перевірте TELEGRAM_BOT_TOKEN у файлі .env'
  end

  LOGGER.error("Помилка Telegram API: #{e.message}. Повтор через #{RETRY_DELAY} с.")
  sleep RETRY_DELAY
rescue Faraday::Error, SocketError, Timeout::Error, SystemCallError => e
  LOGGER.error("Проблема з мережею: #{e.class}: #{e.message}. Повтор через #{RETRY_DELAY} с.")
  sleep RETRY_DELAY
end
