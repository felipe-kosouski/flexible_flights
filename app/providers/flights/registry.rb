# frozen_string_literal: true

module Flights
  class Registry
    PROVIDERS = {
      "stub" => -> { Stub.new },
      "amadeus" => -> { Amadeus::Provider.new }
    }.freeze

    def self.resolve(name)
      factory = PROVIDERS[name] or raise ArgumentError, "Unknown provider: #{name.inspect}"
      factory.call
    end
  end
end
