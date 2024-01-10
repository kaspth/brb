# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "brb"

require "active_model"
require "minitest/autorun"

BRB.enable
BRB.debug if ENV["DEBUG"]

class Post
  include ActiveModel::Model

  def id = 1
  def title = "Super"
end
