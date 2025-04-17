class Cards::GoldnessesController < ApplicationController
  include CardScoped

  def create
    @card.gild
    rerender_card_container
  end

  def destroy
    @card.ungild
    rerender_card_container
  end

  private
    def rerender_card_container
      render turbo_stream: turbo_stream.replace([ @card, :card_container ], partial: "cards/container", locals: { card: @card.reload })
    end
end
