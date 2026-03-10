# frozen_string_literal: true

module WebMockHelpers
  # Stubs a GET request to a URL, ignoring any query params.
  # Use this when the code under test appends params to the URL and
  # you want to match on the base path only.
  def stub_get(url, **options)
    stub_request(:get, /#{Regexp.escape(url)}/).tap do |stub|
      stub.to_return(**options) if options.any?
    end
  end
end

RSpec.configure do |config|
  config.include WebMockHelpers
end
