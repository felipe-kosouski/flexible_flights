require "rails_helper"

RSpec.describe SearchRun, type: :model do
  subject { build(:search_run) }

  describe "associations" do
    it { is_expected.to belong_to(:search_intent) }
    it { is_expected.to have_many(:flight_samples).dependent(:destroy) }
    it { is_expected.to have_one(:analysis_snapshot).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:search_intent) }
    it { is_expected.to validate_presence_of(:state) }
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:state)
        .with_values(initialized: 0, sampling: 1, completed: 2, failed: 3)
        .backed_by_column_of_type(:integer)
    }
  end

  describe "default state" do
    it "defaults to initialized" do
      search_run = SearchRun.new(search_intent: build(:search_intent))
      expect(search_run.state).to eq("initialized")
    end
  end

  describe "state transitions" do
    it "is valid in all defined states" do
      %i[initialized sampling completed failed].each do |state|
        subject.state = state
        expect(subject).to be_valid, "expected #{state} to be valid"
      end
    end
  end
end
