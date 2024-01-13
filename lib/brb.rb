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

    def self.replace(key, value)
      @values.fetch(key).sub "\\1", value
    end

    def self.register(key, replacer)
      @values[key.to_s] = replacer
    end

    register :p, '<%= \1 %>'
    register :t, '<%= t "\1" %>'
    register :id, 'id="<%= dom_id(\1) %>"'
    register :class, 'class="<%= class_names(\1) %>"'
    register :attributes, '<%= tag.attributes(\1) %>'
    register :aria, '<%= tag.aria(\1) %>'
    register :data, '<%= tag.data(\1) %>'
    register :lorem, <<~end_of_lorem
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
    end_of_lorem
  end

  class Erubi < ::ActionView::Template::Handlers::ERB::Erubi
    # DEFAULT_REGEXP = /<%(={1,2}|-|\#|%)?(.*?)([-=])?%>([ \t]*\r?\n)?/m

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
      reset

      input = +""

      until @scanner.eos?
        # debugger
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
          case
          when @scanner.scan(/\#/) then @scanner.scan_until(/\r?\n/)
          when @scanner.scan(/\=/)
            input << "<%=" << @scanner.scan_until(/(?=<\/|\r?\n)/) << " %>"
          when @scanner.scan(/t(\.[\.\w]+)/)
            input << Sigil.replace("t", @scanner[1])
          when @scanner.scan(/(#{Sigil.names.join("|")})\(/)
            input << Sigil.replace(@scanner[1], @scanner.scan_until(/\)/).chomp(")"))
          when @scanner.scan_until(/(.*)(\r?\n)/)
            input << "<%" << @scanner[1] << "%>" << @scanner[2]
          end

          reset

          # match = @scanner.scan_until(/#|=|#{Sigils.names.join("\\b|")}|\n/)
          # case match.last
          # in "\n" then reset
          # in "#"  then @scanner.scan_until("\n") and reset
          # in "="  then @writing = true
          # else
          #   source = @scanner.scan_until Sigils.regex(match)
          #   writing? ? "<%= #{source} %>" : "<% #{source} %>"
          # end
        end
      end

      frontmatter = $1 if input.sub! /\A(.*?)~~~\n/m, ""
      backmatter  = $1 if input.sub! /~~~\n(.*?)\z/m, ""
      BRB.logger.debug { ["frontmatter", frontmatter] }
      BRB.logger.debug { ["backmatter", backmatter] }

      super
    end

    private def reset
      @mode, @writing = :start, false
    end
  end

  def self.enable
    ActionView::Template::Handlers::ERB.erb_implementation = BRB::Erubi
  end
end
