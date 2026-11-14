# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/command_handler'
require_relative 'support/fake_storage'

class CommandHandlerTest < Minitest::Test
  def setup
    @h = CommandHandler.new(FakeStorage.new)
  end

  def test_start_greets_by_name
    assert_includes @h.handle(1, 'Андрій', '/start'), 'Привіт, Андрій!'
  end

  def test_plain_text_is_not_a_command
    assert_includes @h.handle(1, 'A', 'привіт'), '/help'
  end

  def test_unknown_command
    assert_includes @h.handle(1, 'A', '/foo'), 'Невідома команда'
  end

  def test_command_with_bot_suffix
    assert_includes @h.handle(1, 'A', '/help@my_link_bot'), '/save'
  end

  def test_save_and_get
    reply = @h.handle(1, 'A', '/save https://ruby-lang.org ruby docs')
    assert_includes reply, 'збережено'
    assert_includes @h.handle(1, 'A', '/get ruby'), 'https://ruby-lang.org'
    assert_includes @h.handle(1, 'A', '/get docs'), 'https://ruby-lang.org'
  end

  def test_save_without_scheme_adds_https
    @h.handle(1, 'A', '/save example.com web')
    assert_includes @h.handle(1, 'A', '/get web'), 'https://example.com'
  end

  def test_save_without_tag_uses_default
    @h.handle(1, 'A', '/save https://example.com')
    assert_includes @h.handle(1, 'A', '/get untagged'), 'example.com'
  end

  def test_save_invalid_url
    assert_includes @h.handle(1, 'A', '/save це_не_посилання tag'), 'не схоже на коректне'
    assert_includes @h.handle(1, 'A', '/save ftp://example.com tag'), 'не схоже на коректне'
  end

  def test_save_without_args
    assert_includes @h.handle(1, 'A', '/save'), 'Вкажіть посилання'
  end

  def test_too_many_tags
    assert_includes @h.handle(1, 'A', '/save https://a.com 1 2 3 4 5 6'), 'Не більше'
  end

  def test_duplicate_url_merges_tags
    @h.handle(1, 'A', '/save https://a.com one')
    reply = @h.handle(1, 'A', '/save https://a.com two')
    assert_includes reply, 'вже було'
    assert_includes @h.handle(1, 'A', '/get two'), 'https://a.com'
  end

  def test_tags_are_normalized
    @h.handle(1, 'A', '/save https://a.com #Ruby,RUBY')
    assert_includes @h.handle(1, 'A', '/get RUBY'), 'https://a.com'
    assert_includes @h.handle(1, 'A', '/tags'), '#ruby — 1'
  end

  def test_get_unknown_tag
    assert_includes @h.handle(1, 'A', '/get nothing'), 'нічого не знайдено'
  end

  def test_get_without_args
    assert_includes @h.handle(1, 'A', '/get'), 'Вкажіть тег'
  end

  def test_users_are_isolated
    @h.handle(1, 'A', '/save https://secret.com private')
    assert_includes @h.handle(2, 'B', '/get private'), 'нічого не знайдено'
    assert_includes @h.handle(2, 'B', '/list'), 'порожній'
  end

  def test_list_and_tags_empty
    assert_includes @h.handle(1, 'A', '/list'), 'порожній'
    assert_includes @h.handle(1, 'A', '/tags'), 'ще немає тегів'
  end

  def test_delete
    @h.handle(1, 'A', '/save https://a.com x')
    assert_includes @h.handle(1, 'A', '/delete 1'), 'видалено'
    assert_includes @h.handle(1, 'A', '/delete 1'), 'не знайдено'
    assert_includes @h.handle(1, 'A', '/delete abc'), 'Вкажіть номер'
  end

  def test_cannot_delete_foreign_link
    @h.handle(1, 'A', '/save https://a.com x')
    assert_includes @h.handle(2, 'B', '/delete 1'), 'не знайдено'
    assert_includes @h.handle(1, 'A', '/list'), 'https://a.com'
  end

  def test_normalize_url
    assert_equal 'https://a.com/x?y=1', CommandHandler.normalize_url('a.com/x?y=1')
    assert_nil CommandHandler.normalize_url('javascript:alert(1)')
    assert_nil CommandHandler.normalize_url('http://localhost')
    assert_nil CommandHandler.normalize_url('')
  end
end
