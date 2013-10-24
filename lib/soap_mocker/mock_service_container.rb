require 'sinatra/base'
require 'savon'
require 'nokogiri'
require 'equivalent-xml'
require 'mocha/api'
require 'active_support/core_ext/hash/conversions'
require 'thin'
require_relative 'xml_equals'
require_relative 'mock_service_app'

module SoapMocker
  include Mocha::API

  class MockServiceContainer

    attr_reader :service_path, :webservice_url, :service_name, :port_name, :opts, :io_mock


    def initialize(wsdl_url, service_name, port_name, service_path, opts = {})
      @operations = []

      @webservice_url = wsdl_url
      @service_name = service_name
      @port_name = port_name
      @service_path = service_path
      @opts = {:port => 3000}.merge(opts)

      client = Savon.new @webservice_url

      client.operations(@service_name, @port_name).each do |operation_name|
        op = client.operation(@service_name, @port_name, operation_name)

        @operations << {:name => operation_name, :soap_action => op.soap_action, :operation => op, :mocking => []}
      end

      @io_mock = mock()
    end

    def mock_operation(op_name, with, returns, not_equals = false)
      matcher = not_equals ? lambda { |x| Not(xml_equals(x)) } : lambda { |x| xml_equals(x) }

      @io_mock.stubs(:call_op).with(op_name, matcher.call(convert_hash_to_envelope(with, op_name).to_s)).returns(returns)
    end

    def run
      puts "Running on port: #{@opts[:port]}"
      MockServiceApp.new(@operations, @service_path, @io_mock) do |app|
        Rack::Handler::default.run(app, {:Port => @opts[:port]})
      end
    end

    def convert_hash_to_envelope(hash, operation_name)
      op = @operations.find { |x| x[:name] == operation_name }[:operation]
      op.body = hash
      Nokogiri.XML op.build.to_s
    end
  end
end