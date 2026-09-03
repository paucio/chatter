require "rails_helper"

RSpec.describe "Chatrooms", type: :system do
  it "creates a chatroom when the map is clicked" do
    visit root_path
    expect(page).to have_css("#map .leaflet-tile-loaded", wait: 10) # Leaflet ready

    find("#map").click

    within "#panel" do
      expect(page).to have_content("Chatroom 1")
    end
    expect(page).to have_css(".leaflet-marker-icon")
    expect(Chatroom.count).to eq(1)
  end

  it "opens a chatroom's panel when its marker is clicked" do
    Chatroom.create!(latitude: 50.0, longitude: 4.0)   # Chatroom 1
    Chatroom.create!(latitude: 46.0, longitude: 16.0)  # Chatroom 2

    visit root_path
    expect(page).to have_css(".leaflet-marker-icon", count: 2)

    all(".leaflet-marker-icon").last.click
    within("#panel") { expect(page).to have_content("Chatroom 2") }

    all(".leaflet-marker-icon").first.click
    within("#panel") { expect(page).to have_content("Chatroom 1") }

    # panel swaps in place — the map is still there
    expect(page).to have_css("#map")
  end

  it "delivers a posted message in real time and resets the composer" do
    chatroom = Chatroom.create!(latitude: 48.0, longitude: 10.0)

    Capybara.using_session("second viewer") do
      visit chatroom_path(chatroom)
    end

    visit chatroom_path(chatroom)
    fill_in "Write your user name here", with: "Alice"
    fill_in "Write your message here", with: "Hello everyone"
    click_button "Submit"

    within "#messages" do
      expect(page).to have_content("Alice")
      expect(page).to have_content("Hello everyone")
    end
    expect(page).to have_field("Write your message here", with: "")
    expect(page).to have_field("Write your user name here", with: "Alice")

    Capybara.using_session("second viewer") do
      within "#messages" do
        expect(page).to have_content("Hello everyone")
      end
    end
  end

  it "rebuilds the map cleanly after a Turbo navigation" do
    Chatroom.create!(latitude: 48.0, longitude: 10.0)
    visit root_path
    expect(page).to have_css(".leaflet-marker-icon")

    page.execute_script("Turbo.visit(window.location.href)")

    expect(page).to have_css("#map .leaflet-tile-loaded", wait: 10)
    expect(page).to have_css(".leaflet-marker-icon")           # markers replaced, not doubled
    expect(page).to have_css(".leaflet-marker-icon", count: 1)
  end
end
