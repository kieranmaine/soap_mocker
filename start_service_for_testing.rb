require_relative 'lib/soap_mocker/mock_service_container'
require_relative 'lib/soap_mocker/soap_service_settings'
require 'mocha/api'

include Mocha::API

soap_services = [
    SoapMocker::SoapServiceSettings.new("/mock/UkLocationSoapService", "http://www.webservicex.net/uklocation.asmx?WSDL", "UKLocation", "UKLocationSoap"),
    SoapMocker::SoapServiceSettings.new("/mock/UkLocationSoapService2", "http://www.webservicex.net/uklocation.asmx?WSDL", "UKLocation", "UKLocationSoap"),
    SoapMocker::SoapServiceSettings.new("/GeoIpService", "http://www.webservicex.net/geoipservice.asmx?WSDL", "GeoIPService", "GeoIPServiceSoap"),
    SoapMocker::SoapServiceSettings.new("/BookingService", "http://csl104.vpdc.europe.easyjet.local:8081/easyJet.Bookings.Queries.Host/BookingQueryService.svc?wsdl", "BookingQueryService", "BasicHttpBinding_IBookingQueryService")
]

service = SoapMocker::MockServiceContainer.new soap_services, {:port => 1066}

["SW1A 0AA", "N1C 4QP"].each do |postcode|
  service.mock_operation soap_services[0],
                         "GetUKLocationByPostCode",
                         {:GetUKLocationByPostCode => {:PostCode => postcode}},
                         {:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => "THIS IS AN INVALID POSTCODE"}},
                         true
end

service.mock_operation soap_services[0],
                       "GetUKLocationByPostCode",
                       {:GetUKLocationByPostCode => {:PostCode => "SW1A 0AA"}},
                       {:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => "House Of Commons, London, SW1A 0AA, United Kingdom"}}

# Example of accessing mock object directly.
soap_services[0].io_mock.stubs(:call_op).with("GetUKLocationByPostCode", regexp_matches(/AL1 4JW/)).returns({:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => "TESTING"}})

Thread.abort_on_exception = true

t = Thread.new {
  service.run
}

# Mock expectations after service has started running
service.mock_operation soap_services[0],
                       "GetUKLocationByPostCode",
                       {:GetUKLocationByPostCode => {:PostCode => "N1C 4QP"}},
                       {:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => "St Pancras International Station, Euston Road, London, N1C 4QP"}}

puts "To exit you must enter...\n"
gets
t.kill
