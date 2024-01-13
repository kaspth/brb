# frozen_string_literal: true

require "action_view"
require_relative "brb/version"

module BRB
  class ::ActionView::Helpers::TagHelper::TagBuilder
    def aria(**options) = attributes(aria: options)
    def data(**options) = attributes(data: options)
  end

  singleton_class.attr_accessor :logger
  @logger = Logger.new "/dev/null"
  def self.debug = @logger = Logger.new(STDOUT)

  def self.enable = ActionView::Template::Handlers::ERB.erb_implementation = BRB::Parser

  module Sigil
    def self.names = @values.keys
    @values = {}

    def self.replace(scanner, key)
      @values.fetch(key).then do |template|
        case
        when key == "t" && scanner.scan(/\.[\.\w]+/) then template.sub ":value", scanner.matched
        when scanner.check(/\(/) then template.sub ":value", scan_arguments(scanner)
        else
          template
        end
      end
    end

    def self.scan_arguments(scanner)
      arguments, open_parens = +"", 0

      begin
        arguments << scanner.scan_until(/\(|\)/)
        open_parens += arguments.last == "(" ? 1 : -1
      end until open_parens.zero?

      arguments[1..-2]
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

  class Parser < ::ActionView::Template::Handlers::ERB::Erubi
    def initialize(input, ...)
      frontmatter = $1 if input.sub! /\A(.*?)~~~\n/m, ""
      backmatter  = $1 if input.sub! /~~~\n(.*?)\z/m, ""

      @scanner = StringScanner.new(input)
      input    = +""
      @mode    = :start

      if @mode == :start
        if scan = @scanner.scan_until(/(?=\\)/)
          input << scan
          @scanner.skip(/\\/)
          @mode = :open
        else
          input << @scanner.rest
          @scanner.terminate
        end
      else
        case token = @scanner.scan(/#|=|#{Sigil.names.join("\\b|")}\b/)
        when "#"          then @scanner.scan_until(/\n/)
        when *Sigil.names then input << Sigil.replace(@scanner, token)
        when "="          then input << "<%=" << @scanner.scan_until(/(?=<\/|\r?\n)/) << " %>"
        else
          @scanner.scan_until(/(?=\r?\n)/)&.then { input << "<% " << _1 << " %>" }
        end

        @mode = :start
      end until @scanner.eos?

      super
    end
  end
end
