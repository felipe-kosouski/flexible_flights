require "rails_helper"

RSpec.describe AnalysisSnapshot, type: :model do
  subject { build(:analysis_snapshot) }

  describe "associations" do
    it { is_expected.to belong_to(:search_run) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:search_run) }
    it { is_expected.to validate_presence_of(:confidence_level) }
    it { is_expected.to validate_presence_of(:volatility) }

    it { is_expected.to validate_numericality_of(:price_p25_cents).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:price_p50_cents).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:price_p75_cents).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:route_median_duration_minutes).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:sample_count).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:confidence_level)
        .with_values(low: 0, medium: 1, high: 2)
        .with_prefix(:confidence)
        .backed_by_column_of_type(:integer)
    }

    it {
      is_expected.to define_enum_for(:volatility)
        .with_values(low: 0, medium: 1, high: 2)
        .with_prefix(:volatility)
        .backed_by_column_of_type(:integer)
    }
  end

  describe "database constraints" do
    it "enforces one snapshot per search run" do
      snapshot = create(:analysis_snapshot)

      expect {
        create(:analysis_snapshot, search_run: snapshot.search_run)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
