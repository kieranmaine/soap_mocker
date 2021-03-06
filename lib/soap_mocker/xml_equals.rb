require 'mocha/parameter_matchers/base'
require 'nokogiri'
require 'equivalent-xml'

module Mocha
  module ParameterMatchers
    def xml_equals(value)
      XmlEquals.new(value)
    end

    class XmlEquals < Base
      # @private
      def initialize(value)
        @value = value
      end

      # @private
      def matches?(available_parameters)
        parameter = available_parameters.shift
        #@value.remove_namespaces!
        #parameter.remove_namespaces!

        EquivalentXml.equivalent? @value, parameter, opts = {:element_order => false, :normalize_whitespace => true }
      end

      # @private
      def mocha_inspect
        @value.mocha_inspect
      end
    end
  end
end