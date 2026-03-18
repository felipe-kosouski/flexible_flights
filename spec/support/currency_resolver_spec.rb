# spec/support/currency_resolver_spec.rb
require "rails_helper"

RSpec.describe CurrencyResolver do
  describe ".for_locale" do
    it "returns USD for en" do
      expect(described_class.for_locale("en")).to eq("USD")
    end

    it "returns BRL for pt-BR" do
      expect(described_class.for_locale("pt-BR")).to eq("BRL")
    end

    it "returns USD for unknown locale" do
      expect(described_class.for_locale("fr")).to eq("USD")
    end

    it "accepts symbols" do
      expect(described_class.for_locale(:"pt-BR")).to eq("BRL")
    end
  end
end
