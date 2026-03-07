class User < ApplicationRecord
  has_many :search_intents, dependent: :destroy
end
