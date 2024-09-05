class Tagging < ApplicationRecord
  belongs_to :tag
  belongs_to :bubble, touch: true
end
