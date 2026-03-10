class SearchIntent < ApplicationRecord
  belongs_to :user
  has_many :search_runs, dependent: :destroy

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
  validates :luggage_requirement, inclusion: { in: luggage_requirements.keys }, allow_nil: true
  validates :max_stops, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
