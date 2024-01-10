# frozen_string_literal: true

require "test_helper"

class BRBTest < ActionView::TestCase
  TestController.prepend_view_path "./test/partials"

  test "version number" do
    refute_nil ::BRB::VERSION
  end

  test "basic render" do
    render "basic", titles: [1,2,3]
    assert_equal "  <h1>1</h1>\n  <h1>2</h1>\n  <h1>3</h1>\n", rendered
  end

  test "sigils" do
    render "sigils"
    assert_equal <<~HTML, rendered
      class="active"
      data-controller="list" data-action="order"
    HTML
  end
end
