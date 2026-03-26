class PagesController < ApplicationController
  def home
    redirect_to new_search_path if user_signed_in?
  end

  def check_email
  end
end
