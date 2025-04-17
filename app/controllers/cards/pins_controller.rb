class Cards::PinsController < ApplicationController
  include CardScoped

  def show
  end

  def create
    pin = @card.pin_by Current.user
    broadcast_add_to_tray pin
  end

  def destroy
    pin = @card.unpin_by Current.user
    broadcast_remove_from_tray pin
  end

  private
    def broadcast_add_to_tray(pin)
      pin.broadcast_prepend_to [ Current.user, :pins_tray ], target: "pins", partial: "my/pins/pin"
    end

    def broadcast_remove_from_tray(pin)
      pin.broadcast_remove_to [ Current.user, :pins_tray ]
    end
end
