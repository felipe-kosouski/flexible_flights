require "webmock/rspec"

# Disable real HTTP connections in all specs.
# Provider specs use WebMock stubs explicitly.
WebMock.disable_net_connect!(allow_localhost: true)
