require_relative 'lib/soap_mocker/mock_service_container'
require 'mocha/api'

include Mocha::API

service = SoapMocker::MockServiceContainer.new "http://www.webservicex.net/uklocation.asmx?WSDL", "UKLocation", "UKLocationSoap", "/mock/UkLocationSoapService", {:port => 1066}

["SW1A 0AA", "N1C 4QP"].each do |postcode|
  service.mock_operation "GetUKLocationByPostCode",
                         {:GetUKLocationByPostCode => {:PostCode => postcode}},
                         {:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => "THIS IS AN INVALID POSTCODE"}},
                         true
end

service.mock_operation "GetUKLocationByPostCode",
                       {:GetUKLocationByPostCode => {:PostCode => "SW1A 0AA"}},
                       {:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => "House Of Commons, London, SW1A 0AA, United Kingdom"}}

# Example of accessing mock object directly.
service.io_mock.stubs(:call_op)
  .with("GetUKLocationByPostCode", regexp_matches(/AL1 4JW/))
  .returns({:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => "TESTING"}})

Thread.abort_on_exception = true

Thread.new { service.run }

# Mock expectations after service has started running
service.mock_operation "GetUKLocationByPostCode",
                       {:GetUKLocationByPostCode => {:PostCode => "N1C 4QP"}},
                       {:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => "St Pancras International Station, Euston Road, London, N1C 4QP"}}

puts "To exit you must enter...\n"
gets
