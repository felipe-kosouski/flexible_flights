# frozen_string_literal: true

module ApplicationHelper
  # Shared pricing pack metadata used in payments/new and pages/home.
  # Keys map to CREDIT_PACKS constant symbols.
  def credit_pack_meta
    {
      pack_5: {
        label:       "Starter",
        description: t("payments.packs.starter_description"),
        badge:       nil,
        highlight:   false,
        usd:         "$2.99",
        brl:         "R$14,90",
        per_usd:     "$0.60",
        per_brl:     "R$2,98"
      },
      pack_15: {
        label:       "Explorer",
        description: t("payments.packs.explorer_description"),
        badge:       t("pages.home.pricing.most_popular"),
        highlight:   true,
        usd:         "$7.99",
        brl:         "R$39,90",
        per_usd:     "$0.53",
        per_brl:     "R$2,66"
      },
      pack_30: {
        label:       "Frequent Flyer",
        description: t("payments.packs.frequent_flyer_description"),
        badge:       t("pages.home.pricing.best_value"),
        highlight:   false,
        usd:         "$14.99",
        brl:         "R$74,90",
        per_usd:     "$0.50",
        per_brl:     "R$2,50"
      }
    }
  end

  def credit_chip_state(user)
    case user.search_credits
    when 0 then :empty
    when 1 then :low
    else :healthy
    end
  end
end
