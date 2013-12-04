require 'sinatra/base'
require 'savon'
require 'nokogiri'
require 'equivalent-xml'
require 'mocha/api'
require 'active_support/core_ext/hash/conversions'
require 'thin'
require 'json'
require 'soap_mocker/xml_equals'
require 'soap_mocker/logging'

module SoapMocker

  class MockSoapServiceApp < Sinatra::Base

    include Mocha::API

    attr_reader :service_path
    attr_reader :mocks_per_operation
    attr_accessor :io_mock

    def app
      MockSoapServiceApp
    end

    configure do
      enable :logging
    end

    def get_xml_from_request_body(reqbod)
      xml = Nokogiri.XML(reqbod)
      xml.root.add_child Nokogiri::XML::Node.new("Header", xml) if xml.root.children.find { |x| x.name == "Header" }.nil?
      xml
    end

    def increment_mock_operation_count(op_name, returns, with)
      begin
        @io_mock.call_op(op_name, MockSoapServiceApp.convert_hash_to_envelope(with, op_name, @operations).to_s)
      rescue Mocha::ExpectationError
        @mocks_per_operation[op_name] = (@mocks_per_operation[op_name] || 0) + 1
      end
    end

    def self.create_soap_operations_collection(wsdl_file_or_url, service_name, port_name)
      client = Savon.new wsdl_file_or_url

      client.operations(service_name, port_name).map { |operation_name|
        op = client.operation(service_name, port_name, operation_name)
        {:name => operation_name, :soap_action => op.soap_action, :operation => op, :mocking => []}
      }
    end

    def self.convert_hash_to_envelope(hash, operation_name, operations)
      operation = operations.find { |x| x[:name] == operation_name }[:operation]
      operation.body = hash
      Nokogiri.XML operation.build.to_s
    end

    def initialize(operations = nil, service_path = nil, io_mock = mock())
      super()

      @operations = (operations || SoapMocker::MockSoapServiceApp.create_soap_operations_collection(settings.wsdl_file_or_url, settings.service_name, settings.port_name))
      @service_path = (service_path || settings.service_path).downcase
      @io_mock = io_mock
      @mocks_per_operation = {}

      SoapMocker::Logging.logger.info "Service path: #{@service_path}"
    end

    before do
      SoapMocker::Logging.logger.info(request.path)
      unless ["/", "/operations"].include?(request.path.downcase) or request.path =~ /operation\/(.)*\/mock/
        message_404 = "Nothing exists here. POST SOAP Actions to \"/mock/UkLocationSoapService\".  Go to <a href=\"/operations\">/operations</a> for list of valid operations and SOAP actions."
        halt 404, message_404 unless request.path.downcase == @service_path

        soap_action = request.env["HTTP_SOAPACTION"]
        halt 500, "SOAPAction header not present." if soap_action.nil?

        soap_action = soap_action.gsub "\"", ""
        @soap_op = @operations.find { |x| x[:soap_action] == soap_action }
        halt 500, "SOAPAction header not valid. Go to <a href=\"/operations\">/operations</a> for list of valid operations and SOAP actions." if @soap_op.nil?
      end
    end

    get "/" do
      "This is a SOAP mock service. Good luck."
    end

    get "/operations" do
      body_html = "<div id=\"operationsCount\">Operations count: #{@operations.size}</div>"

      @operations.each do |op|
        operation = op[:operation]
        operation.body = operation.example_body
        body_html << %{
        <div class=\"operation\">
          <strong>Name:</strong> #{op[:name]}<br />
          <strong># Mocked Ops:</strong> #{@mocks_per_operation[op[:name]] || 0}<br />
          <strong>SOAPAction:</strong> #{operation.soap_action}<br />
          <strong>Example request body:</strong> #{operation.example_body}<br />
          <strong>Example request envelope:</strong> #{operation.build.gsub("<", "&lt;").gsub(">", "&gt;")}<br />
          <strong>Example response body:</strong> #{operation.example_response_body}<br />
        </div>}
      end

      body "<html><body>#{body_html}</body></html>"
    end

    def self.mock_operation_call(i, o, not_equals, op_name, returns, with)

    end

    post "/operation/:operation_name/mock" do |op_name|
      unless @operations.any?{|x| x[:name] == op_name}
        halt 500, "Operation is not valid. Go to <a href=\"/operations\">/operations</a> for list of valid operations and SOAP actions."
      end

      json = JSON.parse request.body.read

      SoapMocker::Logging.logger.info json

      with = eval(json["with"])
      returns = eval(json["returns"])
      not_equals = json["not_equals"]

      increment_mock_operation_count(op_name, returns, with)

      matcher = not_equals ? lambda { |x| Not(xml_equals(x)) } : lambda { |x| xml_equals(x) }

      @io_mock.stubs(:call_op)
        .with(op_name, matcher.call(MockSoapServiceApp.convert_hash_to_envelope(with, op_name, @operations).to_s))
        .returns(returns)

      "Mock successfully set up"
    end

    get "/*" do
      body "Example response body: #{@soap_op[:operation].example_response_body}"
    end

    post "/*" do
      request_body = request.body.read

      op = @soap_op[:operation]

      op.response_body = @io_mock.call_op(@soap_op[:name], get_xml_from_request_body(request_body).to_s)

      headers "Content-Type" => "text/xml; charset=utf-8"
      body op.build_response
    end
  end
end