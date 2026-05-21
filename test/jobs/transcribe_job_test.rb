require "test_helper"

class TranscribeJobTest < ActiveJob::TestCase
  setup do
    @msg = Message.create!(listener_name: "Jonas", audio_filename: "pending", status: "pending")
    @msg.update!(audio_filename: "#{@msg.id}.wav")
    dest = AudioStorage::DIR.join("#{@msg.id}.wav")
    FileUtils.mkdir_p(dest.dirname)
    FileUtils.cp(Rails.root.join("test", "fixtures", "files", "test.wav"), dest)
  end

  teardown do
    TranscribeJob.client_class = OpenAI::Client
  end

  test "updates message to done with transcription on success" do
    TranscribeJob.client_class = fake_client_class("Bonjour DJ !")
    TranscribeJob.perform_now(@msg.id)

    @msg.reload
    assert_equal "done",         @msg.status
    assert_equal "Bonjour DJ !", @msg.transcription
  end

  test "updates message to error on API failure" do
    TranscribeJob.client_class = Class.new { def audio = raise("boom") }
    TranscribeJob.perform_now(@msg.id)

    @msg.reload
    assert_equal "error", @msg.status
  end

  private

  def fake_client_class(text)
    Class.new do
      define_method(:audio) do
        Object.new.tap { |o| o.define_singleton_method(:transcribe) { |**_| { "text" => text } } }
      end
    end
  end
end
