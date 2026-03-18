# app/support/price_formatter.rb
class PriceFormatter
  SYMBOLS = { "USD" => "$", "BRL" => "R$", "EUR" => "€" }.freeze

  def self.call(cents, currency)
    return "N/A" unless cents
    return "N/A" unless currency
    symbol = SYMBOLS.fetch(currency.to_s, currency.to_s)
    "#{symbol}#{(cents / 100.0).round}"
  end
end
