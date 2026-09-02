# frozen_string_literal: true

class Chatroom < ApplicationRecord
  has_many :messages, dependent: :destroy

  validates :title, presence: true
  validates :latitude, presence: true,
    numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true,
    numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }

  before_validation :set_default_title, on: :create

  private

  def set_default_title
    self.title = "Chatroom #{Chatroom.count + 1}" if title.blank?
  end
end
