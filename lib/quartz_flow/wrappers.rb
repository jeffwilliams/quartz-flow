require 'quartz_torrent/formatter.rb'

module QuartzTorrent

  class Metainfo::FileInfo
    def to_h
      { path: @path, length: @length }
    end
  end

  class Metainfo::Info
    def to_h
      result = {}

      result[:name] = @name
      result[:pieceLen] = @pieceLen
      result[:files] = @files.collect{ |e| e.to_h }

      result
    end
  end

  class TrackerPeer
    def to_h
      { ip: @ip, port: @port }
    end
  end

  class Peer
    def to_h
      result = {}
      
      result[:trackerPeer] = @trackerPeer.to_h
      result[:amChoked] = @amChoked
      result[:amInterested] = @amInterested
      result[:peerChoked] = @peerChoked
      result[:peerInterested] = @peerInterested
      result[:firstEstablishTime] = @firstEstablishTime
      result[:maxRequestedBlocks] = @maxRequestedBlocks
      result[:state] = @state
      result[:isUs] = @isUs
      result[:uploadRate] = @uploadRate
      result[:downloadRate] = @downloadRate
      if @bitfield
        result[:pctComplete] = "%.2f" % (100.0 * @bitfield.countSet / @bitfield.length)
      else
        result[:pctComplete] = 0
      end

      result
    end
  end

  class Alarm
    def to_h
      result = {}
      result[:details] = @details
      result[:time] = @time
      result
    end
  end

  class TorrentDataDelegate
    # Convert to a hash. Also flattens some of the data into new fields.
    def to_h
      result = {}

      ## Extra fields added by this method:
      # Length of the torrent
      result[:dataLength] = @info ? @info.dataLength : 0
      # Percent complete
      pct = withCurrentAndTotalBytes{ |cur, total| (cur.to_f / total.to_f * 100.0).round 1 }
      result[:percentComplete] = pct
      # Time left
      secondsLeft = withCurrentAndTotalBytes do |cur, total|
        if @downloadRateDataOnly && @downloadRateDataOnly > 0
          (total.to_f - cur.to_f) / @downloadRateDataOnly 
        else
          0
        end
      end
      # Cap estimated time at 9999 hours
      secondsLeft = 35996400 if secondsLeft > 35996400
      result[:timeLeft] = Formatter.formatTime(secondsLeft)

      ## Regular fields
      result[:info] = @info ? @info.to_h : nil
      result[:infoHash] = @infoHash
      result[:recommendedName] = @recommendedName
      result[:downloadRate] = @downloadRate
      result[:uploadRate] = @uploadRate
      result[:downloadRateDataOnly] = @downloadRateDataOnly
      result[:uploadRateDataOnly] = @uploadRateDataOnly
      result[:completedBytes] = @completedBytes
      result[:peers] = @peers.collect{ |p| p.to_h }
      result[:state] = @state
      #result[:completePieceBitfield] = @completePieceBitfield
      result[:metainfoLength] = @metainfoLength
      result[:metainfoCompletedLength] = @metainfoCompletedLength
      result[:paused] = @paused
      result[:queued] = @queued
      result[:uploadRateLimit] = @uploadRateLimit
      result[:downloadRateLimit] = @downloadRateLimit
      result[:ratio] = @ratio
      result[:uploadDuration] = @uploadDuration
      result[:bytesUploaded] = @bytesUploaded
      result[:bytesDownloaded] = @bytesDownloaded
      result[:alarms] = @alarms.collect{ |a| a.to_h }

      result
    end

    private
    def withCurrentAndTotalBytes
      if @info
        yield @completedBytes, @info.dataLength
      elsif @state == :downloading_metainfo && @metainfoCompletedLength && @metainfoLength
        yield @metainfoCompletedLength, @metainfoLength
      else
        0
      end
    end
    

    def calcEstimatedTime(torrent)
      # Time left = amount_left / download_rate
      #           = total_size * (1-progress) / download_rate
      if torrentHandle.has_metadata && torrentHandle.status.download_rate.to_f > 0
      secondsLeft = torrentHandle.info.total_size.to_f * (1 - torrentHandle.status.progress.to_f) / torrentHandle.status.download_rate.to_f
      Formatter.formatTime(secondsLeft)
    else
      "unknown"
    end
  end 

  end
end

