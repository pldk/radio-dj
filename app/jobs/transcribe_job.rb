class TranscribeJob < ApplicationJob
  cattr_accessor :client_class, default: OpenAI::Client
  queue_as :default

  def perform(message_id)
    msg = Message.find(message_id)
    audio_path = AudioStorage.path_for_message_id(message_id)
    raise ArgumentError, "audio file not found for message #{message_id}" unless audio_path

    client   = self.class.client_class.new
    response = client.audio.transcribe(
      parameters: { model: "whisper-1", file: File.open(audio_path, "rb") }
    )

    msg.update!(transcription: response["text"], status: "done")
    MessagesController.broadcast(msg)
  rescue => e
    msg&.update!(status: "error")
    Rails.logger.error("TranscribeJob failed: #{e.class} — #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
  end
end
