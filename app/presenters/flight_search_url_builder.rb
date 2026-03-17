# frozen_string_literal: true

require "date"

FlightSearchUrls = Struct.new(:google_flights_url, :skyscanner_url, keyword_init: true)

class FlightSearchUrlBuilder
  SKYSCANNER_BASE     = "https://www.skyscanner.com/transport/flights"
  GOOGLE_FLIGHTS_BASE = "https://www.google.com/flights/"

  CABIN_CLASS_STRINGS = {
    economy:  "economy",
    business: "business",
    first:    "first"
  }.freeze

  def self.call(origin:, destination:, departure_date:, return_date:, passengers: 1, cabin_class: :economy)
    new(origin:, destination:, departure_date:, return_date:, passengers:, cabin_class:).call
  end

  def initialize(origin:, destination:, departure_date:, return_date:, passengers:, cabin_class:)
    @origin         = origin.upcase
    @destination    = destination.upcase
    @departure_date = departure_date
    @return_date    = return_date
    @passengers     = passengers
    @cabin_class    = cabin_class
  end

  def call
    FlightSearchUrls.new(
      google_flights_url: build_google_flights_url,
      skyscanner_url:     build_skyscanner_url
    ).freeze
  end

  private

  def build_skyscanner_url
    depart = @departure_date.strftime("%y%m%d")
    ret    = @return_date.strftime("%y%m%d")
    cabin  = CABIN_CLASS_STRINGS.fetch(@cabin_class, "economy")

    "#{SKYSCANNER_BASE}/#{@origin}/#{@destination}/#{depart}/#{ret}/?adults=#{@passengers}&cabinclass=#{cabin}"
  end

  def build_google_flights_url
    depart = @departure_date.iso8601
    ret    = @return_date.iso8601

    "#{GOOGLE_FLIGHTS_BASE}#search;f=#{@origin};t=#{@destination};d=#{depart};r=#{ret}"
  end
end
