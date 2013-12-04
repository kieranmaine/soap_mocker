require 'sinatra/base'
require 'savon'
require 'nokogiri'
require 'equivalent-xml'
require 'mocha/api'
require 'active_support/core_ext/hash/conversions'
require 'thin'
require 'soap_mocker/xml_equals'
require 'soap_mocker/mock_soap_service_app'
require 'soap_mocker/logging'

module SoapMocker
  class MockServiceContainer
    include Mocha::API

    attr_reader :service_path, :webservice_url, :service_name, :port_name, :opts, :io_mock

    def initialize(wsdl_url, service_name, port_name, service_path, opts = {})
      @webservice_url = wsdl_url
      @service_name = service_name
      @port_name = port_name
      @service_path = service_path
      @opts = {:port => 4567}.merge(opts)

      @operations = MockSoapServiceApp::create_soap_operations_collection(@webservice_url, @service_name, @port_name)

      @io_mock = mock()
    end

    def mock_operation(op_name, with, returns, not_equals = false)
      matcher = not_equals ? lambda { |x| Not(xml_equals(x)) } : lambda { |x| xml_equals(x) }

      @io_mock.stubs(:call_op).with(op_name, matcher.call(MockSoapServiceApp.convert_hash_to_envelope(with, op_name, @operations).to_s)).returns(returns)
    end

    def run
      SoapMocker::Logging.logger.info "Your soapy mock is running on port #{@opts[:port]}"

      app = MockSoapServiceApp.new(@operations, @service_path, @io_mock)

      Rack::Handler::default.run(app, {:Port => @opts[:port]})
    end
  end
end