require "bundler"
Bundler.setup(:default, :development)

ENV['RACK_ENV'] = 'test'

require "soap_mocker"
require "rspec"
require "rspec-html-matchers"
require "rack/test"
require "logging"
require "mocha/api"

include Mocha::API
include SoapMocker

describe SoapMocker::MockSoapServiceApp do

  include Rack::Test::Methods

  context "mocking multiple services" do
    before (:each) do
      SoapMocker::Logging.logger.level = Logger::FATAL

      uk_location_wsdl_file = File.read(File.join(File.dirname(__FILE__), "/wsdl/uklocation.wsdl"))
      geo_ip_wsdl_file = File.read(File.join(File.dirname(__FILE__), "/wsdl/geoipservice.wsdl"))

      @uk_location_service = SoapMocker::SoapServiceSettings.new("/mock/UkLocationSoapService", uk_location_wsdl_file, "UKLocation", "UKLocationSoap")
      @geo_ip_service = SoapMocker::SoapServiceSettings.new("/GeoIpService", geo_ip_wsdl_file, "GeoIPService", "GeoIPServiceSoap")

      SoapMocker::MockSoapServiceApp.set :soap_services, [@uk_location_service, @geo_ip_service]

      @app = SoapMocker::MockSoapServiceApp.new

      @browser = Rack::Test::Session.new(Rack::MockSession.new(@app))
    end

    context "'/' requested" do
      it "should return a message" do
        @browser.get "/"

        expect(@browser.last_response).to be_ok
        expect(@browser.last_response.body).to have_tag("p", :text => "This is a SOAP mock service. The following SOAP services have been mocked:")
        expect(@browser.last_response.body).to have_tag("ul") do
          with_tag "li", :text => "GeoIPService - Path: /GeoIpService"
          with_tag "li", :text => "UKLocation - Path: /mock/UkLocationSoapService"
        end
      end
    end

    context "Given an invalid service path is being used" do
      describe "When a mock operation is called" do
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
          expect(@browser.last_response.body).to eq "Nothing exists here. Go to <a href=\"/\">/</a> to view a list of services. Go to <a href=\"/{service_path}/operations\">/{service_path}/operations</a> for list of valid operations and SOAP actions for a specific service."
        end
      end

      describe "When an invalid service's operations are requested " do
        before :each do
          @browser.get "/invalid_service_path/operations"
        end

        it "should return a 404 status" do
          expect(@browser.last_response).to_not be_ok
          expect(@browser.last_response.status).to eq 404
        end

        it "should return a message directing the user to the correct service path" do
          expect(@browser.last_response.body).to eq "Nothing exists here. Go to <a href=\"/\">/</a> to view a list of services. Go to <a href=\"/{service_path}/operations\">/{service_path}/operations</a> for list of valid operations and SOAP actions for a specific service."
        end
      end
    end

    context "Given the UKLocationService path is being used" do
      describe "When '/mock/UkLocationSerivce/operations' is requested" do
        before :each do
          @browser.get "/mock/UkLocationSoapService/operations"
        end

        it "should return a count of operations" do
          expect(@browser.last_response).to be_ok
          expect(@browser.last_response.body).to have_tag("div", :text => "Operations count: 4")
        end

        it "should return a list of operations" do
          expect(@browser.last_response.body).to have_tag("ul", :class => "operations") do
            with_tag "li", :text => "Name: GetUKLocationByCounty"
            with_tag "li", :text => "Name: GetUKLocationByTown"
            with_tag "li", :text => "Name: GetUKLocationByPostCode"
            with_tag "li", :text => "Name: ValidateUKAddress"
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
          @browser.post "mock/UkLocationSoapService/operation/OPERATION_DOES_NOT_EXIST/mock"
        end

        it "should return a 500 status" do
          expect(@browser.last_response).to_not be_ok
          expect(@browser.last_response.status).to eq 500
        end

        it "should return a message indicating operation is invalid" do
          expect(@browser.last_response.body).to eq "Operation is not valid. Go to <a href=\"/mock/UkLocationSoapService/operations\">/mock/UkLocationSoapService/operations</a> for list of valid operations and SOAP actions."
        end
      end

      context "When a valid operation is mocked" do
        before do
          fields = %Q{{
            "with": "{:GetUKLocationByPostCode => {:PostCode => \\"SW1A 0AA\\"}}",
            "returns": "{:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => \\"House Of Commons, London, SW1A 0AA, United Kingdom\\"}}",
            "not_equals": false
          }}

          @browser.post "mock/UkLocationSoapService/operation/GetUKLocationByPostCode/mock", fields
        end

        it "should return a success message" do
          expect(@browser.last_response).to be_ok
          expect(@browser.last_response.body).to eq("Mock successfully set up")
        end

        it "should increment the mocks_per_operation count" do
          expect(@uk_location_service.operations.find { |o| o[:name] == "GetUKLocationByPostCode" }[:mock_count]).to eq 1
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

    context "Given the GeoIpService path is being used" do
      describe "When '/GeoIpService/operations' is requested " do
        before :each do
          @browser.get "/GeoIpService/operations"
        end

        it "should return a count of operations" do
          expect(@browser.last_response).to be_ok
          expect(@browser.last_response.body).to have_tag("div", :text => "Operations count: 2")
        end

        it "should return a list of operations" do
          expect(@browser.last_response.body).to have_tag("ul", :class => "operations") do
            with_tag "li", :text => "Name: GetGeoIP"
            with_tag "li", :text => "Name: GetGeoIPContext"
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

            @browser.post "/GeoIpService", request_body
          end

          it "should return a 500 status code" do
            expect(@browser.last_response).to_not be_ok
            expect(@browser.last_response.status).to eq 500
          end

          it "should return message indicating SOAPAction header required." do
            expect(@browser.last_response.body).to eq "SOAPAction header not present."
          end
        end

        describe "with an invalid SOAPAction header" do
          before do
            request_body = %Q{
              <env:Envelope xmlns:lol0="http://www.webserviceX.NET" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
                <env:Body></env:Body>
              </env:Envelope>}

            @browser.post "/GeoIpService", request_body, {"HTTP_SOAPACTION" => "SOAP_ACTION_DOES_NOT_EXIST", "CONTENT_TYPE" => "text/xml"}
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
          @browser.post "GeoIpService/operation/OPERATION_DOES_NOT_EXIST/mock"
        end

        it "should return a 500 status" do
          expect(@browser.last_response).to_not be_ok
          expect(@browser.last_response.status).to eq 500
        end

        it "should return a message indicating operation is invalid" do
          expect(@browser.last_response.body).to eq "Operation is not valid. Go to <a href=\"/GeoIpService/operations\">/GeoIpService/operations</a> for list of valid operations and SOAP actions."
        end
      end

      context "When a valid operation is mocked" do
        before do
          fields = %Q{{
            "with": "{:GetGeoIP=>{:IPAddress=>\\"127.0.0.1\\"}}",
            "returns": "{:GetGeoIPResponse=>{:GetGeoIPResult=>{:ReturnCode=>\\"1\\", :IP=>\\"127.0.0.2\\", :ReturnCodeDetails=>\\"BlahBlah\\", :CountryName=>\\"PETEROIA\\", :CountryCode=>\\"PGRIFF\\"}}}",
            "not_equals": false
          }}

          @browser.post "/GeoIpService/operation/GetGeoIP/mock", fields
        end

        it "should return a success message" do
          expect(@browser.last_response).to be_ok
          expect(@browser.last_response.body).to eq("Mock successfully set up")
        end

        it "should increment the mocks_per_operation count" do
          expect(@geo_ip_service.operations.find { |o| o[:name] == "GetGeoIP" }[:mock_count]).to eq 1
        end

        describe "When the mocked operation is called with a specified parameter" do
          it "should return the specified value" do
            request_body = %Q{
              <env:Envelope xmlns:lol0="http://www.webservicex.net/" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
                <env:Header></env:Header>
                <env:Body>
                  <lol0:GetGeoIP><lol0:IPAddress>127.0.0.1</lol0:IPAddress></lol0:GetGeoIP>
                </env:Body>
              </env:Envelope>}

            @browser.post "/GeoIpService", request_body, {"HTTP_SOAPACTION" => "http://www.webservicex.net/GetGeoIP", "CONTENT_TYPE" => "text/xml"}

            expect(@browser.last_response).to be_ok
            expect(@browser.last_response.body).to be_equivalent_to(%Q{
              <env:Envelope xmlns:lol0="http://www.webservicex.net/" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
                <env:Header>
                </env:Header>
                <env:Body>
                  <lol0:GetGeoIPResponse>
                    <lol0:GetGeoIPResult>
                      <lol0:ReturnCode>1</lol0:ReturnCode>
                      <lol0:IP>127.0.0.2</lol0:IP>
                      <lol0:ReturnCodeDetails>BlahBlah</lol0:ReturnCodeDetails>
                      <lol0:CountryName>PETEROIA</lol0:CountryName>
                      <lol0:CountryCode>PGRIFF</lol0:CountryCode>
                    </lol0:GetGeoIPResult>
                  </lol0:GetGeoIPResponse>
                </env:Body>
              </env:Envelope>})
          end
        end

        describe "When the mocked operation is called with an unspecified parameter" do
          it "should throw a Mocha::ExpectationError" do
            request_body = %Q{
              <env:Envelope xmlns:lol0="http://www.webservicex.net/" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
                <env:Header></env:Header>
                <env:Body>
                  <lol0:GetGeoIP><lol0:IPAddress>IP NOT SET UP</lol0:IPAddress></lol0:GetGeoIP>
                </env:Body>
              </env:Envelope>}

            expect {
              @browser.post "/GeoIpService", request_body, {"HTTP_SOAPACTION" => "http://www.webservicex.net/GetGeoIP", "CONTENT_TYPE" => "text/xml"}
            }.to raise_error(Mocha::ExpectationError)
          end
        end
      end
    end
  end

  context "mocking the same service on different paths" do
    before (:each) do
      SoapMocker::Logging.logger.level = Logger::FATAL

      uk_location_wsdl_file = File.read(File.join(File.dirname(__FILE__), "/wsdl/uklocation.wsdl"))

      @uk_location_service1 = SoapMocker::SoapServiceSettings.new("/mock/UkLocationSoapService1", uk_location_wsdl_file, "UKLocation", "UKLocationSoap")
      @uk_location_service2 = SoapMocker::SoapServiceSettings.new("/mock/UkLocationSoapService2", uk_location_wsdl_file, "UKLocation", "UKLocationSoap")

      SoapMocker::MockSoapServiceApp.set :soap_services, [@uk_location_service1, @uk_location_service2]

      @app = SoapMocker::MockSoapServiceApp.new

      @browser = Rack::Test::Session.new(Rack::MockSession.new(@app))
    end

    context "Given the same operation is mocked on both services with the same input parameters and different outputs" do
      before :each do
        fields_for_service1 = %Q{{
            "with": "{:GetUKLocationByPostCode => {:PostCode => \\"SW1A 0AA\\"}}",
            "returns": "{:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => \\"RESULT 1\\"}}",
            "not_equals": false
          }}

        @browser.post "mock/UkLocationSoapService1/operation/GetUKLocationByPostCode/mock", fields_for_service1

        fields_for_service2 = %Q{{
            "with": "{:GetUKLocationByPostCode => {:PostCode => \\"SW1A 0AA\\"}}",
            "returns": "{:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => \\"RESULT 2\\"}}",
            "not_equals": false
          }}

        @browser.post "mock/UkLocationSoapService2/operation/GetUKLocationByPostCode/mock", fields_for_service2
      end

      it "should increment the mocks_per_operation count for the first service" do
        expect(@uk_location_service1.operations.find { |o| o[:name] == "GetUKLocationByPostCode" }[:mock_count]).to eq 1
      end

      it "should increment the mocks_per_operation count for the second service" do
        expect(@uk_location_service2.operations.find { |o| o[:name] == "GetUKLocationByPostCode" }[:mock_count]).to eq 1
      end

      describe "When the both the mock operation is called on each service" do
        it "should return the specified value for the first service" do
          request_body = %Q{
              <env:Envelope xmlns:lol0="http://www.webserviceX.NET" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
                <env:Header></env:Header>
                <env:Body>
                  <lol0:GetUKLocationByPostCode><lol0:PostCode>SW1A 0AA</lol0:PostCode></lol0:GetUKLocationByPostCode>
                </env:Body>
              </env:Envelope>}

          @browser.post "/mock/UkLocationSoapService1", request_body, {"HTTP_SOAPACTION" => "http://www.webserviceX.NET/GetUKLocationByPostCode", "CONTENT_TYPE" => "text/xml"}

          expect(@browser.last_response).to be_ok
          expect(@browser.last_response.body).to be_equivalent_to(%Q{
              <env:Envelope xmlns:lol0="http://www.webserviceX.NET" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
                <env:Header></env:Header>
                <env:Body>
                  <lol0:GetUKLocationByPostCodeResponse>
                    <lol0:GetUKLocationByPostCodeResult>RESULT 1</lol0:GetUKLocationByPostCodeResult>
                  </lol0:GetUKLocationByPostCodeResponse>
                </env:Body>
              </env:Envelope>})
        end

        it "should return the specified value for the second service" do
          request_body = %Q{
              <env:Envelope xmlns:lol0="http://www.webserviceX.NET" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
                <env:Header></env:Header>
                <env:Body>
                  <lol0:GetUKLocationByPostCode><lol0:PostCode>SW1A 0AA</lol0:PostCode></lol0:GetUKLocationByPostCode>
                </env:Body>
              </env:Envelope>}

          @browser.post "/mock/UkLocationSoapService2", request_body, {"HTTP_SOAPACTION" => "http://www.webserviceX.NET/GetUKLocationByPostCode", "CONTENT_TYPE" => "text/xml"}

          expect(@browser.last_response).to be_ok
          expect(@browser.last_response.body).to be_equivalent_to(%Q{
              <env:Envelope xmlns:lol0="http://www.webserviceX.NET" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
                <env:Header></env:Header>
                <env:Body>
                  <lol0:GetUKLocationByPostCodeResponse>
                    <lol0:GetUKLocationByPostCodeResult>RESULT 2</lol0:GetUKLocationByPostCodeResult>
                  </lol0:GetUKLocationByPostCodeResponse>
                </env:Body>
              </env:Envelope>})
        end
      end
    end
  end
end