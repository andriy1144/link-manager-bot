# frozen_string_literal: true

require 'sqlite3'
require 'fileutils'

# Шар зберігання даних: посилання та їхні теги в базі SQLite.
#
# Схема (зв'язок «багато-до-багатьох» спрощено до двох таблиць):
#   links      — унікальні посилання користувача
#   link_tags  — теги, прив'язані до посилання (одне посилання — кілька тегів)
class LinkStorage
  SCHEMA = <<~SQL
    CREATE TABLE IF NOT EXISTS links (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id    INTEGER NOT NULL,
      url        TEXT    NOT NULL,
      created_at TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP,
      UNIQUE (user_id, url)
    );

    CREATE TABLE IF NOT EXISTS link_tags (
      link_id INTEGER NOT NULL REFERENCES links(id) ON DELETE CASCADE,
      tag     TEXT    NOT NULL,
      PRIMARY KEY (link_id, tag)
    );

    CREATE INDEX IF NOT EXISTS idx_link_tags_tag ON link_tags(tag);
  SQL

  # Підзапит, що збирає теги посилання в рядок «tag1, tag2»
  TAGS_SUBQUERY = <<~SQL.strip
    (SELECT GROUP_CONCAT(tag, ', ')
       FROM (SELECT tag FROM link_tags WHERE link_id = l.id ORDER BY tag)) AS tags
  SQL

  def initialize(path = 'data/links.db')
    FileUtils.mkdir_p(File.dirname(path)) unless path == ':memory:'
    @db = SQLite3::Database.new(path)
    @db.results_as_hash = true
    @db.execute('PRAGMA foreign_keys = ON')
    @db.execute_batch(SCHEMA)
  end

  # Зберігає посилання з тегами.
  # Якщо таке посилання в користувача вже є — лише додає нові теги.
  # Повертає { id:, created: true/false }
  def save(user_id, url, tags)
    @db.transaction do
      @db.execute('INSERT OR IGNORE INTO links (user_id, url) VALUES (?, ?)', [user_id, url])
      created = @db.changes.positive?
      link_id = @db.get_first_value('SELECT id FROM links WHERE user_id = ? AND url = ?', [user_id, url])
      tags.each do |tag|
        @db.execute('INSERT OR IGNORE INTO link_tags (link_id, tag) VALUES (?, ?)', [link_id, tag])
      end
      { id: link_id, created: created }
    end
  end

  # Посилання користувача за тегом (найновіші першими)
  def by_tag(user_id, tag, limit: 30)
    rows(<<~SQL, [user_id, tag, limit])
      SELECT l.id, l.url, #{TAGS_SUBQUERY}
        FROM links l
       WHERE l.user_id = ?
         AND l.id IN (SELECT link_id FROM link_tags WHERE tag = ?)
       ORDER BY l.id DESC
       LIMIT ?
    SQL
  end

  # Усі посилання користувача (найновіші першими)
  def all(user_id, limit: 30)
    rows(<<~SQL, [user_id, limit])
      SELECT l.id, l.url, #{TAGS_SUBQUERY}
        FROM links l
       WHERE l.user_id = ?
       ORDER BY l.id DESC
       LIMIT ?
    SQL
  end

  # Список тегів користувача з кількістю посилань: [[tag, count], ...]
  def tags(user_id)
    @db.execute(<<~SQL, [user_id]).map { |r| [r['tag'], r['cnt']] }
      SELECT t.tag AS tag, COUNT(*) AS cnt
        FROM link_tags t
        JOIN links l ON l.id = t.link_id
       WHERE l.user_id = ?
       GROUP BY t.tag
       ORDER BY cnt DESC, t.tag
    SQL
  end

  # Видаляє посилання за id (лише якщо воно належить користувачу)
  def delete(user_id, link_id)
    @db.execute('DELETE FROM links WHERE id = ? AND user_id = ?', [link_id, user_id])
    @db.changes.positive?
  end

  def count(user_id)
    @db.get_first_value('SELECT COUNT(*) FROM links WHERE user_id = ?', [user_id])
  end

  def close
    @db.close
  end

  private

  def rows(sql, params)
    @db.execute(sql, params).map do |r|
      { id: r['id'], url: r['url'], tags: r['tags'].to_s }
    end
  end
end
