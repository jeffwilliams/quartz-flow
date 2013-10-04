#!/usr/bin/env ruby
require 'fileutils'
require 'quartz_flow/model'

$settings = {}
def set(sym, value)
  puts "Set called: #{sym}=#{value}"
  $settings[sym] = value
end

require './etc/quartz'

path = "sqlite://#{Dir.pwd}/#{$settings[:db_file]}"
DataMapper.setup(:default, path)

dir = File.dirname($settings[:db_file])
FileUtils.mkdir dir if dir.length > 0 && ! File.directory?(dir)

DataMapper.auto_migrate!

