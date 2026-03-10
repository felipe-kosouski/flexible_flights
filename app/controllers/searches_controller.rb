# frozen_string_literal: true

class SearchesController < ApplicationController
  def new
    @search_intent = SearchIntent.new
  end

  def create
    @search_intent = current_user.search_intents.build(search_intent_params)

    if @search_intent.save
      search_run = @search_intent.search_runs.create!
      SearchRunJob.perform_later(search_run.id)
      redirect_to search_path(search_run)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @search_run = SearchRun.includes(search_intent: :user).find(params[:id])

    return unless @search_run.completed?

    results = Search::Repositories::SearchRunRepository.load_results(@search_run)
    @presenter = SearchResultsPresenter.new(results, @search_run) if results
  end

  private

  def search_intent_params
    params.require(:search_intent).permit(
      :origin_airport, :destination_airport,
      :earliest_departure, :latest_return,
      :min_stay_days, :max_stay_days,
      :luggage_requirement, :max_stops
    )
  end
end
