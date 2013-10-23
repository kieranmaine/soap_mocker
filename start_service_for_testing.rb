require "sinatra"
require "thin"
require_relative "lib/soap_mocker/mock_service_container"

include SoapMocker

service = MockServiceContainer.new "http://www.webservicex.net/uklocation.asmx?WSDL", "UKLocation", "UKLocationSoap", "/mock/UkLocation.svc"

service.mock_operation "GetUKLocationByPostCode",
                       {:GetUKLocationByPostCode => {:PostCode => "SW1A 0AA"}},
                       {:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => "House Of Commons, London, SW1A 0AA, United Kingdom"}}

service.mock_operation "GetUKLocationByPostCode",
                       {:GetUKLocationByPostCode => {:PostCode => "AL1 4JW"}},
                       {:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => "THIS IS AN INVALID POSTCODE"}},
                       true

service.run