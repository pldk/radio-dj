OpenAI.configure do |config|
  config.access_token = ENV["OPENAI_API_KEY"] || raise("OPENAI_API_KEY is not set")
end