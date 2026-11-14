# frozen_string_literal: true

require 'uri'

# Уся логіка команд бота. Клас НЕ залежить від Telegram:
# отримує id користувача та текст, повертає текст відповіді.
# Завдяки цьому його легко тестувати без токена й інтернету.
class CommandHandler
  DEFAULT_TAG = 'untagged'
  MAX_TAG_LENGTH = 32
  MAX_TAGS = 5
  MAX_URL_LENGTH = 2000

  HELP = <<~TEXT
    📚 Менеджер посилань — зберігаю корисні посилання за тегами.

    Команди:
    /save <url> <тег> — зберегти посилання (можна кілька тегів через пробіл)
    /get <тег> — показати посилання за тегом
    /tags — усі ваші теги
    /list — усі збережені посилання
    /delete <id> — видалити посилання за номером
    /help — ця довідка

    Приклад:
    /save https://ruby-lang.org ruby docs
    /get ruby
  TEXT

  def initialize(storage)
    @storage = storage
  end

  # Повертає текст відповіді або nil, якщо повідомлення — не команда.
  def handle(user_id, first_name, text)
    text = text.to_s.strip
    return not_a_command unless text.start_with?('/')

    command, *args = text.split(/\s+/)
    command = command.sub(%r{\A/}, '').sub(/@.*\z/, '').downcase

    case command
    when 'start'  then start(first_name)
    when 'help'   then HELP
    when 'save'   then save(user_id, args)
    when 'get'    then get(user_id, args)
    when 'tags'   then tags(user_id)
    when 'list'   then list(user_id)
    when 'delete' then delete(user_id, args)
    else "Невідома команда /#{command}. Список команд: /help"
    end
  end

  # --- допоміжні (public для тестів) ---

  # Нормалізує й перевіряє URL. Повертає рядок або nil, якщо URL некоректний.
  def self.normalize_url(raw)
    url = raw.to_s.strip
    return nil if url.empty? || url.length > MAX_URL_LENGTH

    url = "https://#{url}" unless url.match?(%r{\A[a-z][a-z0-9+.\-]*://}i)
    uri = URI.parse(url)
    return nil unless %w[http https].include?(uri.scheme&.downcase)
    return nil if uri.host.nil? || !uri.host.include?('.')

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end

  # Нормалізує тег: нижній регістр, без #, лише безпечні символи.
  def self.normalize_tag(raw)
    tag = raw.to_s.downcase.delete_prefix('#').gsub(/[^[:alnum:]_\-]/, '')
    tag.empty? ? nil : tag[0, MAX_TAG_LENGTH]
  end

  private

  def not_a_command
    'Я розумію лише команди 🙂 Напишіть /help, щоб побачити, що я вмію.'
  end

  def start(first_name)
    name = first_name.to_s.strip
    greeting = name.empty? ? 'Привіт!' : "Привіт, #{name}!"
    "#{greeting} 👋\n\n#{HELP}"
  end

  def save(user_id, args)
    if args.empty?
      return "Вкажіть посилання та тег.\nПриклад: /save https://ruby-lang.org ruby"
    end

    url = self.class.normalize_url(args.first)
    return "❌ «#{args.first}» не схоже на коректне посилання.\nПриклад: /save https://example.com тег" unless url

    raw_tags = args.drop(1).flat_map { |a| a.split(',') }
    tags = raw_tags.filter_map { |t| self.class.normalize_tag(t) }.uniq
    return "Не більше #{MAX_TAGS} тегів за раз." if tags.size > MAX_TAGS

    tags = [DEFAULT_TAG] if tags.empty?
    result = @storage.save(user_id, url, tags)
    verb = result[:created] ? 'збережено' : 'вже було у списку, теги оновлено'
    "✅ Посилання #{verb} (№#{result[:id]}).\n#{url}\nТеги: #{tags.map { |t| "##{t}" }.join(' ')}"
  end

  def get(user_id, args)
    return "Вкажіть тег.\nПриклад: /get ruby" if args.empty?

    tag = self.class.normalize_tag(args.first)
    return '❌ Некоректний тег.' unless tag

    links = @storage.by_tag(user_id, tag)
    return "За тегом #{tag} нічого не знайдено. Подивіться /tags" if links.empty?

    "🔖 Посилання за тегом ##{tag}:\n\n#{format_links(links)}"
  end

  def tags(user_id)
    list = @storage.tags(user_id)
    return 'У вас ще немає тегів. Збережіть посилання: /save <url> <тег>' if list.empty?

    lines = list.map { |tag, count| "##{tag} — #{count}" }
    "🏷 Ваші теги:\n\n#{lines.join("\n")}"
  end

  def list(user_id)
    links = @storage.all(user_id)
    return 'Список порожній. Збережіть перше посилання: /save <url> <тег>' if links.empty?

    total = @storage.count(user_id)
    footer = total > links.size ? "\n\nПоказано #{links.size} із #{total} (найновіші)." : ''
    "📚 Ваші посилання:\n\n#{format_links(links)}#{footer}"
  end

  def delete(user_id, args)
    id = args.first.to_s
    return "Вкажіть номер посилання.\nПриклад: /delete 3" unless id.match?(/\A\d+\z/)

    if @storage.delete(user_id, id.to_i)
      "🗑 Посилання №#{id} видалено."
    else
      "Посилання №#{id} не знайдено."
    end
  end

  def format_links(links)
    links.map do |l|
      tag_line = l[:tags].empty? ? '' : "\n   #{l[:tags].split(', ').map { |t| "##{t}" }.join(' ')}"
      "№#{l[:id]} #{l[:url]}#{tag_line}"
    end.join("\n\n")
  end
end
