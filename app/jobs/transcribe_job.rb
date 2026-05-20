class TranscribeJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    msg        = Message.find(message_id)
    audio_path = Rails.root.join("tmp", "audio", msg.audio_filename)

    client   = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
    response = client.audio.transcribe(
      parameters: { model: "whisper-1", file: File.open(audio_path, "rb") }
    )

    msg.update!(transcription: response["text"], status: "done")
    MessagesController.broadcast(msg)
  rescue => e
    msg&.update!(status: "error")
    Rails.logger.error("TranscribeJob failed: #{e.message}")
  end
end