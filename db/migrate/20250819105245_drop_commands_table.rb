class DropCommandsTable < ActiveRecord::Migration[8.1]
  def change
    drop_table :commands, if_exists: true
  end
end
