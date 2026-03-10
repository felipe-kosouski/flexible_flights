# frozen_string_literal: true

class SearchResultsPresenter
  def initialize(results, search_run)
    @results = results
    @search_run = search_run
  end

  def ranked_flights
    @ranked_flights ||= @results.ranked_flights.map { |rf| RankedFlightPresenter.new(rf) }
  end

  def insights
    @insights ||= InsightsPresenter.new(@results.insights)
  end

  def origin
    @search_run.search_intent.origin_airport.upcase
  end

  def destination
    @search_run.search_intent.destination_airport.upcase
  end

  def sample_count
    @results.snapshot.sample_count
  end

  def confidence_label
    case @results.snapshot.confidence
    when :high then "High confidence"
    when :medium then "Medium confidence"
    when :low then "Low confidence"
    end
  end

  def confidence_color_class
    case @results.snapshot.confidence
    when :high then "text-emerald-600"
    when :medium then "text-yellow-600"
    when :low then "text-red-500"
    end
  end
end
