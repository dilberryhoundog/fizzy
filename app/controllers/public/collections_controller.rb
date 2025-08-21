class Public::CollectionsController < ApplicationController
  include PublicCollectionScoped

  allow_unauthenticated_access only: :show

  layout "public"

  def show
    @considering = current_page_from @collection.cards.considering.latest, per_page: CardsController::PAGE_SIZE
    @on_deck = current_page_from @collection.cards.on_deck.latest, per_page: CardsController::PAGE_SIZE
    @doing = current_page_from @collection.cards.doing.latest, per_page: CardsController::PAGE_SIZE
    @closed = current_page_from @collection.cards.closed.recently_closed_first, per_page: CardsController::PAGE_SIZE

    # To enable caching at intermediate proxies during traffic spikes
    expires_in 5.seconds, public: true
  end
end
