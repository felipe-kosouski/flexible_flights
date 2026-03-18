# app/support/locale_resolver.rb
class LocaleResolver
  SUPPORTED = %w[en pt-BR].freeze
  DEFAULT = "en".freeze

  def self.resolve(user: nil, session_locale: nil, accept_language: nil)
    from_user(user) ||
      from_session(session_locale) ||
      from_header(accept_language) ||
      DEFAULT
  end

  private_class_method def self.from_user(user)
    return nil unless user&.preferred_locale
    supported?(user.preferred_locale) ? user.preferred_locale : nil
  end

  private_class_method def self.from_session(session_locale)
    supported?(session_locale) ? session_locale.to_s : nil
  end

  private_class_method def self.from_header(header)
    return nil unless header
    # Quality values (q=) are intentionally ignored — positional order is sufficient
    # for a 2-locale app where most headers list preferred locale first.
    # Regional subtags (e.g., en-US) are normalised to the base language (en) when no
    # exact match is found.
    locales = header.split(",").map { |l| l.split(";").first.strip }
    locales.find { |l| supported?(l) } ||
      locales.map { |l| l.split("-").first }.find { |l| supported?(l) }
  end

  private_class_method def self.supported?(locale)
    SUPPORTED.include?(locale.to_s)
  end
end
