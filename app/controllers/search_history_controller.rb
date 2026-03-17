# frozen_string_literal: true

class SearchHistoryController < ApplicationController
  before_action :authenticate_user!

  def index
    @search_runs = current_user.search_runs
                               .includes(:search_intent)
                               .order(created_at: :desc)
  end
end
