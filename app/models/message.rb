class Message < ApplicationRecord
  validates :listener_name, presence: true
  validates :audio_filename, presence: true, format: { without: %r{[/\\]} }

  def audio_file_path
    AudioStorage.path_for_message_id(id)
  end

  def as_event
    as_json(only: %i[id listener_name transcription status created_at])
  end
end
