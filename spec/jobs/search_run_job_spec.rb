require "rails_helper"

RSpec.describe SearchRunJob, type: :job do
  let(:user) { create(:user, search_credits: 1) }
  let(:search_intent) { create(:search_intent, user: user) }
  let(:search_run) { create(:search_run, search_intent: search_intent) }

  before do
    allow(Search::Repositories::SearchRunRepository).to receive(:execute)
    allow(Search::Repositories::SearchRunRepository).to receive(:load_results).and_return(nil)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
  end

  describe "credit deduction" do
    it "decrements search_credits by 1 after successful execution" do
      expect {
        described_class.new.perform(search_run.id)
      }.to change { user.reload.search_credits }.from(1).to(0)
    end

    it "does not decrement credits when execution raises" do
      allow(Search::Repositories::SearchRunRepository).to receive(:execute).and_raise(StandardError, "search failed")

      expect {
        described_class.new.perform(search_run.id) rescue nil
      }.not_to change { user.reload.search_credits }
    end

    it "does not raise when the CHECK constraint would be violated (concurrent edge case)" do
      user.update_columns(search_credits: 0)

      expect { described_class.new.perform(search_run.id) }.not_to raise_error
      expect(user.reload.search_credits).to eq(0)
    end
  end
end
