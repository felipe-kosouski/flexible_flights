# frozen_string_literal: true

class ProfilePresenter
  PERSONAL_INFO_FIELDS = %i[first_name last_name email].freeze
  PASSWORD_FIELDS = %i[current_password password password_confirmation].freeze

  def initialize(user)
    @user = user
  end

  def display_name
    first = @user.first_name.to_s
    last = @user.last_name.to_s
    name = "#{first} #{last}".strip
    name.present? ? name : @user.email
  end

  def personal_info_errors
    PERSONAL_INFO_FIELDS.flat_map { |field| @user.errors.full_messages_for(field) }
  end

  def password_errors
    PASSWORD_FIELDS.flat_map { |field| @user.errors.full_messages_for(field) }
  end
end
