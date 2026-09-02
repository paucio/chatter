require "rails_helper"

RSpec.describe "Messages", type: :request do
  let(:chatroom) { Chatroom.create!(latitude: 45.0, longitude: 23.0) }

  describe "POST /chatrooms/:chatroom_id/messages" do
    it "creates a message on the chatroom" do
      expect {
        post chatroom_messages_path(chatroom),
          params: { message: { username: "alice", body: "hello" } },
          as: :turbo_stream
      }.to change(chatroom.messages, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(chatroom.messages.last).to have_attributes(username: "alice", body: "hello")
    end

    it "responds with a turbo stream that resets the composer, keeping the username" do
      post chatroom_messages_path(chatroom),
        params: { message: { username: "alice", body: "hello" } },
        as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="replace"', 'id="message_form"')
      expect(response.body).to include('value="alice"')
    end

    it "returns 422 when the message is invalid" do
      expect {
        post chatroom_messages_path(chatroom), params: { message: { username: "alice", body: "" } }
      }.not_to change(Message, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 404 for an unknown chatroom" do
      post chatroom_messages_path(chatroom_id: 0), params: { message: { username: "a", body: "b" } }

      expect(response).to have_http_status(:not_found)
    end
  end
end
