# frozen_string_literal: true

require "test_helper"
require "irb"
require "debug"

class BRBTest < ActionView::TestCase
  TestController.prepend_view_path "./test/partials"

  class ActionView::Helpers::TagHelper::TagBuilder
    def aria(**options) = attributes(aria: options)
    def data(**options) = attributes(data: options)
  end

  test "version number" do
    refute_nil ::BRB::VERSION
  end

  test "basic render" do
    render "basic", titles: [1,2]
    assert_equal <<~HTML, rendered
        <h1>1</h1><span>1</span>1
        <h1>2</h1><span>2</span>2

      <div>
      YO</div>
    HTML
  end

  test "sigils" do
    render "sigils", post: Post.new
    assert_equal <<~HTML, rendered
      <span>Super</span>
      id="post_1"
      class="active"
      aria-describedby="post_1"
      data-controller="list" data-action="order"

      <span class="translation_missing" title="translation missing: en._sigils.message">Message</span>
      <span class="translation_missing" title="translation missing: en.fully.qualified.message">Message</span>
      <span class="translation_missing" title="translation missing: en.Some bare words">Some Bare Words</span>
    HTML
  end

  test "matter" do
    render "matter"
    assert_equal <<~HTML, rendered

    <h1></h1>

    HTML
  end
end
