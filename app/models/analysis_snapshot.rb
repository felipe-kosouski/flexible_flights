class AnalysisSnapshot < ApplicationRecord
  belongs_to :search_run

  enum :confidence_level, {
    low: 0,
    medium: 1,
    high: 2
  }, prefix: :confidence

  enum :volatility, {
    low: 0,
    medium: 1,
    high: 2
  }, prefix: :volatility

  validates :search_run, presence: true
  validates :confidence_level, presence: true, inclusion: { in: confidence_levels.keys }
  validates :volatility, presence: true, inclusion: { in: volatilities.keys }
  validates :route_median_duration_minutes, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :price_p25_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :price_p50_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :price_p75_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sample_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
