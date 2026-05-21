require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "valid with listener_name and audio_filename" do
    msg = Message.new(listener_name: "Jonas", audio_filename: "test.wav", status: "pending")
    assert msg.valid?
  end

  test "invalid without listener_name" do
    msg = Message.new(audio_filename: "test.wav", status: "pending")
    assert_not msg.valid?
    assert_includes msg.errors[:listener_name], "can't be blank"
  end

  test "as_event returns expected keys" do
    msg = Message.create!(listener_name: "Laura", audio_filename: "x.wav", status: "pending")
    event = msg.as_event
    assert_equal %w[id listener_name transcription status created_at].sort, event.keys.map(&:to_s).sort
  end

  test "audio_file_path returns path when file exists in storage" do
    FileUtils.mkdir_p(AudioStorage::DIR)
    msg = Message.create!(listener_name: "Laura", audio_filename: "pending", status: "pending")
    msg.update!(audio_filename: "#{msg.id}.wav")
    FileUtils.touch(AudioStorage::DIR.join("#{msg.id}.wav"))

    assert_equal AudioStorage::DIR.join("#{msg.id}.wav"), msg.audio_file_path
  ensure
    FileUtils.rm_f(AudioStorage::DIR.join("#{msg.id}.wav")) if defined?(msg) && msg
  end

  test "audio_filename rejects path separators" do
    msg = Message.new(listener_name: "Laura", audio_filename: "../../../etc/passwd", status: "pending")

    assert_not msg.valid?
  end
end
