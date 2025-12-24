json.cache! event do
  json.(event, :id, :action)
  json.created_at event.created_at.utc
  json.particulars event.particulars

  json.board event.board, partial: "boards/board", as: :board
  json.creator event.creator, partial: "users/user", as: :user

  json.eventable_type event.eventable_type

  case event.eventable
  when Card
    json.card event.eventable, partial: "cards/card", as: :card
  when Comment
    json.comment event.eventable, partial: "cards/comments/comment", as: :comment
    json.card event.eventable.card, partial: "cards/card", as: :card
  end
end