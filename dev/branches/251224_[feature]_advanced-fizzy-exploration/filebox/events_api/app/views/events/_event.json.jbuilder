json.cache! event do
  json.(event, :id, :action)
  json.created_at event.created_at.utc

  # Include particulars - critical for column tracking
  # Structure varies by action type, e.g.:
  #   card_triaged: { "particulars" => { "column" => "In Progress" } }
  #   card_board_changed: { "particulars" => { "old_board" => "...", "new_board" => "..." } }
  #   card_title_changed: { "particulars" => { "old_title" => "...", "new_title" => "..." } }
  json.particulars event.particulars

  json.board event.board, partial: "boards/board", as: :board
  json.creator event.creator, partial: "users/user", as: :user

  # Polymorphic eventable handling
  json.eventable_type event.eventable_type

  case event.eventable
  when Card
    json.card do
      json.partial! "cards/card", card: event.eventable
    end
  when Comment
    json.comment do
      json.partial! "cards/comments/comment", comment: event.eventable
    end
    # Also include the parent card for comments
    json.card do
      json.partial! "cards/card", card: event.eventable.card
    end
  end

  json.url polymorphic_url(event.eventable)
end
