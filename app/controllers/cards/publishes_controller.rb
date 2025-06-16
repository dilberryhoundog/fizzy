class Cards::PublishesController < ApplicationController
  include CardScoped

  def create
    @card.publish

    if add_another_param?
      redirect_to @collection.cards.create!, notice: "Card added"
    else
      redirect_to @card
    end
  end

  private
    def add_another_param?
      params[:creation_type] == "add_another"
    end
end
