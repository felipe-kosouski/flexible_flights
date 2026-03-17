# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Sampling::Sampler do
  let(:departure_date) { Date.new(2025, 3, 1) }
  let(:return_date) { Date.new(2025, 3, 6) }

  let(:valid_sample) do
    {
      price_cents: 12_500,
      currency: "USD",
      airline_codes: [ "AA" ],
      stops: 1,
      air_time_minutes: 420,
      layover_time_minutes: 90,
      luggage_included: true,
      raw_provider: "test"
    }
  end

  describe "#call" do
    context "provider interaction" do
      it "calls provider with correct parameters for each date pair" do
        provider = double("Provider", search: [ valid_sample ])

        sampler = described_class.new(
          origin: "NYC",
          destination: "LON",
          date_pairs: [
            [ departure_date, return_date ],
            [ departure_date + 1, return_date + 1 ]
          ],
          passengers: 2,
          cabin_class: :business,
          provider: provider
        )

        sampler.call

        expect(provider).to have_received(:search).with(
          origin: "NYC",
          destination: "LON",
          departure_date: departure_date,
          return_date: return_date,
          passengers: 2,
          cabin_class: :business
        )

        expect(provider).to have_received(:search).with(
          origin: "NYC",
          destination: "LON",
          departure_date: departure_date + 1,
          return_date: return_date + 1,
          passengers: 2,
          cabin_class: :business
        )
      end

      it "uses default passengers and cabin_class when not provided" do
        provider = double("Provider", search: [ valid_sample ])

        sampler = described_class.new(
          origin: "NYC",
          destination: "LON",
          date_pairs: [ [ departure_date, return_date ] ],
          provider: provider
        )

        sampler.call

        expect(provider).to have_received(:search).with(
          hash_including(passengers: 1, cabin_class: :economy)
        )
      end
    end

    context "provider return contract" do
      it "raises when provider returns nil" do
        provider = double("Provider", search: nil)

        sampler = described_class.new(
          origin: "NYC",
          destination: "LON",
          date_pairs: [ [ departure_date, return_date ] ],
          provider: provider
        )

        expect { sampler.call }.to raise_error(TypeError)
      end

      it "raises when provider returns a non-array value" do
        provider = double("Provider", search: "invalid")

        sampler = described_class.new(
          origin: "NYC",
          destination: "LON",
          date_pairs: [ [ departure_date, return_date ] ],
          provider: provider
        )

        expect { sampler.call }.to raise_error(TypeError)
      end

      it "allows provider exceptions to bubble up" do
        provider = double("Provider")
        allow(provider).to receive(:search).and_raise(StandardError, "network failure")

        sampler = described_class.new(
          origin: "NYC",
          destination: "LON",
          date_pairs: [ [ departure_date, return_date ] ],
          provider: provider
        )

        expect { sampler.call }.to raise_error(StandardError, "network failure")
      end
    end

    context "sample normalization and validation" do
      it "returns normalized samples with attached dates" do
        provider = double("Provider", search: [ valid_sample ])

        sampler = described_class.new(
          origin: "NYC",
          destination: "LON",
          date_pairs: [ [ departure_date, return_date ] ],
          provider: provider
        )

        result = sampler.call

        expect(result).to eq([
          valid_sample.merge(
            departure_datetime: departure_date.to_time,
            return_datetime: return_date.to_time
          )
        ])
      end

      it "skips samples that are not hashes" do
        provider = double("Provider", search: [ "invalid", valid_sample ])

        sampler = described_class.new(
          origin: "NYC",
          destination: "LON",
          date_pairs: [ [ departure_date, return_date ] ],
          provider: provider
        )

        result = sampler.call

        expect(result.size).to eq(1)
        expect(result.first[:price_cents]).to eq(12_500)
      end

      it "skips samples missing required fields" do
        invalid_sample = valid_sample.except(:currency)

        provider = double("Provider", search: [ invalid_sample, valid_sample ])

        sampler = described_class.new(
          origin: "NYC",
          destination: "LON",
          date_pairs: [ [ departure_date, return_date ] ],
          provider: provider
        )

        result = sampler.call

        expect(result.size).to eq(1)
        expect(result.first[:currency]).to eq("USD")
      end
    end

    context "ordering guarantees" do
      it "preserves date_pairs order and provider result order" do
        provider = double("Provider")
        allow(provider).to receive(:search).and_return(
          [ valid_sample.merge(price_cents: 100) ],
          [ valid_sample.merge(price_cents: 200) ]
        )

        sampler = described_class.new(
          origin: "A",
          destination: "B",
          date_pairs: [
            [ departure_date, return_date ],
            [ departure_date + 1, return_date + 1 ]
          ],
          provider: provider
        )

        result = sampler.call

        expect(result.map { |s| s[:price_cents] }).to eq([ 100, 200 ])
        expect(result.map { |s| s[:departure_datetime] }).to eq([
          departure_date.to_time,
          (departure_date + 1).to_time
        ])
      end
    end

    context "edge cases" do
      it "returns an empty array and does not call provider when date_pairs is empty" do
        provider = spy("Provider")

        sampler = described_class.new(
          origin: "NYC",
          destination: "LON",
          date_pairs: [],
          provider: provider
        )

        result = sampler.call

        expect(result).to eq([])
        expect(provider).not_to have_received(:search)
      end
    end
  end
end
