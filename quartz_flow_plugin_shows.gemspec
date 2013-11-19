Gem::Specification.new do |s|
  git_tag = `git describe --tags --long --match 'v*'`.chomp!
  version = nil
  puts "Most recent git version tag: '#{git_tag}'"

  if git_tag =~ /^v(\d+)\.(\d+)\.(\d+)-(\d+)/
    commits_since = $4.to_i
    maj, min, bug = $1.to_i, $2.to_i, $3.to_i
    if commits_since > 0
      version = "#{maj}.#{min}.#{bug+1}.pre"
    else
      version = "#{maj}.#{min}.#{bug}"
    end
  else
    puts "Warning: Couldn't get the latest git tag using git describe. Defaulting to 0.0.1"
    version = "0.0.1"
  end

  s.name        = 'quartz_flow_plugin_shows'
  s.version     = version
  s.date        = Time.new
  s.summary     = "Plugin for quartz_flow that displays downloaded shows"
  s.description = "Plugin for quartz_flow that displays downloaded shows"
  s.authors     = ["Jeff Williams"]
  s.files       = Dir['plugins/shows/**/*'] 
  s.homepage    =
    'https://github.com/jeffwilliams/quartz-flow'
  s.has_rdoc = false

  s.add_runtime_dependency "quartz_flow", '~> 0.0.2'
end


