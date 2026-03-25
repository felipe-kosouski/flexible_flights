class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  stale_when_importmap_changes

  before_action :set_locale

  def after_sign_in_path_for(_resource)
    new_search_path
  end

  def after_sign_up_path_for(_resource)
    new_search_path
  end

  private

  def set_locale
    locale = LocaleResolver.resolve(
      user: current_user,
      session_locale: session[:locale],
      accept_language: request.env["HTTP_ACCEPT_LANGUAGE"]
    )
    session[:locale] = locale
    I18n.locale = locale
  end
end
