require 'open-uri'
require 'quartz_torrent/util'
require 'quartz_torrent/formatter'
require 'quartz_torrent/magnet'
require 'fileutils'

class TorrentManager
  def initialize(peerClient, torrentFileDir)
    @peerClient = peerClient
    @cachedTorrentData = nil
    @cachedAt = nil
    @cacheLifetime = 2
    @torrentFileDir = torrentFileDir
    @peerClientStopped = false
  end

  attr_reader :peerClient

  def torrentData(infoHash = nil)
    if (! @cachedTorrentData || Time.new - @cachedAt > @cacheLifetime) && ! @peerClientStopped
      @cachedTorrentData = @peerClient.torrentData
      @cachedAt = Time.new
    end
    
    @cachedTorrentData
  end

  def stopPeerClient
    @peerClient.stop
    @peerClientStopped = true
  end

  # Start torrents that already exist in the torrent file directory
  def startExistingTorrents
    Dir.new(@torrentFileDir).each do |e|
      path = @torrentFileDir + File::SEPARATOR + e
      if e =~ /\.torrent$/
        puts "Starting .torrent '#{path}'"
        startTorrentFile(path)
      elsif e =~ /\.magnet$/   
        magnet = loadMagnet(path)
        puts "Starting magnet '#{magnet.raw}'"
        startMagnet magnet
      end
    end
  end

  # Convert torrent data such that:
  # - The TorrentDataDelegate objects are converted to hashes.
  def simplifiedTorrentData
    result = {}
    torrentData.each do |k,d|
      h = d.to_h
      asciiInfoHash = QuartzTorrent::bytesToHex(h[:infoHash])
      h[:infoHash] = asciiInfoHash
      h[:downloadRate] = QuartzTorrent::Formatter.formatSpeed(h[:downloadRate])
      h[:uploadRate] = QuartzTorrent::Formatter.formatSpeed(h[:uploadRate])
      h[:downloadRateDataOnly] = QuartzTorrent::Formatter.formatSpeed(h[:downloadRateDataOnly])
      h[:uploadRateDataOnly] = QuartzTorrent::Formatter.formatSpeed(h[:uploadRateDataOnly])
      h[:dataLength] = QuartzTorrent::Formatter.formatSize(h[:dataLength])
      h[:completedBytes] = QuartzTorrent::Formatter.formatSize(h[:completedBytes])
      h[:peers].each do |p| 
        p[:uploadRate] = QuartzTorrent::Formatter.formatSpeed(p[:uploadRate])
        p[:downloadRate] = QuartzTorrent::Formatter.formatSpeed(p[:downloadRate])
      end
      result[asciiInfoHash] = h
    end
    result
  end

  # Download a .torrent file from a specified URL. Return the path to the 
  # downloaded .torrent file.
  def downloadTorrentFile(url)
    # open-uri doesn't handle [ and ] properly
    encodedSourcePath = URI.escape(url, /[\[\]]/)

    path = nil
    open(encodedSourcePath) do |f|
      uriPath = f.base_uri.path
      raise "The file '#{uriPath}' doesn't have the .torrent extension" if uriPath !~ /.torrent$/
      path = @torrentFileDir + File::SEPARATOR + File.basename(uriPath)
      File.open(path, "w"){ |outfile| outfile.write(f.read) }
    end
    path
  end

  # Store a magnet link in a file in the torrent file directory.
  def storeMagnet(magnet)
    asciiInfoHash = QuartzTorrent::bytesToHex(magnet.btInfoHash)
    path = @torrentFileDir + File::SEPARATOR + asciiInfoHash + ".magnet"
    File.open(path, "w"){ |outfile| outfile.write(magnet.raw) }
  end

  # Load a magnet link in a file 
  def loadMagnet(path)
    raw = nil
    File.open(path, "r"){ |infile| raw = infile.read }
    QuartzTorrent::MagnetURI.new(raw)
  end

  # Store an uploaded .torrent file in the torrent directory. Return the path to the 
  # final .torrent file.
  def storeUploadedTorrentFile(path, name)
    name += ".torrent" if name !~ /\.torrent$/
    dpath = @torrentFileDir + File::SEPARATOR + name
    FileUtils.mv path, dpath
    dpath
  end

  # Start running the torrent specified by the .torrent file given in path.
  def startTorrentFile(path)
    startTorrent do
      begin
        metainfo = QuartzTorrent::Metainfo.createFromFile(path)
        @peerClient.addTorrentByMetainfo(metainfo)
      rescue BEncode::DecodeError
        # Delete the file
        begin
          FileUtils.rm path
        rescue
        end
        raise $!
      end
    end
  end

  # Start running the magnet
  def startMagnet(magnet)
    startTorrent do
      @peerClient.addTorrentByMagnetURI(magnet)
    end
  end

  # Remove the specified torrent. Pass the infoHash as an ascii string, not binary.
  def removeTorrent(infoHash, deleteFiles)
    infoHashBytes = QuartzTorrent::hexToBytes(infoHash)
    @peerClient.removeTorrent infoHashBytes, deleteFiles

    # Remove torrent from torrent dir
    Dir.new(@torrentFileDir).each do |e|
      if e =~ /\.torrent$/
        path = @torrentFileDir + File::SEPARATOR + e
        metainfo = Metainfo.createFromFile(path)
        if metainfo.infoHash == infoHashBytes
          FileUtils.rm path
          break
        end
      end
    end
    
    # Remove magnet file if it exists
    magnetFile = @torrentFileDir + File::SEPARATOR + infoHash + ".magnet"
    FileUtils.rm magnetFile if File.exists?(magnetFile)
  end

  private
  # Helper for starting torrents. Expects a block that when called will add a torrent to the 
  # @peerClient, and return the infoHash.
  def startTorrent
    raise "Torrent client is shutting down" if @peerClientStopped
    helper = SettingsHelper.new
    infoHash = yield 
    @peerClient.setUploadRateLimit infoHash, to_i(helper.get(:defaultUploadRateLimit, :unfiltered))
    @peerClient.setDownloadRateLimit infoHash, to_i(helper.get(:defaultDownloadRateLimit, :unfiltered))
  end

  def to_i(val)
    val = val.to_i if val
    val
  end

end
