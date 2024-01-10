# frozen_string_literal: true

require "test_helper"

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
    render "basic", titles: [1,2,3]
    assert_equal "  <h1>1</h1>\n  <h1>2</h1>\n  <h1>3</h1>\n", rendered
  end

  test "sigils" do
    render "sigils", title: "Super"
    assert_equal <<~HTML, rendered
      <span>Super</span>
      class="active"
      data-controller="list" data-action="order"
      aria-describedby="post_1"
    HTML
  end
end
