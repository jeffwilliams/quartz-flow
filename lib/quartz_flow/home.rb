require 'fileutils'
require 'quartz_flow/model'

# Class used to setup a new QuartzFlow home directory, and get information about it.
class Home
  def initialize(dir = ".")
    @dir = dir

    @subdirs = [
      "etc",
      "log",
      "download",
      "meta",
      "public",
      "db",
      "views",
    ]

    @installRoot = Home.determineAppRoot("quartz_flow")
  end

  def validate
    rc = true
    @subdirs.each do |subdir|
      path = File.join(@dir, subdir)
      if ! File.directory?(path)
        puts "Error: The home directory is invalid: the subdirectory #{subdir} doesn't exist under the home directory. Was the setup command run?"
        rc = false
        break
      end
    end
    rc
  end

  def setup
    @subdirs.each do |subdir|
      if File.directory?(subdir)
        puts "Directory #{subdir} already exists. Skipping creation."
      else
        installedPath = @installRoot + File::SEPARATOR + subdir 
        if File.directory? installedPath
          FileUtils.cp_r installedPath, @dir
          puts "Copying #{subdir}"
        else
          FileUtils.mkdir @dir + File::SEPARATOR + subdir
          puts "Creating #{subdir}"
        end
      end
    end

    # Create database
    puts "Creating database file"
    path = "sqlite://#{File.expand_path(@dir)}/db/quartz.sqlite"
    DataMapper.setup(:default, path)

    DataMapper.auto_migrate!
  end

  def self.determineAppRoot(gemname)
    # Are we running as a Gem, or from the source directory?
    if Gem.loaded_specs[gemname]
      Gem.loaded_specs[gemname].full_gem_path
    else
      "."
    end
  end

end
