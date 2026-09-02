class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :chatroom, null: false, foreign_key: true
      t.string :username, null: false
      t.text :body, null: false

      t.timestamps
    end
  end
end
