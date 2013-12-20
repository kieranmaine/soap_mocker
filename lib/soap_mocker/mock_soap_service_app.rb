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

    def increment_mock_operation_count(soap_service, operation, with)
      begin
        soap_service.io_mock.call_op(operation[:name], MockSoapServiceApp.convert_hash_to_envelope(with, operation).to_s)
      rescue Mocha::ExpectationError
        operation[:mock_count] = (operation[:mock_count] || 0) + 1
      end
    end

    def self.convert_hash_to_envelope(hash, operation)
      operation[:operation].body = hash
      Nokogiri.XML operation[:operation].build.to_s
    end

    def self.valid_operations_request?(request_path)
      settings.soap_services.any?{|s| request_path == "#{s.service_path}/operations".downcase }
    end

    before do
      SoapMocker::Logging.logger.info(request.path)

      unless request.path.downcase == "/" or MockSoapServiceApp.valid_operations_request?(request.path.downcase) or request.path =~ /\/(.)*\/operation\/(.)*\/mock/
        message_404 = "Nothing exists here. Go to <a href=\"/\">/</a> to view a list of services. Go to <a href=\"/{service_path}/operations\">/{service_path}/operations</a> for list of valid operations and SOAP actions for a specific service."
        halt 404, message_404 unless settings.soap_services.any?{|s| s.service_path.downcase == request.path.downcase}

        soap_action = request.env["HTTP_SOAPACTION"]
        halt 500, "SOAPAction header not present." if soap_action.nil?

        soap_action = soap_action.gsub "\"", ""
        soap_service = settings.soap_services.find{ |s| s.service_path.downcase == request.path.downcase }
        @io_mock = soap_service.io_mock
        @soap_op = soap_service.operations.find { |x| x[:soap_action] == soap_action }
        halt 500, "SOAPAction header not valid. Go to <a href=\"/operations\">/operations</a> for list of valid operations and SOAP actions." if @soap_op.nil?
      end
    end

    get "/" do
      "<p>This is a SOAP mock service. The following SOAP services have been mocked:</p>" +
          "<p><ul>#{settings.soap_services.map { |s| "<li>#{s.service_name} - Path: #{s.service_path}</li>" }.sort.join}</ul></p>"
    end

    get "*/operations" do |service_path|
      operations = settings.soap_services.find{|s| s.service_path.downcase == service_path.downcase}.operations

      body_html = "<div id=\"operationsCount\">Operations count: #{operations.size}</div>"
      body_html << "<ul class=\"operations\">"

      operations.each do |op|
        operation = op[:operation]
        operation.body = operation.example_body
        body_html << %{
        <li class=\"operation\">
          <ul>
            <li><strong>Name:</strong> #{op[:name]}</li>
            <li><strong># Mocked Ops:</strong> #{op[:mock_count]}</li>
            <li><strong>SOAPAction:</strong> #{operation.soap_action}</li>
            <li><strong>Example request body:</strong> #{operation.example_body}</li>
            <li><strong>Example request envelope:</strong> #{operation.build.gsub("<", "&lt;").gsub(">", "&gt;")}</li>
            <li><strong>Example response body:</strong> #{operation.example_response_body}</li>
          </ul>
        </li>}
      end

      body_html << "</ul>"
      body "<html><body>#{body_html}</body></html>"
    end

    def self.mock_operation_call(i, o, not_equals, op_name, returns, with)

    end

    post "*/operation/*/mock" do |service_path, op_name|
      soap_service = settings.soap_services.find { |s| s.service_path == service_path }
      operations = soap_service.operations

      operation = operations.find{|o|o[:name] == op_name}

      if operation.nil?
        halt 500, "Operation is not valid. Go to <a href=\"#{soap_service.service_path}/operations\">#{soap_service.service_path}/operations</a> for list of valid operations and SOAP actions."
      end

      json = JSON.parse request.body.read

      SoapMocker::Logging.logger.info json

      with = eval(json["with"])
      returns = eval(json["returns"])
      not_equals = json["not_equals"]

      increment_mock_operation_count(soap_service, operation, with)

      matcher = not_equals ? lambda { |x| Not(xml_equals(x)) } : lambda { |x| xml_equals(x) }

      soap_service.io_mock.stubs(:call_op).with(op_name, matcher.call(MockSoapServiceApp.convert_hash_to_envelope(with, operation).to_s)).returns(returns)

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