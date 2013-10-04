require 'rake/testtask'
require 'rdoc/task'

task :default => [:makegem]

task :makegem do
  system "gem build quartz_flow.gemspec"
end

task :devinstall do
  system "gem install quartz_flow-0.0.1.gem --user-install --ignore-dependencies --no-rdoc --no-ri"
end
