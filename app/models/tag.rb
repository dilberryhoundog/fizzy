class Tag < ApplicationRecord
  #belongs_to :account

  has_many :taggings, dependent: :destroy
  has_many :bubbles, through: :taggings

  normalizes :title, with: ->(value) { value.to_s }
end
