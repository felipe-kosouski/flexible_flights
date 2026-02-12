class AnalysisSnapshot < ApplicationRecord
  belongs_to :search_run

  enum :confidence_level, {
    low: 0,
    medium: 1,
    high: 2
  }

  validates :search_run, presence: true
  validates :confidence_level, presence: true, inclusion: { in: confidence_level.keys }
  validates :route_median_duration_minutes, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :price_p25_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :price_p50_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :price_p75_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sample_size, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
