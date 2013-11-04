# Register an at_exit handler so that when Sinatra is shutting down
# we stop the torrent peer client.
$manager = nil
at_exit do
  puts "Stopping torrent client"
  $manager.stopPeerClient if $manager
end

require 'haml'
require 'json'
require 'quartz_torrent'
require 'quartz_flow/wrappers'
require 'quartz_flow/torrent_manager'
require 'quartz_flow/settings_helper'
require 'quartz_flow/authentication'
require 'quartz_flow/session'
require 'fileutils'
require 'sinatra/base'

class LogConfigurator
  def self.set(logger, level)
    QuartzTorrent::LogManager.setLevel logger, level
  end

  def self.configLevels
    # Load configuration settings
    path = "./etc/logging.rb"
    return if ! File.exists?(path)
    eval File.open(path,"r").read
  end
end

class Server < Sinatra::Base
  configure do
    enable :sessions
    set :bind, '0.0.0.0'
    set :port, 4444
    set :basedir, "download" 
    set :torrent_port, 9996
    set :db_file, "db/quartz.sqlite"
    set :torrent_log, "log/torrent.log"
    set :password_file, "etc/passwd"
    set :logging, true
    set :monthly_usage_reset_day, 1

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
    LogConfigurator.configLevels
    peerClient = QuartzTorrent::PeerClient.new(settings.basedir)
    peerClient.port = settings.torrent_port
    peerClient.start

    # Initialize Datamapper
    path = "sqlite://#{Dir.pwd}/#{settings.db_file}"
    DataMapper.setup(:default, path)

    $manager = TorrentManager.new(peerClient, settings.metadir, settings.monthly_usage_reset_day)
    $manager.startExistingTorrents
  end

  before do
    if $useAuthentication
      sid = session[:sid]
      if ! SessionStore.instance.valid_session?(sid)
        if request.path_info == "/"
          # Redirect to login if not authenticated
          session[:redir] = request.path_info
          request.path_info = "/login"
        elsif request.path_info != "/login"
          halt 500, "Authentication required"
        end
      end
    end
  end

  get "/login" do
    haml :login
  end

  post "/login" do
    json = JSON.parse(request.body.read)
    halt 500, "Missing login" if ! json['login']
    halt 500, "Missing password" if ! json['password']

    auth = Authentication.new settings.password_file
    if auth.authenticate json['login'], json['password']
      sid = SessionStore.instance.start_session(params[:login].to_s)
      session[:sid] = sid
    else
      halt 500, "Invalid login or password"
    end
    "OK"
  end

  post "/logout" do
    SessionStore.instance.end_session(session[:sid])
    session.delete :sid
    "OK"
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
    fields = nil
    fields = JSON.parse(params[:fields]).collect{ |f| f.to_sym } if params[:fields]
    where = nil
    where = JSON.parse(params[:where]) if params[:where]
    JSON.generate $manager.simplifiedTorrentData(fields, where)
  end

  # Get usage as a JSON object.
  get "/usage" do
    hash = { 
      :monthlyUsage => QuartzTorrent::Formatter.formatSize($manager.currentPeriodUsage(:monthly)),
      :dailyUsage => QuartzTorrent::Formatter.formatSize($manager.currentPeriodUsage(:daily))
    }
    JSON.generate hash
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

    begin
      $manager.removeTorrent infoHash, deleteFiles
    rescue
      halt 500, "Removing torrent failed: #{$!}"
    end
    
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
    begin
      helper.setGlobalSettingsHash(json)
    rescue
      halt 500, "Saving global settings failed: #{$!}"
    end
    "OK"
  end

  post "/change_torrent" do
    helper = SettingsHelper.new
    json = JSON.parse(request.body.read)

    asciiInfoHash = json['infoHash']
    halt 500, "Saving torrent settings failed: no infoHash parameter was sent to the server in the post request." if ! asciiInfoHash
  
    json.each do |k,v|
      next if k == 'infoHash'
      begin
        helper.set k, v, asciiInfoHash
      rescue
        halt 500, "Saving torrent settings failed: #{$!}"
      end
    end

    infoHash = QuartzTorrent::hexToBytes(asciiInfoHash)
    $manager.applyTorrentSettings infoHash

    "OK"
  end

end
