require "rails_helper"

RSpec.describe SearchIntent, type: :model do
  subject { build(:search_intent) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:origin_airport) }
    it { is_expected.to validate_presence_of(:destination_airport) }
    it { is_expected.to validate_presence_of(:earliest_departure) }
    it { is_expected.to validate_presence_of(:latest_return) }
    it { is_expected.to validate_presence_of(:min_stay_days) }
    it { is_expected.to validate_presence_of(:max_stay_days) }

    it { is_expected.to validate_presence_of(:currency) }

    it { is_expected.to validate_numericality_of(:min_stay_days).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:max_stay_days).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:max_stops).only_integer.is_greater_than_or_equal_to(0).allow_nil }
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:luggage_requirement)
        .with_values(none: 0, carry_on: 1, checked: 2)
        .with_prefix(:luggage_requirement)
        .backed_by_column_of_type(:integer)
    }
  end

  describe "luggage_requirement" do
    it "is valid when nil" do
      subject.luggage_requirement = nil
      expect(subject).to be_valid
    end

    it "is invalid for an unknown value" do
      expect { subject.luggage_requirement = :business }.to raise_error(ArgumentError)
    end
  end

  describe "max_stops" do
    it "is valid when nil" do
      subject.max_stops = nil
      expect(subject).to be_valid
    end

    it "is invalid when negative" do
      subject.max_stops = -1
      expect(subject).not_to be_valid
    end
  end
end
