# app/support/ai_locale.rb
module AiLocale
  LANGUAGE_INSTRUCTIONS = {
    "pt-BR" => "Respond in Brazilian Portuguese (PT-BR)."
  }.freeze

  # Returns nil for English — the model defaults to English, no instruction needed.
  # Callers must guard before appending to prompts:
  #   instruction = AiLocale.instruction_for(locale)
  #   system_prompt += "\n#{instruction}" if instruction
  def self.instruction_for(locale)
    LANGUAGE_INSTRUCTIONS[locale.to_s]
  end
end
