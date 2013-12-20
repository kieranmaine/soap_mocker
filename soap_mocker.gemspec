# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'soap_mocker/version'

Gem::Specification.new do |spec|
  spec.name          = "soap_mocker"
  spec.version       = SoapMocker::VERSION
  spec.authors       = ["Kieranmaine"]
  spec.email         = ["kieran.iles@gmail.com"]
  spec.description   = %q{Mocks SOAP web services}
  spec.summary       = %q{Mocks SOAP web services}
  spec.homepage      = "https://github.com/kieranmaine/soap_mocker"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "sinatra"
  spec.add_dependency "thin"
  spec.add_dependency "nokogiri"
  spec.add_dependency "equivalent-xml"
  spec.add_dependency "mocha"
  spec.add_dependency "activesupport"
  spec.add_dependency "rspec", "~> 2.14"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-html-matchers"
  spec.add_development_dependency "rack-test"
end
