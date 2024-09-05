class Bubble < ApplicationRecord
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_many :comments, dependent: :destroy
  has_many :boosts, dependent: :destroy

  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

  has_one_attached :image, dependent: :purge_later

  enum :color, %w[
    #AF2E1B #CC6324 #3B4B59 #BFA07A #ED8008 #ED3F1C #BF1B1B #736B1E #D07B53
    #736356 #AD1D1D #BF7C2A #C09C6F #698F9C #7C956B #5D618F #3B3633 #67695E
  ].index_by(&:itself), suffix: true, default: "#698F9C"
end
