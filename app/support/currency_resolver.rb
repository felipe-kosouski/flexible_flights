# app/support/currency_resolver.rb
class CurrencyResolver
  LOCALE_CURRENCY = {
    "en" => "USD",
    "pt-BR" => "BRL"
  }.freeze
  DEFAULT = "USD".freeze

  def self.for_locale(locale)
    LOCALE_CURRENCY.fetch(locale.to_s, DEFAULT)
  end
end
