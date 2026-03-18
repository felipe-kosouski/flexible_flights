# frozen_string_literal: true

class InsightsPresenter
  def initialize(insights, route_summary: nil, origin: nil, destination: nil, currency: nil)
    @insights = insights
    @route_summary = route_summary
    @origin = origin
    @destination = destination
    @currency = currency
  end

  def wait_or_book
    return nil unless @insights.wait_or_book

    WaitOrBookPresenter.new(@insights.wait_or_book, currency: @currency)
  end

  def best_time_to_travel
    return nil unless @insights.best_time_to_travel

    DateRangePresenter.new(@insights.best_time_to_travel, origin: @origin, destination: @destination)
  end

  def price_rarity
    return nil unless @insights.price_rarity

    PriceRarityPresenter.new(@insights.price_rarity, currency: @currency)
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
    def initialize(insight, currency: nil)
      @insight = insight
      @currency = currency
    end

    def directive_label
      key = @insight.directive == :insufficient_data ? "insufficient_data" : @insight.directive.to_s
      I18n.t("insights.wait_or_book.#{key}")
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
      I18n.t("insights.price_band.#{@insight.price_band}")
    end

    def top_price
      cents = @insight.top_flight_median_price_cents
      return nil unless cents

      PriceFormatter.call(cents, @currency || "USD")
    end

    def confidence_level
      @insight.confidence_level
    end

    def medium_confidence?
      @insight.confidence_level == :medium
    end

    def subtext
      return I18n.t("insights.subtext.insufficient_data") if @insight.directive == :insufficient_data

      key = "#{@insight.confidence_level}_#{@insight.directive}"
      I18n.t("insights.subtext.#{key}", default: nil)
    end
  end

  class DateRangePresenter
    def initialize(insight, origin: nil, destination: nil)
      @insight = insight
      @origin = origin
      @destination = destination
    end

    def search_urls
      return nil unless @origin && @destination

      FlightSearchUrlBuilder.call(
        origin: @origin,
        destination: @destination,
        departure_date: @insight.from_date,
        return_date: @insight.to_date
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
      I18n.t("insights.date_range.description_#{@insight.confidence_level}", default: nil)
    end
  end

  class PriceRarityPresenter
    def initialize(insight, currency: nil)
      @insight = insight
      @currency = currency
    end

    def label
      I18n.t("insights.price_rarity.#{@insight.classification}")
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

      PriceFormatter.call(cents, @currency || "USD")
    end

    def confidence_level
      @insight.confidence_level
    end

    def medium_confidence?
      @insight.confidence_level == :medium
    end

    def description
      key = "#{@insight.confidence_level}_#{@insight.classification}"
      I18n.t("insights.price_rarity_description.#{key}", default: nil)
    end
  end
end
