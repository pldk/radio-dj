class Message < ApplicationRecord
  validates :listener_name, presence: true

  def as_event
    as_json(only: %i[id listener_name transcription status created_at])
  end
end
