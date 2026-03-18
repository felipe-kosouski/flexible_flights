# spec/support/price_formatter_spec.rb
require "rails_helper"

RSpec.describe PriceFormatter do
  describe ".call" do
    it "formats USD with dollar sign" do
      expect(described_class.call(53_600, "USD")).to eq("$536")
    end

    it "formats BRL with R$ symbol" do
      expect(described_class.call(234_000, "BRL")).to eq("R$2340")
    end

    it "formats EUR with euro sign" do
      expect(described_class.call(45_000, "EUR")).to eq("€450")
    end

    it "falls back to ISO code for unknown currency" do
      expect(described_class.call(10_000, "JPY")).to eq("JPY100")
    end

    it "returns N/A when cents is nil" do
      expect(described_class.call(nil, "USD")).to eq("N/A")
    end

    it "rounds fractional cents" do
      expect(described_class.call(53_650, "USD")).to eq("$537")
    end

    it "returns N/A when currency is nil" do
      expect(described_class.call(53_600, nil)).to eq("N/A")
    end
  end
end
