require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  describe "#welcome" do
    let(:user) { create(:user) }
    subject(:mail) { described_class.welcome(user) }

    it "sends to the user's email" do
      expect(mail.to).to eq([user.email])
    end

    it "has the correct subject" do
      expect(mail.subject).to eq("You're confirmed — here's your free search")
    end

    it "includes the search CTA URL" do
      expect(mail.body.encoded).to include(new_search_url(host: "www.example.com"))
    end

    it "includes the welcome heading" do
      expect(mail.body.encoded).to include("You&#39;re all set")
    end

    it "includes the date window tip" do
      expect(mail.body.encoded).to include("flexible date window")
    end
  end
end
