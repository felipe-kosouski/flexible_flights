# frozen_string_literal: true

# Zeitwerk explicit namespace file.
# Loaded before any file under app/providers/flights/, ensuring error constants
# are available whenever any Flights::* constant is first referenced.
module Flights
  Error = Class.new(StandardError)
  TimeoutError = Class.new(Error)
  RateLimitError = Class.new(Error)
  InvalidResponse = Class.new(Error)
  AuthError = Class.new(Error)
end
