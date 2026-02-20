require "test_helper"

class BlogPostTest < ActiveSupport::TestCase
  test "valid blog post" do
    post = BlogPost.new(
      user: users(:one),
      title: "테스트 블로그",
      prompt: "법률 블로그 작성해주세요",
      tone: :professional,
      length_setting: :medium
    )
    assert post.valid?
  end

  test "requires title" do
    post = BlogPost.new(prompt: "test", user: users(:one))
    assert_not post.valid?
    assert_includes post.errors[:title], "can't be blank"
  end

  test "requires prompt" do
    post = BlogPost.new(title: "test", user: users(:one))
    assert_not post.valid?
    assert_includes post.errors[:prompt], "can't be blank"
  end

  test "status enum" do
    post = BlogPost.new(user: users(:one), title: "t", prompt: "p")
    assert post.draft?
    post.status = :generating
    assert post.generating?
  end

  test "belongs to user" do
    assert_respond_to BlogPost.new, :user
  end

  test "has many blog_chats" do
    assert_respond_to BlogPost.new, :blog_chats
  end
end
