# frozen_string_literal: true

require "action_view"
require_relative "brb/version"

module BRB
  singleton_class.attr_accessor :logger
  @logger = Logger.new "/dev/null"

  def self.debug
    @logger = Logger.new STDOUT
  end

  # Here's BRB with preprocessing sigils. Sigils aim to make actions common in an HTML context easier to write.
  # At template compile time the sigils are `gsub`'ed into their replacements.
  #
  # They follow this syntax, here `sigil_name` is the name of the Sigil:
  #
  #   \sigil_name # A sigil with no arguments
  #   \sigil_name(< ruby expression >) # A sigil with arguments, must be called with ()
  #
  # Examples:
  #
  #   \p(post.options) -> <%= post.options %>
  #   \id(post) -> id=<%= dom_id(post) %>
  #   \class(active: post.active?) -> class="<%= class_names(active: post.active?) %>"
  #   \attributes(post.options) -> <%= tag.attributes(post.options) %>
  #   \data(controller: :list) -> <%= tag.data(controller: :list) %>
  #   \aria(describedby: :post_1) -> <%= tag.aria(describedby: :post_1) %>
  #   \lorem -> Lorem ipsum dolor sit amet…
  #
  # There's also a `t` sigil, but that's a little more involved since there's some extra things to condense:
  #
  #   \t.message -> <%= t ".message" %>
  #   \t(fully.qualified.message) -> <%= t "fully.qualified.message" %>
  #   \t(Some bare words) -> <%= t "Some bare words" %> # Assumes we're using a gettext I18n backend, coming later!
  module Sigil
    def self.names = @values.keys
    @values = {}

    def self.replace(scanner, key)
      @values.fetch(key).then do |template|
        if (key == "t" && scanner.scan(/(\.[\.\w]+)/)) || scanner.scan(/\((.*?)\)/)
          template.sub ":value", scanner[1]
        else
          template
        end
      end
    end

    def self.register(key, replacer)
      @values[key.to_s] = replacer
    end

    register :p, '<%= :value %>'
    register :t, '<%= t ":value" %>'
    register :id, 'id="<%= dom_id(:value) %>"'
    register :class, 'class="<%= class_names(:value) %>"'
    register :attributes, '<%= tag.attributes(:value) %>'
    register :aria, '<%= tag.aria(:value) %>'
    register :data, '<%= tag.data(:value) %>'
    register :lorem, <<~end_of_lorem
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
    end_of_lorem
  end

  class Erubi < ::ActionView::Template::Handlers::ERB::Erubi
    # BRB aims to be a simpler syntax, but still a superset of ERB, that's aware of the context we're in: HTML.
    #
    # We're replacing <% %>, <%= %>, and <%# %> with \, \= and \# — these are self-terminating expressions.
    #
    # So this ERB:
    #
    #   <%# Some comment. %>
    #   <% posts.each do |post| %>
    #     <h1><%= post.title %></h1>
    #   <% end %>
    #
    # Can be this in BRB:
    #
    #   \# Some comment.
    #   \posts.each do |post|
    #     <h1>\= post.title</h1>
    #   \end
    #
    # Note: you can also do `\ posts.each` and `\ end`, it just feels a little nicer to nestle.
    #
    # We recognize every line starting with \ or \# as pure Ruby lines so we terminate on \n and convert to `<% %>`.
    # Same goes for \= except we also terminate on `</`, and then convert to `<%= %>`.
    #
    # Use `\p(post.title)` for multiple statements on the same line or to otherwise disambiguate statements.
    def initialize(input, ...)
      BRB.logger.debug { input }

      @scanner = StringScanner.new(input)
      @mode = :start

      input = +""

      until @scanner.eos?
        case @mode
        in :start
          if scan = @scanner.scan_until(/(?=\\)/)
            input << scan
            @scanner.skip(/\\/)
            @mode = :open
          else
            input << @scanner.rest
            @scanner.terminate
          end
        in :open
          case token = @scanner.scan(/#|=|#{Sigil.names.join("\\b|")}\b/)
          when "#" then @scanner.scan_until(/\n/)
          when "=" then input << "<%=" << @scanner.scan_until(/(?=<\/|\r?\n)/) << " %>"
          when *Sigil.names
            input << Sigil.replace(@scanner, token)
          else
            @scanner.scan_until(/(?=\r?\n)/)&.then { input << "<% " << _1 << " %>" }
          end

          @mode = :start
        end
      end

      frontmatter = $1 if input.sub! /\A(.*?)~~~\n/m, ""
      backmatter  = $1 if input.sub! /~~~\n(.*?)\z/m, ""
      BRB.logger.debug { ["frontmatter", frontmatter] }
      BRB.logger.debug { ["backmatter", backmatter] }

      super
    end
  end

  def self.enable
    ActionView::Template::Handlers::ERB.erb_implementation = BRB::Erubi
  end
end
