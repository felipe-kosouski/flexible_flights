# frozen_string_literal: true

class SearchHistoryPresenter
  include Rails.application.routes.url_helpers

  DAYS_IN_SECONDS = 86_400

  def initialize(search_run)
    @run    = search_run
    @intent = search_run.search_intent
  end

  def route
    "#{@intent.origin_airport.upcase} → #{@intent.destination_airport.upcase}"
  end

  def date_window
    from = @intent.earliest_departure.strftime("%-d %b")
    to   = @intent.latest_return.strftime("%-d %b")
    "#{from} – #{to}"
  end

  def stay_range
    "#{@intent.min_stay_days}–#{@intent.max_stay_days} nights"
  end

  def status_label
    case @run.state
    when "completed" then "Completed"
    when "failed"    then "Failed"
    else                  "In progress"
    end
  end

  def status_color_class
    case @run.state
    when "completed" then "bg-emerald-100 text-emerald-800"
    when "failed"    then "bg-red-100 text-red-800"
    else                  "bg-amber-100 text-amber-800"
    end
  end

  def run_at
    timestamp = @run.finished_at || @run.created_at
    time_ago_in_words(timestamp) + " ago"
  end

  def view_results_path
    return nil unless @run.completed?

    search_path(@run)
  end

  def run_again_path
    new_search_path(from_intent: @intent.id)
  end

  private

  def time_ago_in_words(time)
    seconds = (Time.current - time).round
    days    = seconds / DAYS_IN_SECONDS
    hours   = seconds / 3600
    minutes = seconds / 60

    if days >= 1
      "#{days} #{days == 1 ? 'day' : 'days'}"
    elsif hours >= 1
      "#{hours} #{hours == 1 ? 'hour' : 'hours'}"
    elsif minutes >= 1
      "#{minutes} #{minutes == 1 ? 'minute' : 'minutes'}"
    else
      "moments"
    end
  end
end
