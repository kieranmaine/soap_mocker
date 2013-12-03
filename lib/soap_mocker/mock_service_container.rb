require 'sinatra/base'
require 'savon'
require 'nokogiri'
require 'equivalent-xml'
require 'mocha/api'
require 'active_support/core_ext/hash/conversions'
require 'thin'
require_relative 'xml_equals'
require_relative 'mock_soap_service_app'
require_relative 'logging'

module SoapMocker
  class MockServiceContainer
    include Mocha::API

    attr_reader :service_path, :webservice_url, :service_name, :port_name, :opts, :io_mock

    def initialize(wsdl_url, service_name, port_name, service_path, opts = {})
      @operations = []

      @webservice_url = wsdl_url
      @service_name = service_name
      @port_name = port_name
      @service_path = service_path
      @opts = {:port => 4567}.merge(opts)

      client = Savon.new @webservice_url

      client.operations(@service_name, @port_name).each do |operation_name|
        op = client.operation(@service_name, @port_name, operation_name)

        @operations << {:name => operation_name, :soap_action => op.soap_action, :operation => op, :mocking => []}
      end

      @io_mock = mock()
    end

    def mock_operation(op_name, with, returns, not_equals = false)
      MockServiceContainer.mock_operation(@io_mock, @operations, op_name, with, returns, not_equals)
    end

    def self.mock_operation(io_mock, operations, op_name, with, returns, not_equals = false)
      matcher = not_equals ? lambda { |x| Not(xml_equals(x)) } : lambda { |x| xml_equals(x) }

      io_mock.stubs(:call_op).with(op_name, matcher.call(MockServiceContainer.convert_hash_to_envelope(with, op_name, operations).to_s)).returns(returns)
    end

    def run
      SoapMocker::Logging.logger.info "Your soapy mock is running on port #{@opts[:port]}"

      app = MockSoapServiceApp.new(@operations, @service_path, @io_mock)

      Rack::Handler::default.run(app, {:Port => @opts[:port]})
    end

    def self.convert_hash_to_envelope(hash, operation_name, operations)
      self.convert_hash_to_envelope_for_operation hash, operations.find { |x| x[:name] == operation_name }[:operation]
    end

    def self.convert_hash_to_envelope_for_operation(hash, operation)
      operation.body = hash
      Nokogiri.XML operation.build.to_s
    end
  end
end