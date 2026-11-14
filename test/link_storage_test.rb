# frozen_string_literal: true

require 'minitest/autorun'

begin
  require_relative '../lib/link_storage'
rescue LoadError
  warn 'gem sqlite3 не встановлено — тести LinkStorage пропущено (виконайте bundle install)'
  return
end

class LinkStorageTest < Minitest::Test
  def setup
    @s = LinkStorage.new(':memory:')
  end

  def test_save_new_and_duplicate
    first = @s.save(1, 'https://a.com', %w[ruby docs])
    assert first[:created]
    second = @s.save(1, 'https://a.com', %w[extra])
    refute second[:created]
    assert_equal first[:id], second[:id]
    assert_equal 'docs, extra, ruby', @s.all(1).first[:tags]
  end

  def test_by_tag
    @s.save(1, 'https://a.com', %w[ruby])
    @s.save(1, 'https://b.com', %w[python])
    assert_equal ['https://a.com'], @s.by_tag(1, 'ruby').map { |l| l[:url] }
  end

  def test_users_isolated
    @s.save(1, 'https://a.com', %w[ruby])
    assert_empty @s.by_tag(2, 'ruby')
    assert_equal 0, @s.count(2)
  end

  def test_tags_count
    @s.save(1, 'https://a.com', %w[ruby web])
    @s.save(1, 'https://b.com', %w[ruby])
    assert_equal [['ruby', 2], ['web', 1]], @s.tags(1)
  end

  def test_delete_cascades_tags
    id = @s.save(1, 'https://a.com', %w[ruby])[:id]
    refute @s.delete(2, id)
    assert @s.delete(1, id)
    assert_empty @s.tags(1)
  end
end
