class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.string :listener_name
      t.string :audio_filename
      t.text :transcription
      t.string :status

      t.timestamps
    end
  end
end
