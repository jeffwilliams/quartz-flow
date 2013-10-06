# Register an at_exit handler so that when Sinatra is shutting down
# we stop the torrent peer client.
$manager = nil
at_exit do
  puts "Stopping torrent client"
  $manager.stopPeerClient if $manager
end

require 'haml'
require 'json'
#require 'quartz_flow/mock_client'
require 'quartz_torrent'
require 'quartz_flow/wrappers'
require 'quartz_flow/torrent_manager'
require 'quartz_flow/settings_helper'
require 'fileutils'

require 'sinatra/base'

class Server < Sinatra::Base

  configure do
    set :bind, '0.0.0.0'
    set :port, 4444
    set :basedir, "download" 
    set :torrent_port, 9996
    set :db_file, "db/quartz.sqlite"
    set :torrent_log, "log/torrent.log"
    set :logging, true

    # Load configuration settings
    eval File.open("./etc/quartz.rb","r").read

    set :root, '.'

    raise "The basedir '#{settings.basedir}' does not exist. Please create it." if ! File.directory? settings.basedir
    raise "The metadir '#{settings.metadir}' does not exist. Please create it." if ! File.directory? settings.metadir

    QuartzTorrent::LogManager.initializeFromEnv
    logfile = settings.torrent_log
    QuartzTorrent::LogManager.setup do
      setLogfile logfile
      setDefaultLevel :info
    end
    QuartzTorrent::LogManager.setLevel "peer_manager", :debug
    QuartzTorrent::LogManager.setLevel "tracker_client", :debug
    QuartzTorrent::LogManager.setLevel "http_tracker_client", :debug
    QuartzTorrent::LogManager.setLevel "udp_tracker_client", :debug
    QuartzTorrent::LogManager.setLevel "peerclient", :debug
    QuartzTorrent::LogManager.setLevel "peerclient.reactor", :info
    #LogManager.setLevel "peerclient.reactor", :debug
    QuartzTorrent::LogManager.setLevel "blockstate", :debug
    QuartzTorrent::LogManager.setLevel "piecemanager", :info
    QuartzTorrent::LogManager.setLevel "peerholder", :debug

    peerClient = QuartzTorrent::PeerClient.new(settings.basedir)
    peerClient.port = settings.torrent_port
    peerClient.start

    # Initialize Datamapper
    path = "sqlite://#{Dir.pwd}/#{settings.db_file}"
    DataMapper.setup(:default, path)

    $manager = TorrentManager.new(peerClient, settings.metadir)
    $manager.startExistingTorrents
  end

  get "/" do
    haml :index
  end

  # Get the HTML template used by the Angular module 
  # to display the table of running torrents view.
  get "/torrent_table" do
    haml :torrent_table_partial
  end

  # Get the HTML template used by the Angular module 
  # to display the details of a single running torrent view.
  get "/torrent_detail" do
    haml :torrent_detail_partial
  end


  # Get the HTML template used by the Angular module 
  # to display the config settings
  get "/config" do
    haml :config_partial
  end

  # Get an array of JSON objects that represent a list of current running 
  # torrents with various properties.
  get "/torrent_data" do
    JSON.generate $manager.simplifiedTorrentData
  end

  # Download a .torrent file and start running it.
  # The body of the post should be JSON encoded.
  post "/download_torrent" do
    json = JSON.parse(request.body.read)
    
    url = json["url"]
    halt 500, "Downloading torrent file failed: no url parameter was sent to the server in the post request." if ! url || url.length == 0
    path = nil
    begin
      path = $manager.downloadTorrentFile url
    rescue
      halt 500, "Downloading torrent file failed: #{$!}"
    end

    begin
      $manager.startTorrentFile(path)
    rescue BEncode::DecodeError
      halt 500, "Starting torrent file failed: torrent file is malformed."
    rescue
      puts $!
      puts $!.backtrace.join("\n")
      halt 500, "Starting torrent file failed: #{$!}."
    end
      
    # We need to return something here otherwise AngularJS chokes.
    "Worked fine"
  end

  # Given a magnet link, start running it.
  # The body of the post should be JSON encoded.
  post "/start_magnet" do
    json = JSON.parse(request.body.read)

    url = json["url"]
    halt 500, "Starting magnet link failed: no url parameter was sent to the server in the post request." if ! url || url.length == 0
    halt 500, "Starting magnet link failed: the link doesn't appear to be a magnet link" if ! QuartzTorrent::MagnetURI.magnetURI?(url)

    magnet = QuartzTorrent::MagnetURI.new(url)
    begin
      $manager.storeMagnet(magnet)
    rescue
      halt 500, "Storing magnet link failed: #{$!}."
    end
   
    begin
      $manager.startMagnet(magnet)
    rescue
      puts $!
      puts $!.backtrace.join("\n")
      halt 500, "Starting magnet link failed: #{$!}."
    end

    # We need to return something here otherwise AngularJS chokes.
    "Worked fine"
  end

  # Handle an upload of a torrent file.
  post "/upload_torrent" do
    # See http://www.wooptoot.com/file-upload-with-sinatra
    path = params['torrentfile'][:tempfile].path

    #FileUtils.chmod 0644, path
    path = $manager.storeUploadedTorrentFile path, params['torrentfile'][:filename]

    begin
      $manager.startTorrentFile(path)
    rescue BEncode::DecodeError
      halt 500, "Starting torrent file failed: torrent file is malformed."
    rescue
      puts $!
      puts $!.backtrace.join("\n")
      halt 500, "Starting torrent file failed: #{$!}."
    end
      
    # We need to return something here otherwise AngularJS chokes.
    "@@success"
  end

  post "/pause_torrent" do
    json = JSON.parse(request.body.read)

    infoHash = json["infohash"]
    halt 500, "Pausing torrent failed: no infohash parameter was sent to the server in the post request." if !infoHash || infoHash.length == 0
    $manager.peerClient.setPaused QuartzTorrent::hexToBytes(infoHash), true
    puts "Pausing torrent"
    "OK"
  end

  post "/unpause_torrent" do
    json = JSON.parse(request.body.read)

    infoHash = json["infohash"]
    halt 500, "Unpausing torrent failed: no infohash parameter was sent to the server in the post request." if !infoHash || infoHash.length == 0
    $manager.peerClient.setPaused QuartzTorrent::hexToBytes(infoHash), false
    "OK"
  end

  post "/delete_torrent" do
    json = JSON.parse(request.body.read)

    infoHash = json["infohash"]
    halt 500, "Deleting torrent failed: no infohash parameter was sent to the server in the post request." if !infoHash || infoHash.length == 0
    deleteFiles = json["delete_files"]
    halt 500, "Deleting torrent failed: no delete_files parameter was sent to the server in the post request." if deleteFiles.nil?

    $manager.removeTorrent infoHash, deleteFiles
    
    "OK"
  end

  # Return all UI configurable settings from the model as
  # a hash.
  get "/global_settings" do
    settings = SettingsHelper.new.globalSettingsHash
    JSON.generate settings
  end

  post "/global_settings" do
    helper = SettingsHelper.new
    json = JSON.parse(request.body.read)
    helper.setGlobalSettingsHash(json)
  end

end
