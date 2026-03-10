# frozen_string_literal: true

module Search
  module Models
    class FlightSample
      REASONABLE_DEPARTURE_HOURS = 6..22
      REASONABLE_ARRIVAL_HOURS   = 7..23

      def initialize(
        departure_datetime:,
        return_datetime:,
        luggage_included:,
        price_cents: nil,
        stops: nil,
        air_time_minutes: nil,
        layover_time_minutes: nil
      )
        @departure_datetime  = departure_datetime
        @return_datetime     = return_datetime
        @luggage_included    = luggage_included
        @price_cents         = price_cents
        @stops               = stops
        @air_time_minutes    = air_time_minutes
        @layover_time_minutes = layover_time_minutes
      end

      def departure_datetime
        @departure_datetime
      end

      def return_datetime
        @return_datetime
      end

      def price_cents
        @price_cents
      end

      def stops
        @stops
      end

      def air_time_minutes
        @air_time_minutes
      end

      def layover_time_minutes
        @layover_time_minutes
      end

      def luggage_included?
        @luggage_included
      end

      def has_times?
        @departure_datetime && @return_datetime
      end

      def stay_length_days
        return 0 unless has_times?

        (@return_datetime.to_date - @departure_datetime.to_date).to_i
      end

      def departure_in_reasonable_window?
        return true unless @departure_datetime

        REASONABLE_DEPARTURE_HOURS.cover?(departure_hour)
      end

      def arrival_in_reasonable_window?
        return true unless @return_datetime

        REASONABLE_ARRIVAL_HOURS.cover?(arrival_hour)
      end

      def red_eye_departure?
        return false unless @departure_datetime

        departure_hour < REASONABLE_DEPARTURE_HOURS.begin
      end

      def very_late_arrival?
        return false unless @return_datetime

        arrival_hour > REASONABLE_ARRIVAL_HOURS.end || arrival_hour < REASONABLE_ARRIVAL_HOURS.begin
      end

      private

      def departure_hour
        @departure_datetime.hour + (@departure_datetime.min / 60.0)
      end

      def arrival_hour
        @return_datetime.hour + (@return_datetime.min / 60.0)
      end
    end
  end
end
