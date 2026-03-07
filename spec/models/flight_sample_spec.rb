require "rails_helper"

RSpec.describe FlightSample, type: :model do
  subject { build(:flight_sample) }

  describe "associations" do
    it { is_expected.to belong_to(:search_run) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:search_run) }
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_presence_of(:price_cents) }
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_presence_of(:air_time_minutes) }
    it { is_expected.to validate_presence_of(:layover_time_minutes) }
    it { is_expected.to validate_presence_of(:stops) }
    it { is_expected.to validate_presence_of(:airlines) }
    it { is_expected.to validate_presence_of(:departure_datetime) }
    it { is_expected.to validate_presence_of(:return_datetime) }

    it { is_expected.to validate_numericality_of(:price_cents).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:air_time_minutes).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:layover_time_minutes).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:stops).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "luggage_included" do
    it "is valid when true" do
      subject.luggage_included = true
      expect(subject).to be_valid
    end

    it "is valid when false" do
      subject.luggage_included = false
      expect(subject).to be_valid
    end

    it "is invalid when nil" do
      subject.luggage_included = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:luggage_included]).to be_present
    end
  end
end
