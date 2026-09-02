class Message < ApplicationRecord
  belongs_to :chatroom

  validates :username, :body, presence: true

  broadcasts_to :chatroom, target: "messages"
end
