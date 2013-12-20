require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |r|
  r.rspec_opts = "-c -f d"
end

RSpec::Core::RakeTask.new("spec:wip") do |r|
  r.rspec_opts = "-c -f d --tag wip"
end

task :default => :spec
