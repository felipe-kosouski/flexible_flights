class Users::RegistrationsController < Devise::RegistrationsController
  private

  # Called by Devise when a new user signs up but confirmation is required.
  # With :confirmable and allow_unconfirmed_access_for = 0.days, every new
  # registration hits this path (never after_sign_up_path_for).
  def after_inactive_sign_up_path_for(resource)
    flash[:unconfirmed_email] = resource.email
    check_email_path
  end
end
