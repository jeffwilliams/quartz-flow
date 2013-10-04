#!/usr/bin/env ruby
require 'getoptlong'
require 'quartz_flow/home'

def doSetup
  home = "."

  opts = GetoptLong.new(
    [ '--homedir', '-d', GetoptLong::REQUIRED_ARGUMENT],
  )       

  opts.each do |opt, arg|
    if opt == '--homedir'
      home = arg
    end
  end

  if ! File.directory?(home)
    puts "Error: The directory '#{home}' we will setup into doesn't exist."
    exit 1
  end

  if ! File.owned?(home)
    puts "Error: The directory '#{home}' is not owned by this user. Please change the owner."
    exit 1
  end

  puts "Initializing new quartzflow home in #{home == "." ? "current directory" : home}"
  Home.new(home).setup
end

def doHelp
  if ARGV.size == 0
    puts "Used to manage or start quartzflow."
    puts "Usage: #{$0} <command> [options]"
    puts ""
    puts "For help with a specific command, use 'help command'. The available commands are:"
    puts "  start   Start quartzflow"
    puts "  setup   Setup a new quartzflow home directory"
  else
    command = ARGV.shift
    if command == "setup"
      puts "Initialize a new quartzflow home directory. This command creates the necessary "
      puts "subdirectories and files needed for quartzflow to run. When run without options, "
      puts "the current directory is set up. The directory should be empty and owned by the "
      puts "current user."
      puts ""
      puts "Options:"
      puts "  --homedir DIR, -d DIR       Setup DIR instead of the current directory"
    elsif command == "start"
      puts "Start quartzflow. When run without options, the current directory should be a"
      puts "quartzflow home directory, as created using the setup command."
    else
      puts "Unknown command"
    end
  end
end

command = :start

if ARGV.size > 0
  command = ARGV.shift.to_sym
end

if command == :setup
  doSetup
elsif command == :start
  exit 1 if ! Home.new.validate
  require 'quartz_flow/server'
  Server.run!
elsif command == :help
  doHelp
else
  puts "Unknown command #{command}"
end
