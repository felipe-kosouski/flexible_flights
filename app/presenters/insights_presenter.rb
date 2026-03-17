# frozen_string_literal: true

class InsightsPresenter
  def initialize(insights, route_summary: nil, origin: nil, destination: nil)
    @insights      = insights
    @route_summary = route_summary
    @origin        = origin
    @destination   = destination
  end

  def wait_or_book
    return nil unless @insights.wait_or_book

    WaitOrBookPresenter.new(@insights.wait_or_book)
  end

  def best_time_to_travel
    return nil unless @insights.best_time_to_travel

    DateRangePresenter.new(@insights.best_time_to_travel, origin: @origin, destination: @destination)
  end

  def price_rarity
    return nil unless @insights.price_rarity

    PriceRarityPresenter.new(@insights.price_rarity)
  end

  def cheapest_comfort_window
    return nil unless @insights.cheapest_comfort_window

    DateRangePresenter.new(@insights.cheapest_comfort_window, origin: @origin, destination: @destination)
  end

  def confidence_level
    @insights.confidence_level
  end

  def low_confidence?
    @insights.confidence_level == :low
  end

  def route_summary
    @route_summary
  end

  def any?
    wait_or_book || best_time_to_travel || price_rarity || cheapest_comfort_window
  end

  class WaitOrBookPresenter
    def initialize(insight)
      @insight = insight
    end

    def directive_label
      case @insight.directive
      when :book_now then "Book Now"
      when :wait then "Wait"
      when :consider_booking then "Consider Booking"
      else "Not Enough Data"
      end
    end

    def directive_color_class
      case @insight.directive
      when :book_now then "bg-emerald-50 border-emerald-200 text-emerald-900"
      when :wait then "bg-blue-50 border-blue-200 text-blue-900"
      when :consider_booking then "bg-yellow-50 border-yellow-200 text-yellow-900"
      else "bg-gray-50 border-gray-200 text-gray-700"
      end
    end

    def directive_badge_class
      case @insight.directive
      when :book_now then "bg-emerald-100 text-emerald-700"
      when :wait then "bg-blue-100 text-blue-700"
      when :consider_booking then "bg-yellow-100 text-yellow-700"
      else "bg-gray-100 text-gray-500"
      end
    end

    def price_band_label
      case @insight.price_band
      when :cheap then "Prices are cheap right now"
      when :below_median then "Prices are below average"
      when :above_median then "Prices are above average"
      when :expensive then "Prices are high"
      end
    end

    def top_price
      cents = @insight.top_flight_median_price_cents
      return nil unless cents

      "$#{(cents / 100.0).round}"
    end

    def confidence_level
      @insight.confidence_level
    end

    def medium_confidence?
      @insight.confidence_level == :medium
    end

    def subtext
      return "Not enough data to make a reliable recommendation for this route yet." if @insight.directive == :insufficient_data

      case @insight.confidence_level
      when :high
        case @insight.directive
        when :book_now          then "Prices are at a good level right now — waiting risks paying more."
        when :wait              then "Prices are elevated for this route. Better options are likely ahead."
        when :consider_booking  then "Conditions are reasonable. Booking now is a solid choice."
        end
      when :medium
        case @insight.directive
        when :book_now          then "Prices suggest this may be a good time to book."
        when :wait              then "Prices suggest waiting could pay off for this route."
        when :consider_booking  then "Prices appear reasonable, though the data picture isn't fully clear."
        end
      end
    end
  end

  class DateRangePresenter
    def initialize(insight, origin: nil, destination: nil)
      @insight     = insight
      @origin      = origin
      @destination = destination
    end

    def search_urls
      return nil unless @origin && @destination

      FlightSearchUrlBuilder.call(
        origin:         @origin,
        destination:    @destination,
        departure_date: @insight.from_date,
        return_date:    @insight.to_date
      )
    end

    def date_range
      "#{@insight.from_date.strftime('%b %-d')} – #{@insight.to_date.strftime('%b %-d')}"
    end

    def average_score
      @insight.average_score.round
    end

    def flight_count
      @insight.flight_count
    end

    def confidence_level
      @insight.confidence_level
    end

    def medium_confidence?
      @insight.confidence_level == :medium
    end

    def description
      case @insight.confidence_level
      when :high   then "Strong market signal for this window."
      when :medium then "Based on available data, this window looks favorable."
      end
    end
  end

  class PriceRarityPresenter
    def initialize(insight)
      @insight = insight
    end

    def label
      case @insight.classification
      when :rare_cheap then "Rare deal"
      when :below_median then "Below average"
      when :above_median then "Above average"
      when :expensive then "Expensive"
      end
    end

    def color_class
      case @insight.classification
      when :rare_cheap then "bg-emerald-50 border-emerald-200 text-emerald-900"
      when :below_median then "bg-blue-50 border-blue-200 text-blue-900"
      when :above_median then "bg-yellow-50 border-yellow-200 text-yellow-900"
      when :expensive then "bg-red-50 border-red-200 text-red-900"
      end
    end

    def badge_class
      case @insight.classification
      when :rare_cheap then "bg-emerald-100 text-emerald-700"
      when :below_median then "bg-blue-100 text-blue-700"
      when :above_median then "bg-yellow-100 text-yellow-700"
      when :expensive then "bg-red-100 text-red-700"
      end
    end

    def market_price
      cents = @insight.market_representative_price_cents
      return nil unless cents

      "$#{(cents / 100.0).round}"
    end

    def confidence_level
      @insight.confidence_level
    end

    def medium_confidence?
      @insight.confidence_level == :medium
    end

    def description
      case @insight.confidence_level
      when :high
        case @insight.classification
        when :rare_cheap    then "Prices are unusually low for this route right now."
        when :below_median  then "Prices are below the typical range for this route."
        when :above_median  then "Prices are above the typical range for this route."
        when :expensive     then "Prices are high relative to this route's history."
        end
      when :medium
        case @insight.classification
        when :rare_cheap    then "Prices appear lower than usual, though data is limited."
        when :below_median  then "Prices appear to be below average."
        when :above_median  then "Prices appear to be above average."
        when :expensive     then "Prices appear high, though data is limited."
        end
      end
    end
  end
end
