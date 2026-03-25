class PagesController < ApplicationController
  def home
    redirect_to new_search_path if user_signed_in?
  end
end
