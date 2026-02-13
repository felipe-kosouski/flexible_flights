class SearchIntent < ApplicationRecord
  belongs_to :user

  enum :luggage_requirement, {
    none: 0,
    carry_on: 1,
    checked: 2
  }, prefix: true

  validates :user, presence: true
  validates :origin_airport, presence: true
  validates :destination_airport, presence: true
  validates :earliest_departure, presence: true
  validates :latest_return, presence: true
  validates :min_stay_days, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_stay_days, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :luggage_requirement, presence: true, inclusion: { in: luggage_requirements.keys }
  validates :max_stops, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
