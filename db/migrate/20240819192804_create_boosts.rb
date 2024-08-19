class CreateBoosts < ActiveRecord::Migration[8.0]
  def change
    create_table :boosts do |t|
      t.string :content
      t.integer :creator_id, null: false
      t.references :splat, null: false

      t.timestamps
    end
  end
end
