require "test_helper"

class ActiveStorageBlobPreviewableTest < ActiveSupport::TestCase
  test "small files are previewable" do
    blob = ActiveStorage::Blob.new(filename: "test.mp4", content_type: "video/mp4", byte_size: 1024 * 1024, key: "test", checksum: "abc")
    assert blob.previewable?
  end

  test "large files are not previewable" do
    blob = ActiveStorage::Blob.new(filename: "test.mp4", content_type: "video/mp4", byte_size: ActiveStorageBlobPreviewable::MAX_PREVIEWABLE_SIZE + 1, key: "test", checksum: "abc")
    assert_not blob.previewable?
  end
end
