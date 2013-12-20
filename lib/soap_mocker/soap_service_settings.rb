require 'savon'
require 'mocha/api'

module SoapMocker
  class SoapServiceSettings
    attr_accessor :mocks_per_operation
    attr_reader :service_path, :wsdl_file_or_url, :service_name, :port_name, :io_mock

    def initialize(service_path, wsdl_file_or_url, service_name, port_name)
      @service_path = service_path
      @wsdl_file_or_url = wsdl_file_or_url
      @service_name = service_name
      @port_name = port_name
      @mocks_per_operation = {}
      @io_mock = mock()
    end

    def create_soap_operations_collection
      client = Savon.new @wsdl_file_or_url

      client.operations(@service_name, @port_name).map { |operation_name|
        op = client.operation(@service_name, @port_name, operation_name)
        {:name => operation_name, :soap_action => op.soap_action, :operation => op, :mocking => [], :mock_count => 0}
      }
    end

    def operations
      @operations ||= create_soap_operations_collection
    end
  end
end