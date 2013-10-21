#!/usr/bin/env ruby
require 'fileutils'
require 'quartz_flow/model'

DataMapper::Logger.new($stdout, :debug)

$settings = {}
def set(sym, value)
  puts "Set called: #{sym}=#{value}"
  $settings[sym] = value
end

require './etc/quartz'

dbPath = "#{Dir.pwd}/#{$settings[:db_file]}"
path = "sqlite://#{dbPath}"
DataMapper.setup(:default, path)

dir = File.dirname($settings[:db_file])
FileUtils.mkdir dir if dir.length > 0 && ! File.directory?(dir)


if ! File.exists?(dbPath)
  puts "creating database #{path}"
  DataMapper.auto_migrate!
else
  puts "upgrading database #{path}"
  DataMapper.auto_upgrade!
end

