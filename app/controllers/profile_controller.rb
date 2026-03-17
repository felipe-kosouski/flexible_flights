# frozen_string_literal: true

class ProfileController < ApplicationController
  before_action :authenticate_user!

  def show
    @presenter = ProfilePresenter.new(current_user)
  end

  def update
    case params[:form_type]
    when "personal_info" then update_personal_info
    when "password"      then update_password
    else
      redirect_to profile_path, alert: "Invalid request."
    end
  end

  def destroy
    if params[:confirmation_email].to_s.strip.downcase == current_user.email.downcase
      user = current_user
      sign_out user
      user.destroy!
      redirect_to root_path, notice: "Your account has been deleted."
    else
      redirect_to profile_path, alert: "Email did not match. Account not deleted."
    end
  end

  private

  def update_personal_info
    if current_user.update(personal_info_params)
      redirect_to profile_path, notice: "Profile updated."
    else
      @presenter = ProfilePresenter.new(current_user)
      render :show, status: :unprocessable_entity
    end
  end

  def update_password
    if current_user.update_with_password(password_params)
      # bypass_sign_in prevents Devise from signing the user out after a password change
      bypass_sign_in(current_user)
      redirect_to profile_path, notice: "Password updated."
    else
      @presenter = ProfilePresenter.new(current_user)
      render :show, status: :unprocessable_entity
    end
  end

  def personal_info_params
    params.require(:user).permit(:first_name, :last_name, :email)
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
