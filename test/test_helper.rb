# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "brb"

require "minitest/autorun"

BRB.enable
BRB.debug if ENV["DEBUG"]
