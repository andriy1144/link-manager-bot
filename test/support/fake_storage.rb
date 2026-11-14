# frozen_string_literal: true

# Проста in-memory реалізація інтерфейсу LinkStorage для тестів.
class FakeStorage
  def initialize
    @links = [] # { id:, user_id:, url:, tags: [] }
    @next_id = 1
  end

  def save(user_id, url, tags)
    link = @links.find { |l| l[:user_id] == user_id && l[:url] == url }
    created = link.nil?
    unless link
      link = { id: @next_id, user_id: user_id, url: url, tags: [] }
      @next_id += 1
      @links << link
    end
    link[:tags] |= tags
    { id: link[:id], created: created }
  end

  def by_tag(user_id, tag, limit: 30)
    mine(user_id).select { |l| l[:tags].include?(tag) }.reverse.first(limit).map { |l| view(l) }
  end

  def all(user_id, limit: 30)
    mine(user_id).reverse.first(limit).map { |l| view(l) }
  end

  def tags(user_id)
    mine(user_id).flat_map { |l| l[:tags] }.tally.sort_by { |t, c| [-c, t] }
  end

  def delete(user_id, id)
    before = @links.size
    @links.reject! { |l| l[:id] == id && l[:user_id] == user_id }
    @links.size < before
  end

  def count(user_id) = mine(user_id).size

  private

  def mine(user_id) = @links.select { |l| l[:user_id] == user_id }
  def view(l) = { id: l[:id], url: l[:url], tags: l[:tags].sort.join(', ') }
end
