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

  s.name        = 'quartz_flow'
  s.version     = version
  s.date        = Time.new
  s.license     = 'MIT'
  s.summary     = "A web-based bittorrent client"
  s.description = "A web-based bittorrent client"
  s.authors     = ["Jeff Williams"]
  s.files       = Dir['bin/*'] + Dir['public/**/*.{css,js,png}'] + Dir['views/*.haml'] + Dir['lib/**/*.rb']  + Dir['etc/*.rb']
  s.homepage    =
    'https://github.com/jeffwilliams/quartz-flow'
  s.has_rdoc = false
  s.executables = ["quartzflow"]

  s.required_ruby_version = '>= 1.9.1'

  s.add_runtime_dependency "quartz_torrent", '~> 0.2'
  s.add_runtime_dependency "data_mapper", '~> 1.2'
  s.add_runtime_dependency "dm-sqlite-adapter", '~> 1.2'
  s.add_runtime_dependency "dm-types", '~> 1.2'
  s.add_runtime_dependency "sinatra", '~> 1.4'
  s.add_runtime_dependency "haml", '~> 4.0'
end

