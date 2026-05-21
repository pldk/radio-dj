module AudioStorage
  DIR = Rails.root.join("tmp", "audio").freeze

  def self.path_for_message_id(message_id)
    id_str = message_id.to_s
    name = Dir.children(DIR).find do |filename|
      base, dot, ext = filename.partition(".")
      base == id_str && dot == "." && ext.present?
    end
    DIR.join(name) if name
  end
end
