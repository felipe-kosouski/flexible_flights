# spec/support/ai_locale_spec.rb
require "rails_helper"

RSpec.describe AiLocale do
  describe ".instruction_for" do
    it "returns a Portuguese instruction for pt-BR" do
      expect(described_class.instruction_for("pt-BR")).to eq("Respond in Brazilian Portuguese (PT-BR).")
    end

    it "returns nil for en (model already defaults to English)" do
      expect(described_class.instruction_for("en")).to be_nil
    end

    it "returns nil for unknown locale" do
      expect(described_class.instruction_for("fr")).to be_nil
    end

    it "accepts symbols" do
      expect(described_class.instruction_for(:"pt-BR")).to eq("Respond in Brazilian Portuguese (PT-BR).")
    end
  end
end
