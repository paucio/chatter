# frozen_string_literal: true

class ChatroomsController < ApplicationController
  def index
    @chatrooms = Chatroom.all
  end

  def create
    @chatroom = Chatroom.create!(chatroom_params)
  end

  def show
    @chatroom = Chatroom.find(params[:id])
  end

  private

  def chatroom_params
    params.require(:chatroom).permit(:latitude, :longitude)
  end
end
