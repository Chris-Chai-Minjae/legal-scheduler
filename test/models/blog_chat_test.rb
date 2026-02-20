require "test_helper"

class BlogChatTest < ActiveSupport::TestCase
  test "valid blog chat" do
    chat = BlogChat.new(
      user: users(:one),
      role: "user",
      content: "더 쉽게 작성해주세요"
    )
    assert chat.valid?
  end

  test "requires role" do
    chat = BlogChat.new(user: users(:one), content: "test")
    assert_not chat.valid?
  end

  test "requires content" do
    chat = BlogChat.new(user: users(:one), role: "user")
    assert_not chat.valid?
  end

  test "validates role inclusion" do
    chat = BlogChat.new(user: users(:one), role: "admin", content: "test")
    assert_not chat.valid?
  end

  test "blog_post is optional" do
    chat = BlogChat.new(user: users(:one), role: "user", content: "test")
    assert chat.valid?
  end
end
