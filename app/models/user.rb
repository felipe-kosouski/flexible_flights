class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  SUPPORTED_LOCALES = LocaleResolver::SUPPORTED

  has_many :search_intents, dependent: :destroy
  has_many :search_runs, through: :search_intents
  has_many :credit_purchases, dependent: :destroy

  validates :preferred_locale,
    inclusion: { in: SUPPORTED_LOCALES },
    allow_nil: true
end
