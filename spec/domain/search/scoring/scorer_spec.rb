# # frozen_string_literal: true

# RSpec.describe Search::Scoring::Scorer do
#   subject(:scorer) { described_class.new(samples) }

#   let(:samples) do
#     [
#       {
#         price_cents: 100_000,
#         air_time_minutes: 600,
#         layover_time_minutes: 120,
#         stops_count: 1,
#         baggage_included: true
#       },
#       {
#         price_cents: 80_000,
#         air_time_minutes: 900,
#         layover_time_minutes: 300,
#         stops_count: 2,
#         baggage_included: false
#       }
#     ]
#   end

#   describe "#score" do
#     it "returns a score for each sample" do
#       results = scorer.score

#       expect(results.size).to eq(2)
#       expect(results.first).to include(:score)
#     end

#     it "returns numeric scores" do
#       results = scorer.score

#       expect(results.map { |r| r[:score] }).to all(be_a(Numeric))
#     end

#     it "does not mutate input samples" do
#       original = Marshal.load(Marshal.dump(samples))

#       scorer.score

#       expect(samples).to eq(original)
#     end
#   end

#   describe "relative scoring" do
#     it "gives better score to cheaper flights" do
#       results = scorer.score

#       cheaper = results.find { |r| r[:price_cents] == 80_000 }
#       expensive = results.find { |r| r[:price_cents] == 100_000 }

#       expect(cheaper[:score]).to be > expensive[:score]
#     end

#     it "penalizes longer total travel time" do
#       results = scorer.score

#       shorter = results.find { |r| r[:air_time_minutes] == 600 }
#       longer = results.find { |r| r[:air_time_minutes] == 900 }

#       expect(shorter[:score]).to be > longer[:score]
#     end
#   end

#   describe "stops and baggage penalties" do
#     it "penalizes flights with more stops" do
#       results = scorer.score

#       fewer_stops = results.find { |r| r[:stops_count] == 1 }
#       more_stops = results.find { |r| r[:stops_count] == 2 }

#       expect(fewer_stops[:score]).to be > more_stops[:score]
#     end

#     it "penalizes missing baggage" do
#       results = scorer.score

#       with_baggage = results.find { |r| r[:baggage_included] }
#       without_baggage = results.find { |r| !r[:baggage_included] }

#       expect(with_baggage[:score]).to be > without_baggage[:score]
#     end
#   end
# end
