# frozen_string_literal: true

Rack::Attack.cache.store = Rails.cache

# Rule 1: Throttle login attempts by IP
# Prevents automated login attempts from a single IP.
Rack::Attack.throttle("logins/ip", limit: 10, period: 20.seconds) do |req|
  req.ip if req.path == "/users/sign_in" && req.post?
end

# Rule 2: Throttle login attempts by email
# Tighter limit per email — prevents targeting specific accounts across multiple IPs.
Rack::Attack.throttle("logins/email", limit: 5, period: 20.seconds) do |req|
  if req.path == "/users/sign_in" && req.post?
    req.params.dig("user", "email")&.downcase&.strip
  end
end

# Rule 3: Throttle signups by IP
# Prevents account farming to exploit the 1 free search per account.
Rack::Attack.throttle("signups/ip", limit: 5, period: 60.seconds) do |req|
  req.ip if req.path == "/users" && req.post?
end

# Rule 4: Throttle search creation by user
# Prevents job queue flooding from a single authenticated user.
# Key: Warden stores [[user_id], salt] — dig(0, 0) extracts the user ID.
# Returns nil for unauthenticated requests (no session key → no throttle key → not throttled).
Rack::Attack.throttle("searches/user", limit: 3, period: 60.seconds) do |req|
  if req.path == "/searches" && req.post?
    # rack.session may be nil if CookieStore hasn't decoded the cookie yet at this
    # middleware position — safe navigation prevents NoMethodError on unauthenticated requests.
    req.env["rack.session"]&.dig("warden.user.user.key", 0, 0)
  end
end
