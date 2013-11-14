# Context used when executing the plugin's links.rb script.
# This class defines the 'functions' that the links.rb script can call.
class PluginContext
  def initialize
    @links = []
  end

  attr_reader :links  

  def link(name, path)
    @links.push [name, path]
  end
end

# This class is used to load QuartzFlow plugins (loadAll), and represents a single plugin.
# Plugins contain:
#   - a links.rb file that defines menu links that show up on the main QuartzFlow page
#   - a routes.rb file that defines new Sinatra routes
#   - a views directory that contains new templates for use with the routes defined in routes.rb
class Plugin

  def initialize(links, routesFile)
    @links = links
    @routesFile = routesFile
  end

  attr_reader :links
  attr_reader :routesFile

  # Load all plugins under plugins/ and return an array of the loaded Plugin objects.
  def self.loadAll
    plugins = []
    Dir.new("plugins").each do |e|
      next if e =~ /^\./
      path = "plugins" + File::SEPARATOR + e
      if File.directory?(path)
     
        puts "Loading plugin #{e}"
   
        links = loadPluginLinks(path)
        routesFile = path + File::SEPARATOR + "routes.rb"
        if ! File.exists?(routesFile)
          routesFile = nil 
          puts "  plugin has no routes.rb file"
        end

        plugins.push Plugin.new(links, routesFile)
      end
    end
    plugins
  end

  private
  # Load the links.rb file.
  def self.loadPluginLinks(pluginDirectory)
    links = []
    path = pluginDirectory + File::SEPARATOR + "links.rb"
    if File.exists?(path)
      File.open(path,"r") do |file|
        context = PluginContext.new
        context.instance_eval file.read, "links.rb"
        links = context.links
      end
    else
      puts "  plugin has no links.rb file"
    end
    links
  end
end
