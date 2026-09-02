require "rails_helper"

RSpec.describe Message, type: :model do
  let(:chatroom) { Chatroom.create!(latitude: 45.0, longitude: 23.0) }
  subject(:message) { chatroom.messages.build(username: "alice", body: "hello") }

  it "is valid with a username and body" do
    expect(message).to be_valid
  end

  it "belongs to a chatroom" do
    message.chatroom = nil

    expect(message).not_to be_valid
    expect(message.errors[:chatroom]).to be_present
  end

  it "requires a username" do
    message.username = nil

    expect(message).not_to be_valid
    expect(message.errors[:username]).to be_present
  end

  it "requires a body" do
    message.body = nil

    expect(message).not_to be_valid
    expect(message.errors[:body]).to be_present
  end

  # Real-time delivery (broadcasts_to) relies on after_commit and is covered
  # end-to-end by the message system spec, not here.
end
