# frozen_string_literal: true

class MessagesController < ApplicationController
  def create
    @chatroom = Chatroom.find(params[:chatroom_id])
    @message = @chatroom.messages.create!(message_params)

    # The message row reaches every subscriber (sender included) via the
    # broadcast; this response only resets the composer.
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  private

  def message_params
    params.require(:message).permit(:username, :body)
  end
end
