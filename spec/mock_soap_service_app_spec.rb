require "bundler"
Bundler.setup(:default, :development)

ENV['RACK_ENV'] = 'test'

require "soap_mocker"
require "rspec"
require "rack/test"
require "logging"
require "mocha/api"

include Mocha::API

describe SoapMocker::MockSoapServiceApp do

  before (:each) do
    SoapMocker::Logging.logger.level = Logger::FATAL

    @service_name, @port_name = "UKLocation", "UKLocationSoap"
    client = Savon.new File.read(File.join(File.dirname(__FILE__), "/wsdl/uklocation.wsdl"))

    operations = client.operations(@service_name, @port_name).map { |operation_name|
      op = client.operation(@service_name, @port_name, operation_name)
      {:name => operation_name, :soap_action => op.soap_action, :operation => op, :mocking => []}
    }

    @app = SoapMocker::MockSoapServiceApp.new operations, "/mock/UkLocationSoapService", Mocha::API::mock()

    @browser = Rack::Test::Session.new(Rack::MockSession.new(@app))
  end

  context "'/' requested" do
    it "should return a message" do
      @browser.get "/"

      expect(@browser.last_response).to be_ok
      expect(@browser.last_response.body).to eq("This is a SOAP mock service. Good luck.")
    end
  end

  context "When a mock operation is called" do
    describe "with an incorrect service path" do
      before do
        request_body = %Q{
          <env:Envelope xmlns:lol0="http://www.webserviceX.NET" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Body></env:Body>
          </env:Envelope>}

        @browser.post "/incorrect_service_path", request_body
      end

      it "should return a 404 status code" do
        expect(@browser.last_response).to_not be_ok
        expect(@browser.last_response.status).to eq 404
      end

      it "should return a message directing the user to the correct service path" do
        expect(@browser.last_response.body).to eq "Nothing exists here. POST SOAP Actions to \"/mock/UkLocationSoapService\".  Go to <a href=\"/operations\">/operations</a> for list of valid operations and SOAP actions."
      end
    end
  end

  context "When a mock operation is called" do
    describe "without a SOAPAction header" do
      before do
        request_body = %Q{
          <env:Envelope xmlns:lol0="http://www.webserviceX.NET" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Body></env:Body>
          </env:Envelope>}

        @browser.post "/mock/UkLocationSoapService", request_body
      end

      it "should return a 500 status code" do
        expect(@browser.last_response).to_not be_ok
        expect(@browser.last_response.status).to eq 500
      end

      it "should return message indicating SOAPAction header required." do
        expect(@browser.last_response.body).to eq "SOAPAction header not present."
      end
    end
  end

  context "When a mock operation is called" do
    describe "with an invalid SOAPAction header" do
      before do
        request_body = %Q{
          <env:Envelope xmlns:lol0="http://www.webserviceX.NET" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Body></env:Body>
          </env:Envelope>}

        @browser.post "/mock/UkLocationSoapService", request_body, {"HTTP_SOAPACTION" => "SOAP_ACTION_DOES_NOT_EXIST", "CONTENT_TYPE" => "text/xml"}
      end

      it "should return a 500 status code" do
        expect(@browser.last_response).to_not be_ok
        expect(@browser.last_response.status).to eq 500
      end

      it "should return a message indicating SOAPAction invalid" do
        expect(@browser.last_response.body).to eq "SOAPAction header not valid. Go to <a href=\"/operations\">/operations</a> for list of valid operations and SOAP actions."
      end
    end
  end

  context "When an not existent operation is mocked" do
    before do
      @browser.post "/operation/OPERATION_DOES_NOT_EXIST/mock"
    end

    it "should return a 500 status" do
      expect(@browser.last_response).to_not be_ok
      expect(@browser.last_response.status).to eq 500
    end

    it "should return a message indicating operation is invalid" do
      expect(@browser.last_response.body).to eq "Operation is not valid. Go to <a href=\"/operations\">/operations</a> for list of valid operations and SOAP actions."
    end
  end

  context "When a valid operation is mocked" do
    before do
      fields = %Q{{
            "with": "{:GetUKLocationByPostCode => {:PostCode => \\"SW1A 0AA\\"}}",
            "returns": "{:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => \\"House Of Commons, London, SW1A 0AA, United Kingdom\\"}}",
            "not_equals": false
          }}

      @browser.post "/operation/GetUKLocationByPostCode/mock", fields
    end

    it "should return a success message" do
      expect(@browser.last_response).to be_ok
      expect(@browser.last_response.body).to eq("Mock successfully set up")
    end

    it "should increment the mocks_per_operation count" do
      expect(@app.helpers.mocks_per_operation["GetUKLocationByPostCode"]).to eq 1
    end

    describe "When the mocked operation is called with a specified parameter" do
      it "should return the specified value" do
        request_body = %Q{
          <env:Envelope xmlns:lol0="http://www.webserviceX.NET" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Header></env:Header>
            <env:Body>
              <lol0:GetUKLocationByPostCode><lol0:PostCode>SW1A 0AA</lol0:PostCode></lol0:GetUKLocationByPostCode>
            </env:Body>
          </env:Envelope>}

        @browser.post "/mock/UkLocationSoapService", request_body, {"HTTP_SOAPACTION" => "http://www.webserviceX.NET/GetUKLocationByPostCode", "CONTENT_TYPE" => "text/xml"}

        expect(@browser.last_response).to be_ok
        expect(@browser.last_response.body).to be_equivalent_to(%Q{
          <env:Envelope xmlns:lol0="http://www.webserviceX.NET" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Header>
            </env:Header>
            <env:Body>
              <lol0:GetUKLocationByPostCodeResponse>
                <lol0:GetUKLocationByPostCodeResult>House Of Commons, London, SW1A 0AA, United Kingdom</lol0:GetUKLocationByPostCodeResult>
              </lol0:GetUKLocationByPostCodeResponse>
            </env:Body>
          </env:Envelope>})
      end
    end

    describe "When the mocked operation is called with an unspecified parameter" do
      it "should throw a Mocha::ExpectationError" do
        request_body = %Q{
          <env:Envelope xmlns:lol0="http://www.webserviceX.NET" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Header></env:Header>
            <env:Body>
              <lol0:GetUKLocationByPostCode><lol0:PostCode>DOES NOT EXIST</lol0:PostCode></lol0:GetUKLocationByPostCode>
            </env:Body>
          </env:Envelope>}

        expect {
          @browser.post "/mock/UkLocationSoapService", request_body, {"HTTP_SOAPACTION" => "http://www.webserviceX.NET/GetUKLocationByPostCode", "CONTENT_TYPE" => "text/xml"}
        }.to raise_error(Mocha::ExpectationError)
      end
    end
  end
end