require 'rubygems'
require 'sinatra/base'
require 'savon'
require 'nokogiri'
require 'equivalent-xml'
require 'mocha/api'
require 'active_support/core_ext/hash/conversions'
require 'thin'
require_relative 'xml_equals'
require_relative 'mock_service_app'

include Mocha::API

class MockServiceContainer

  attr_reader :service_path, :webservice_url, :service_name, :port_name, :opts

  def MockServiceContainer::convert_hash_to_envelope(hash, operation_name, operations)
    op = operations.find { |x| x[:name] == operation_name }[:operation]
    op.body = hash
    Nokogiri.XML op.build.to_s
  end

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
    if not_equals
      @io_mock.stubs(:call_op).with(op_name, Not(xml_equals(MockServiceContainer::convert_hash_to_envelope(with, op_name, @operations)))).returns(returns)
    else
      @io_mock.stubs(:call_op).with(op_name, xml_equals(MockServiceContainer::convert_hash_to_envelope(with, op_name, @operations))).returns(returns)
    end
  end

  def run
    puts "Running on port: #{@opts[:port]}"
    MockServiceApp.new(@operations, @service_path, @io_mock) do |web|
      Rack::Handler::Thin.run(web, {:Port => @opts[:port]})
    end
  end
end

