require 'quartz_torrent/magnet'

module BEncode
  class DecodeError
  end
end


module QuartzTorrent
  class Words
    def initialize
      @words = []
      File.open "/usr/share/dict/words", "r" do |file|
        file.each_line do |l|
          @words.push l.chomp
        end
      end
    end

    def randomWord
      @words[rand(@words.size)]
    end
  end

  class Metainfo

    def self.createFromFile(file)
    end

    class FileInfo
      def initialize(length = nil, path = nil)
        @length = length
        @path = path
      end
        
      # Relative path to the file. For a single-file torrent this is simply the name of the file. For a multi-file torrent,
      # this is the directory names from the torrent and the filename separated by the file separator.
      attr_accessor :path
      # Length of the file.
      attr_accessor :length
    end 

    class Info
      def initialize
        @files = []
        @name = nil
        @pieceLen = 0
        @pieces = []
        @private = false
      end
    
      # Array of FileInfo objects
      attr_accessor :files
      # Suggested file or directory name
      attr_accessor :name
      # Length of each piece in bytes. The last piece may be shorter than this.
      attr_accessor :pieceLen
      # Array of SHA1 digests of all peices. These digests are in binary format. 
      attr_accessor :pieces
      # True if no external peer source is allowed.
      attr_accessor :private

      # Total length of the torrent data in bytes.
      def dataLength
        files.reduce(0){ |memo,f| memo + f.length}
      end
    end
  end

  class TrackerPeer
    def initialize(ip, port, id = nil)
      @ip = ip
      @port = port
      @id = id
    end

    attr_accessor :ip
    attr_accessor :port
    attr_accessor :id
  end

  class Peer
    def initialize(trackerPeer)
      @trackerPeer = trackerPeer
      @amChoked = true
      @amInterested = false
      @peerChoked = true
      @peerInterested = false
      @infoHash = nil
      @state = :disconnected
      @uploadRate = 0
      @downloadRate = 0
      @uploadRateDataOnly = 0
      @downloadRateDataOnly = 0
      @bitfield = nil
      @firstEstablishTime = nil
      @isUs = false
      @requestedBlocks = {}
      @requestedBlocksSizeLastPass = nil
      @maxRequestedBlocks = 50
    end

    attr_accessor :trackerPeer
    attr_accessor :amChoked
    attr_accessor :amInterested
    attr_accessor :peerChoked
    attr_accessor :peerInterested
    attr_accessor :infoHash
    attr_accessor :firstEstablishTime
    attr_accessor :maxRequestedBlocks
    attr_accessor :state
    attr_accessor :isUs
    attr_accessor :uploadRate
    attr_accessor :downloadRate
    attr_accessor :uploadRateDataOnly
    attr_accessor :downloadRateDataOnly
    attr_accessor :bitfield
    attr_accessor :requestedBlocks
    attr_accessor :requestedBlocksSizeLastPass
    attr_accessor :peerMsgSerializer
  end

  class TorrentDataDelegate
    # Create a new TorrentDataDelegate. This is meant to only be called internally.
    def initialize
      @info = nil
      @infoHash = nil
      @recommendedName = nil
      @downloadRate = nil
      @uploadRate = nil
      @downloadRateDataOnly = nil
      @uploadRateDataOnly = nil
      @completedBytes = nil
      @peers = nil
      @state = nil
      @completePieceBitfield = nil
      @metainfoLength = nil
      @metainfoCompletedLength = nil
      @paused = nil
    end

    # Torrent Metainfo.info struct. This is nil if the torrent has no metadata and we haven't downloaded it yet
    # (i.e. a magnet link).
    attr_accessor :info
    attr_accessor :infoHash
    # Recommended display name for this torrent.
    attr_accessor :recommendedName
    attr_accessor :downloadRate
    attr_accessor :uploadRate
    attr_accessor :downloadRateDataOnly
    attr_accessor :uploadRateDataOnly
    attr_accessor :completedBytes
    attr_accessor :peers
    # State of the torrent. This may be one of :downloading_metainfo, :error, :checking_pieces, :running, :downloading_metainfo, or :deleted.
    # The :deleted state indicates that the torrent that this TorrentDataDelegate refers to is no longer being managed by the peer client.
    attr_accessor :state
    attr_accessor :completePieceBitfield
    # Length of metainfo info in bytes. This is only set when the state is :downloading_metainfo
    attr_accessor :metainfoLength
    # How much of the metainfo info we have downloaded in bytes. This is only set when the state is :downloading_metainfo
    attr_accessor :metainfoCompletedLength
    attr_accessor :paused
  end

  class PeerClient
    def initialize(ignored)
      @words = Words.new
      @torrents = {}
      7.times{ addTorrent }
      Thread.new do
        while true
          begin
            @torrents.each{ |k,t| t.downloadRate += (rand(1000) - 500)}
          rescue
            puts "Exception in Mock PeerClient: #{$!}" 
          end
          sleep 2
        end
      end
    end

    def port=(p)
    end

    def start
    end

    def stop
    end

    def addTorrentByMetainfo(info)
    end

    def torrentData(infoHash = nil)
      @torrents
    end

    def addTorrent
      d = makeFakeTorrentDelegate
      @torrents[d.infoHash] = d
    end

    private
    def makeFakeTorrentDelegate
      result = TorrentDataDelegate.new
      name = ""
      (rand(3)+1).times do 
        name << @words.randomWord + " "
      end
      result.recommendedName = name
      result.infoHash = randomBinaryData 20
      result.downloadRate = 100*1024
      result.uploadRate = 5*1024
      result.downloadRateDataOnly = 100*1024
      result.uploadRateDataOnly = 5*1024
      result.completedBytes = 800
      result.peers = []
      result.state = :running
      result.paused = false

      result.info = Metainfo::Info.new
      result.info.files = [Metainfo::FileInfo.new(1000, "file1"), Metainfo::FileInfo.new(1000, "file2")]

      3.times do
        
        peer = Peer.new(TrackerPeer.new("176.23.54.201", 5000))
        peer.amChoked = false
        peer.amInterested = false
        peer.peerChoked = false
        peer.peerInterested = true
        peer.uploadRate = 20*1024
        peer.downloadRate = 10*1024
    
        result.peers.push peer
      end

      result
    end

    def randomBinaryData(len)
      result = ""
      len.times{ result << rand(256) }
      result
    end
  end
end

