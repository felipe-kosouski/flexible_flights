class SearchRun < ApplicationRecord
  belongs_to :search_intent
  has_many :flight_samples, dependent: :destroy
  has_one :analysis_snapshot, dependent: :destroy

  enum :state, {
    initialized: 0,
    sampling: 1,
    completed: 2,
    failed: 3
  }

  validates :search_intent, presence: true
  validates :state, presence: true, inclusion: { in: states.keys }
end
