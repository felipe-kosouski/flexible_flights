# frozen_string_literal: true

class InsightsPresenter
  def initialize(insights)
    @insights = insights
  end

  def wait_or_book
    return nil unless @insights.wait_or_book

    WaitOrBookPresenter.new(@insights.wait_or_book)
  end

  def best_time_to_travel
    return nil unless @insights.best_time_to_travel

    DateRangePresenter.new(@insights.best_time_to_travel)
  end

  def price_rarity
    return nil unless @insights.price_rarity

    PriceRarityPresenter.new(@insights.price_rarity)
  end

  def cheapest_comfort_window
    return nil unless @insights.cheapest_comfort_window

    DateRangePresenter.new(@insights.cheapest_comfort_window)
  end

  def confidence_level
    @insights.confidence_level
  end

  def low_confidence?
    @insights.confidence_level == :low
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

      nil
    end
  end

  class DateRangePresenter
    def initialize(insight)
      @insight = insight
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
  end
end
