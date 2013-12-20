require 'sinatra/base'
require 'savon'
require 'nokogiri'
require 'equivalent-xml'
require 'mocha/api'
require 'active_support/core_ext/hash/conversions'
require 'thin'
require_relative 'mock_soap_service_app'
require_relative 'soap_service_settings'

module SoapMocker
  class MockServiceContainer
    include Mocha::API

    attr_accessor :io_mock

    def initialize(soap_services, opts = {})
      @soap_services = soap_services
      @opts = {:port => 4567}.merge(opts)
    end

    def mock_operation(soap_service, op_name, with, returns, not_equals = false)
      matcher = not_equals ? lambda { |x| Not(xml_equals(x)) } : lambda { |x| xml_equals(x) }

      soap_service.io_mock.stubs(:call_op).with(op_name, matcher.call(MockSoapServiceApp.convert_hash_to_envelope(with, soap_service.operations.find{|o| o[:name] == op_name}).to_s)).returns(returns)
    end

    def run
      SoapMocker::Logging.logger.info "Your soapy mock is running on port #{@opts[:port]}"

      MockSoapServiceApp.set :soap_services, @soap_services
      app = MockSoapServiceApp.new(@io_mock)

      Rack::Handler::default.run(app, {:Port => @opts[:port]})
    end
  end
end