class Cards::ReadingsController < ApplicationController
  include CardScoped

  skip_writer_affinity

  def create
    @notifications = @card.read_by(Current.user)
  end
end
