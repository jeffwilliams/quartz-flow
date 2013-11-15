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
      "plugins",
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
    dbFile = "#{File.expand_path(@dir)}/db/quartz.sqlite"
    if ! File.exists?(dbFile)
      puts "Creating database file"
      path = "sqlite://#{File.expand_path(@dir)}/db/quartz.sqlite"
      DataMapper.setup(:default, path)
      DataMapper.auto_migrate!
    else
      puts "Database file already exists. Running upgrade."
      path = "sqlite://#{File.expand_path(@dir)}/db/quartz.sqlite"
      DataMapper.setup(:default, path)
      DataMapper.auto_upgrade!
    end

    # Install plugins.
    setupPlugins
  end

  def self.determineAppRoot(gemname)
    # Are we running as a Gem, or from the source directory?
    if Gem.loaded_specs[gemname]
      Gem.loaded_specs[gemname].full_gem_path
    else
      "."
    end
  end

  private
  
  def setupPlugins
    # Find out the latest version of the quartz_flow gem
    spec = Gem::Specification.find_by_name("quartz_flow")
    if ! spec
      puts "Not copying plugins: quartz_flow gem is not installed" 
      return
    end

    # If quartz_flow is pre-release, allow loading pre-release plugins.
    allowPrerelease = spec.version.prerelease?

    Gem::Specification.latest_specs(allowPrerelease).each do |spec|
      if spec.name =~ /quartz_flow_plugin/
        puts "Detected installed plugins gem '#{spec.name}'"
        pluginBase = spec.full_gem_path
        pluginContentsDir = pluginBase + File::SEPARATOR + "plugins"
        Dir.new(pluginContentsDir).each do |e|
          next if e[0,1] == '.'
          path = pluginContentsDir + File::SEPARATOR + e
          if File.directory?(path)
            puts "Copying plugin #{e}"
            FileUtils.cp_r path, @dir + File::SEPARATOR + "plugins"
          end
        end
      end
    end
  end

end
