class FlightSample < ApplicationRecord
  belongs_to :search_run

  validates :search_run, presence: true
  validates :provider, presence: true
  validates :price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :air_time_minutes, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :layover_time_minutes, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :stops, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :airlines, presence: true
  validates :luggage_included, inclusion: { in: [ true, false ] }
  validates :departure_datetime, presence: true
  validates :return_datetime, presence: true
end
