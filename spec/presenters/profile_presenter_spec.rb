# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProfilePresenter do
  let(:errors) { instance_double(ActiveModel::Errors) }

  def build_presenter(first_name: "Jane", last_name: "Doe", email: "jane@example.com")
    user = instance_double(User,
      first_name: first_name,
      last_name: last_name,
      email: email,
      errors: errors)
    described_class.new(user)
  end

  describe "#display_name" do
    it "returns full name when both fields are set" do
      expect(build_presenter.display_name).to eq("Jane Doe")
    end

    it "returns only first name when last name is blank" do
      expect(build_presenter(last_name: "").display_name).to eq("Jane")
    end

    it "returns only last name when first name is blank" do
      expect(build_presenter(first_name: "").display_name).to eq("Doe")
    end

    it "falls back to email when both name fields are blank" do
      expect(build_presenter(first_name: "", last_name: "").display_name).to eq("jane@example.com")
    end

    it "falls back to email when name fields are nil" do
      expect(build_presenter(first_name: nil, last_name: nil).display_name).to eq("jane@example.com")
    end
  end

  describe "#personal_info_errors" do
    it "returns full messages for first_name, last_name, and email" do
      allow(errors).to receive(:full_messages_for).with(:first_name).and_return([ "First name can't be blank" ])
      allow(errors).to receive(:full_messages_for).with(:last_name).and_return([])
      allow(errors).to receive(:full_messages_for).with(:email).and_return([])

      expect(build_presenter.personal_info_errors).to eq([ "First name can't be blank" ])
    end

    it "returns empty array when there are no errors" do
      allow(errors).to receive(:full_messages_for).with(:first_name).and_return([])
      allow(errors).to receive(:full_messages_for).with(:last_name).and_return([])
      allow(errors).to receive(:full_messages_for).with(:email).and_return([])

      expect(build_presenter.personal_info_errors).to eq([])
    end
  end

  describe "#password_errors" do
    it "returns full messages for current_password, password, and password_confirmation" do
      allow(errors).to receive(:full_messages_for).with(:current_password).and_return([ "Current password is invalid" ])
      allow(errors).to receive(:full_messages_for).with(:password).and_return([])
      allow(errors).to receive(:full_messages_for).with(:password_confirmation).and_return([])

      expect(build_presenter.password_errors).to eq([ "Current password is invalid" ])
    end

    it "returns empty array when there are no errors" do
      allow(errors).to receive(:full_messages_for).with(:current_password).and_return([])
      allow(errors).to receive(:full_messages_for).with(:password).and_return([])
      allow(errors).to receive(:full_messages_for).with(:password_confirmation).and_return([])

      expect(build_presenter.password_errors).to eq([])
    end
  end
end
