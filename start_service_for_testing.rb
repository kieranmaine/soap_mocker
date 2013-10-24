require "sinatra/base"
require "thin"
require_relative "lib/soap_mocker/mock_service_container"

include SoapMocker

service = MockServiceContainer.new "http://www.webservicex.net/uklocation.asmx?WSDL", "UKLocation", "UKLocationSoap", "/mock/UkLocation.svc"

["SW1A 0AA", "N1C 4QP"].each do |postcode|
  service.mock_operation "GetUKLocationByPostCode",
                         {:GetUKLocationByPostCode => {:PostCode => postcode}},
                         {:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => "THIS IS AN INVALID POSTCODE"}},
                         true
end

service.mock_operation "GetUKLocationByPostCode",
                       {:GetUKLocationByPostCode => {:PostCode => "SW1A 0AA"}},
                       {:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => "House Of Commons, London, SW1A 0AA, United Kingdom"}}

service.mock_operation "GetUKLocationByPostCode",
                       {:GetUKLocationByPostCode => {:PostCode => "N1C 4QP"}},
                       {:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => "St Pancras International Station, Euston Road, London, N1C 4QP"}}

# Example of accessing mock object directly and setting up own matcher.
service.io_mock.stubs(:call_op).with("GetUKLocationByPostCode", regexp_matches(/AL1 4JW/)).returns({:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => "TESTING"}})

service.run