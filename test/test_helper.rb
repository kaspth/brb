# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "brb"

require "irb"
require "debug"
require "active_model"
require "minitest/autorun"

Minitest.backtrace_filter = Class.new do
  def filter(backtrace)
    backtrace.grep_v /gems\/(minitest|activesupport|actionview)/
  end
end.new

BRB.enable
BRB.debug if ENV["DEBUG"]

class Post
  include ActiveModel::Model

  def id = 1
  def title = "Super"
end
