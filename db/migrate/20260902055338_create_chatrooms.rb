class CreateChatrooms < ActiveRecord::Migration[8.1]
  def change
    create_table :chatrooms do |t|
      t.float :latitude, null: false
      t.float :longitude, null: false
      t.string :title, null: false

      t.timestamps
    end
  end
end
