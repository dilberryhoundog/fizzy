class Boost < ApplicationRecord
  belongs_to :splat
  belongs_to :creator, class_name: "User", default: -> { Current.user }
end
