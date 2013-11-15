require 'rake/testtask'
require 'rdoc/task'

$gemfile_name = nil

task :default => [:makegem]

task :makegem do
  output = `gem build quartz_flow.gemspec`
  output.each_line do |line|
    $gemfile_name = $1 if line =~ /File: (.*)$/
    print line
  end

  system "gem build quartz_flow_plugin_shows.gemspec"
end

task :devinstall => [:makegem] do
  system "gem install #{$gemfile_name} --user-install --ignore-dependencies --no-rdoc --no-ri"
end
