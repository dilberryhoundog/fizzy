class RenameCategoriesToTags < ActiveRecord::Migration[8.0]
  def change
    rename_table :categories, :tags
    rename_table :categorizations, :taggings

    rename_column :taggings, :category_id, :tag_id
  end
end
