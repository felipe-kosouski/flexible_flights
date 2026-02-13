class SearchRun < ApplicationRecord
  belongs_to :search_intent

  enum :status, {
    pending: 0,
    running: 1,
    completed: 2,
    failed: 3
  }

  validates :search_intent, presence: true
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :started_at, presence: true
  validates :completed_at, presence: true
end
