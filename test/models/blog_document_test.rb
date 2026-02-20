require "test_helper"

class BlogDocumentTest < ActiveSupport::TestCase
  test "valid blog document" do
    doc = BlogDocument.new(
      user: users(:one),
      filename: "판결문.pdf",
      file_type: "pdf",
      file_size: 1024
    )
    assert doc.valid?
  end

  test "requires filename" do
    doc = BlogDocument.new(user: users(:one), file_type: "pdf", file_size: 100)
    assert_not doc.valid?
  end

  test "validates file_type inclusion" do
    doc = BlogDocument.new(user: users(:one), filename: "t", file_type: "exe", file_size: 100)
    assert_not doc.valid?
  end

  test "status enum" do
    doc = BlogDocument.new(user: users(:one), filename: "t", file_type: "pdf", file_size: 100)
    assert doc.pending?
  end
end
