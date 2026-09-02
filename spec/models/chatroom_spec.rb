require "rails_helper"

RSpec.describe Chatroom, type: :model do
  subject(:chatroom) { Chatroom.new(latitude: 45.0, longitude: 23.0) }

  it "is valid with in-range coordinates" do
    expect(chatroom).to be_valid
  end

  describe "title" do
    it "is auto-assigned as \"Chatroom N\" from the current count" do
      Chatroom.create!(latitude: 10.0, longitude: 10.0)

      chatroom.save!

      expect(chatroom.title).to eq("Chatroom 2")
    end

    it "keeps an explicitly provided title" do
      chatroom.title = "Named room"

      chatroom.save!

      expect(chatroom.title).to eq("Named room")
    end

    it "is required" do
      chatroom.save!
      chatroom.title = ""

      expect(chatroom).not_to be_valid
      expect(chatroom.errors[:title]).to be_present
    end
  end

  describe "latitude" do
    it "is required" do
      chatroom.latitude = nil

      expect(chatroom).not_to be_valid
      expect(chatroom.errors[:latitude]).to be_present
    end

    it "rejects values below -90" do
      chatroom.latitude = -90.001
      expect(chatroom).not_to be_valid
    end

    it "rejects values above 90" do
      chatroom.latitude = 90.001
      expect(chatroom).not_to be_valid
    end

    it "accepts the -90 and 90 boundaries" do
      expect(chatroom.tap { |c| c.latitude = -90 }).to be_valid
      expect(chatroom.tap { |c| c.latitude = 90 }).to be_valid
    end
  end

  describe "longitude" do
    it "is required" do
      chatroom.longitude = nil

      expect(chatroom).not_to be_valid
      expect(chatroom.errors[:longitude]).to be_present
    end

    it "rejects values below -180" do
      chatroom.longitude = -180.001
      expect(chatroom).not_to be_valid
    end

    it "rejects values above 180" do
      chatroom.longitude = 180.001
      expect(chatroom).not_to be_valid
    end

    it "accepts the -180 and 180 boundaries" do
      expect(chatroom.tap { |c| c.longitude = -180 }).to be_valid
      expect(chatroom.tap { |c| c.longitude = 180 }).to be_valid
    end
  end

  describe "messages association" do
    it "destroys its messages when destroyed" do
      chatroom.save!
      chatroom.messages.create!(username: "alice", body: "hi")

      expect { chatroom.destroy }.to change(Message, :count).by(-1)
    end
  end
end
