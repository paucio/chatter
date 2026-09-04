require "rails_helper"

RSpec.describe "Chatrooms", type: :request do
  let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

  # The chatrooms/_marker partial is the single source of truth for the data
  # attributes map_controller.js reads off each marker; assert the whole contract.
  def marker_in(body)
    Nokogiri::HTML(body).at_css('[data-map-target="marker"]')
  end

  describe "GET /" do
    it "renders the map with the existing pins" do
      chatroom = Chatroom.create!(latitude: 45.0, longitude: 23.0)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="map"')

      marker = marker_in(response.body)
      expect(marker["data-chatroom-id"]).to eq(chatroom.id.to_s)
      expect(marker["data-latitude"]).to eq("45.0")
      expect(marker["data-longitude"]).to eq("23.0")
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
      expect(chatroom.title).to eq("Chatroom #{chatroom.id}")
    end

    it "responds with a turbo stream carrying the new marker and panel" do
      post chatrooms_path, params: params, headers: turbo_headers
      chatroom = Chatroom.last

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('<turbo-stream action="append" target="map">')
      expect(response.body).to include('<turbo-stream action="update" target="panel">')
      expect(response.body).to include(chatroom.title)

      marker = marker_in(response.body)
      expect(marker["data-chatroom-id"]).to eq(chatroom.id.to_s)
      expect(marker["data-latitude"]).to eq("45.5")
      expect(marker["data-longitude"]).to eq("23.7")
    end

    it "ignores a client-supplied title" do
      post chatrooms_path,
        params: { chatroom: { latitude: 1.0, longitude: 2.0, title: "hacked" } },
        headers: turbo_headers

      chatroom = Chatroom.last
      expect(chatroom.title).to eq("Chatroom #{chatroom.id}")
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
