# frozen_string_literal: true

class Users::ConfirmationsController < Devise::ConfirmationsController
  protected

  # Called by Devise only when confirmation succeeds (valid token, not yet confirmed).
  # Side effect (welcome email) lives here, not in the model — consistent with architecture.
  def after_confirmation_path_for(resource_name, resource)
    UserMailer.welcome(resource).deliver_later
    super
  end
end
