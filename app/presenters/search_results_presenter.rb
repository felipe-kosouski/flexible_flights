# frozen_string_literal: true

class SearchResultsPresenter
  def initialize(results, search_run)
    @results = results
    @search_run = search_run
  end

  def ranked_flights
    intent = @search_run.search_intent
    total  = @results.ranked_flights.size
    copy   = batch_ai_copy

    role_map = curated_with_roles
    @ranked_flights ||= curated_flights.map { |rf|
      fingerprint = ExplanationCopyService.fingerprint_for(rf)
      RankedFlightPresenter.new(rf, intent: intent, total_flights: total, ai_copy: copy[fingerprint], tags: role_map[rf])
    }
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

  private

  def curated_flights
    curated_with_roles.keys.sort_by(&:rank)
  end

  def curated_with_roles
    @curated_with_roles ||= begin
      all          = @results.ranked_flights
      top3         = all.first(3)
      best_price   = all.max_by { |rf|
        [ rf.score_result.components[:price].to_f, -rf.flight.price_cents.to_i ]
      }
      best_comfort = all.max_by { |rf|
        total = rf.flight.air_time_minutes.to_i + rf.flight.layover_time_minutes.to_i
        [ rf.score_result.components[:time_comfort].to_f, -total ]
      }
      top3_set     = top3.to_set

      (top3 + [ best_price, best_comfort ].compact).uniq.each_with_object({}) do |rf, map|
        roles = []
        roles << :top_rated    if top3_set.include?(rf)
        roles << :best_price   if rf.equal?(best_price)
        roles << :best_comfort if rf.equal?(best_comfort)
        map[rf] = roles
      end
    end
  end

  def batch_ai_copy
    @batch_ai_copy ||= ExplanationCopyService.batch_call(
      ranked_flights: curated_flights,
      intent: @search_run.search_intent,
      total_flights: @results.ranked_flights.size
    )
  end
end
