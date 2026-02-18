class SearchRun < ApplicationRecord
  belongs_to :search_intent

  enum :state, {
    initialized: 0,
    sampling: 1,
    completed: 2,
    failed: 3
  }

  validates :search_intent, presence: true
  validates :state, presence: true, inclusion: { in: states.keys }
end
