class StripeConfig
  def self.webhook_secret
    Rails.application.credentials.dig(:stripe, :webhook_secret)
  end
end
