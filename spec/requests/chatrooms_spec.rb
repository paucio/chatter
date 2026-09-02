require "rails_helper"

RSpec.describe "Chatrooms", type: :request do
  let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

  describe "GET /" do
    it "renders the map with the existing pins" do
      Chatroom.create!(latitude: 45.0, longitude: 23.0)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="map"')
      expect(response.body).to include('data-map-target="marker"')
    end
  end

  describe "POST /chatrooms" do
    let(:params) { { chatroom: { latitude: 45.5, longitude: 23.7 } } }

    it "creates a chatroom at the clicked coordinates" do
      expect {
        post chatrooms_path, params: params, headers: turbo_headers
      }.to change(Chatroom, :count).by(1)

      chatroom = Chatroom.last
      expect(chatroom.latitude).to eq(45.5)
      expect(chatroom.longitude).to eq(23.7)
      expect(chatroom.title).to eq("Chatroom 1")
    end

    it "responds with a turbo stream carrying the new marker and panel" do
      post chatrooms_path, params: params, headers: turbo_headers

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('data-map-target="marker"')
      expect(response.body).to include("Chatroom 1")
    end

    it "ignores a client-supplied title" do
      post chatrooms_path,
        params: { chatroom: { latitude: 1.0, longitude: 2.0, title: "hacked" } },
        headers: turbo_headers

      expect(Chatroom.last.title).to eq("Chatroom 1")
    end

    it "does not create a chatroom for out-of-range coordinates" do
      expect {
        post chatrooms_path,
          params: { chatroom: { latitude: 200.0, longitude: 0.0 } },
          headers: turbo_headers
      }.not_to change(Chatroom, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /chatrooms/:id" do
    it "renders the chatroom panel inside the turbo frame" do
      chatroom = Chatroom.create!(latitude: 45.0, longitude: 23.0)
      chatroom.messages.create!(username: "alice", body: "first!")

      get chatroom_path(chatroom)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(chatroom.title)
      expect(response.body).to include("first!")
      expect(response.body).to include('id="panel"')
    end

    it "returns 404 for an unknown chatroom" do
      get chatroom_path(id: 0)

      expect(response).to have_http_status(:not_found)
    end
  end
end
