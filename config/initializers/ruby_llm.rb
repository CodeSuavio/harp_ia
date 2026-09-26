RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY")

  # Enable the association-based Rails API
  config.use_new_acts_as = true

end
