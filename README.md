soap_mocker
======

SOAP web service mocking framework.

Allows you to create mock web services with any given WSDL document.

Usage
=====

````ruby
require 'SOAPMocker'

mock_service = SOAPMocker.new "http://www.webservicex.net/uklocation.asmx?WSDL", { :port => 3001, :path => "mock/FakeService.svc" }

web.mock_operation "GetUKLocationByPostCode",
                    {:GetUKLocationByPostCode => {:PostCode => "AL1 4JW"}},
                    {:GetUKLocationByPostCodeResponse => {:GetUKLocationByPostCodeResult => "St Pauls Place, St Albans, Hertfordshire, AL1 4JW"}}

# Web service will be accessible at the URL http://localhost:3001/mock/FakeService.svc
mock_service.run
```
