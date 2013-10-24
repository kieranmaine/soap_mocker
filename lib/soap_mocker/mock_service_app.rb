require 'sinatra/base'
require 'savon'
require 'nokogiri'
require 'equivalent-xml'
require 'mocha/api'
require 'active_support/core_ext/hash/conversions'
require 'thin'
require_relative 'xml_equals'

module SoapMocker

  include Mocha::API

  class MockServiceApp < Sinatra::Base

    @service_path = "default"

    attr_accessor :service_path

    def MockServiceApp::get_xml_from_request_body(reqbod)
      xml = Nokogiri.XML(reqbod)
      xml.root.add_child Nokogiri::XML::Node.new("Header", xml) if xml.root.children.find { |x| x.name == "Header" }.nil?
      xml
    end

    def initialize(operations, service_path, io_mock)
      @operations = operations
      @service_path = service_path
      @io_mock = io_mock

      puts "MockServiceApp instantiated."
      puts "Service path: #{@service_path}"

      super()
    end

    get "/" do
      "This is a SOAP mock service. Good luck."
    end

    get "/operations" do
      body_html = "<p>Operations count: #{@operations.size}</p>"

      @operations.each do |op|
        operation = op[:operation]
        operation.body = operation.example_body
        body_html << %{
        <p>
          <strong>Name:</strong> #{op[:name]}<br />
          <strong>SOAPAction:</strong> #{operation.soap_action}<br />
          <strong>Example request body:</strong> #{operation.example_body}<br />
          <strong>Example request envelope:</strong> #{operation.build.gsub("<", "&lt;").gsub(">", "&gt;")}<br />
          <strong>Example response body:</strong> #{operation.example_response_body}<br />
          <strong>Expectation:</strong> #{@io_mock}
        </p>}
      end

      body body_html
    end

    before "/mock/UkLocation.svc" do
      soap_action = request.env["HTTP_SOAPACTION"]
      halt 500, "SOAPAction header not present." if soap_action.nil?

      soap_action = soap_action.gsub "\"", ""
      @soap_op = @operations.find { |x| x[:soap_action] == soap_action }
      halt 500, "SOAPAction header not valid. See /operations for list of valid SOAP actions." if @soap_op.nil?
    end

    get "/mock/UkLocation.svc" do
      return @soap_op[:operation].example_response_body
    end

    post "/mock/UkLocation.svc" do
      request_body = request.body.read

      op = @soap_op[:operation]

      op.response_body = @io_mock.call_op(@soap_op[:name], MockServiceApp::get_xml_from_request_body(request_body).to_s)

      headers "Content-Type" => "text/xml; charset=utf-8"
      body op.build_response
    end



  end
end