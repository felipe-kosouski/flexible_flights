# frozen_string_literal: true

module Flights
  module Amadeus
    class Client
      BASE_URLS = {
        test: "https://test.api.amadeus.com",
        production: "https://api.amadeus.com"
      }.freeze

      # Refresh the token this many seconds before it actually expires
      # to avoid race conditions during long sampling batches.
      TOKEN_EXPIRY_BUFFER_SECONDS = 60

      def initialize(client_id:, client_secret:, env: :test)
        @client_id = client_id
        @client_secret = client_secret
        @base_url = BASE_URLS.fetch(env)
        @token = nil
        @token_expires_at = Time.now
      end

      def flight_offers(params)
        response = api_connection.get("/v2/shopping/flight-offers") do |req|
          req.headers["Authorization"] = "Bearer #{fetch_token}"
          req.params = params
        end
        response.body
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
        # ConnectionFailed wraps Timeout::Error when WebMock (or the adapter) doesn't produce
        # a proper Faraday::TimeoutError. Re-raise as domain TimeoutError in both cases.
        raise Flights::TimeoutError, "Amadeus request timed out" if timeout_cause?(e)
        raise Flights::Error, "Amadeus connection failed: #{e.message}"
      rescue Faraday::UnauthorizedError
        raise Flights::AuthError, "Amadeus authentication failed"
      rescue Faraday::TooManyRequestsError
        raise Flights::RateLimitError, "Amadeus rate limit reached"
      rescue Faraday::Error => e
        raise Flights::Error, "Amadeus request failed: #{e.message}"
      end

      private

      def timeout_cause?(error)
        error.is_a?(Faraday::TimeoutError) ||
          error.respond_to?(:wrapped_exception) && error.wrapped_exception.is_a?(Timeout::Error)
      end

      def fetch_token
        refresh_token! if token_expired?
        @token
      end

      def token_expired?
        Time.now >= @token_expires_at - TOKEN_EXPIRY_BUFFER_SECONDS
      end

      def refresh_token!
        response = auth_connection.post("/v1/security/oauth2/token",
          "grant_type=client_credentials&client_id=#{@client_id}&client_secret=#{@client_secret}"
        )
        @token = response.body["access_token"]
        @token_expires_at = Time.now + response.body["expires_in"].to_i
      rescue Faraday::Error => e
        raise Flights::AuthError, "Amadeus token fetch failed: #{e.message}"
      end

      def api_connection
        @api_connection ||= Faraday.new(url: @base_url, request: { timeout: 10 }) do |f|
          f.response :json
          f.response :raise_error
          f.adapter :net_http
        end
      end

      def auth_connection
        @auth_connection ||= Faraday.new(url: @base_url, request: { timeout: 10 }) do |f|
          f.headers["Content-Type"] = "application/x-www-form-urlencoded"
          f.response :json
          f.response :raise_error
          f.adapter :net_http
        end
      end
    end
  end
end
