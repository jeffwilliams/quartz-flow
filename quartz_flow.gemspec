Gem::Specification.new do |s|
  s.name        = 'quartz_flow'
  s.version     = '0.0.1'
  s.date        = '2013-10-04'
  s.summary     = "A web-based bittorrent client"
  s.description = "A web-based bittorrent client"
  s.authors     = ["Jeff Williams"]
  s.files       = Dir['bin/*'] + Dir['public/**/*.{css,js,png}'] + Dir['views/*.haml'] + Dir['lib/**/*.rb']  + Dir['etc/*.rb']
  s.homepage    =
    'https://github.com/jeffwilliams/quartz-torrent'
  s.has_rdoc = false
  s.executables = ["quartzflow"]

  s.add_runtime_dependency "quartz_torrent"
  s.add_runtime_dependency "data_mapper", '~> 1.2'
  s.add_runtime_dependency "dm-sqlite-adapter", '~> 1.2'
  s.add_runtime_dependency "dm-types", '~> 1.2'
  s.add_runtime_dependency "sinatra", '~> 1.4'
end

