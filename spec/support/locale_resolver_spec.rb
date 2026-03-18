# spec/support/locale_resolver_spec.rb
require "rails_helper"

RSpec.describe LocaleResolver do
  let(:user_with_locale) { instance_double("User", preferred_locale: "pt-BR") }
  let(:user_without_locale) { instance_double("User", preferred_locale: nil) }

  describe ".resolve" do
    it "returns user preferred_locale when set and supported" do
      expect(described_class.resolve(user: user_with_locale)).to eq("pt-BR")
    end

    it "ignores unsupported user preferred_locale and falls back to session" do
      user = instance_double("User", preferred_locale: "fr")
      expect(described_class.resolve(user: user, session_locale: "en")).to eq("en")
    end

    it "falls back to session_locale when user has none" do
      expect(described_class.resolve(user: user_without_locale, session_locale: "pt-BR")).to eq("pt-BR")
    end

    it "falls back to Accept-Language header when no user or session" do
      expect(described_class.resolve(accept_language: "pt-BR,en;q=0.9")).to eq("pt-BR")
    end

    it "parses Accept-Language with quality values and picks first supported locale" do
      expect(described_class.resolve(accept_language: "en-US,en;q=0.9,pt-BR;q=0.8")).to eq("en")
    end

    it "matches en-US to 'en' via subtag stripping" do
      expect(described_class.resolve(accept_language: "en-US,en-GB;q=0.9")).to eq("en")
    end

    it "returns default 'en' when nothing matches" do
      expect(described_class.resolve(accept_language: "fr,de")).to eq("en")
    end

    it "returns default 'en' when all inputs are nil" do
      expect(described_class.resolve).to eq("en")
    end

    it "rejects unsupported session_locale and falls back to default" do
      expect(described_class.resolve(session_locale: "zh")).to eq("en")
    end
  end
end
