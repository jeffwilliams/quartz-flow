def showList
  interp = ShowNameInterpreter.new
  def filesUnder(dir)
    Dir.new(dir).each do |e|
      next if e[0,1] == '.'
      path = dir + "/" + e
      if File.directory?(path)
        filesUnder(path){ |f,d|
          yield f,d
        }
      else
        yield e, dir
      end
    end
  end

  filesUnder(settings.basedir) do |e, dir|
    if e[0,1] != '.'
      interp.addName(e, FilenameMetaInfo.new.setParentDir(dir))
    end
  end

  shows = interp.processNames

  showsForDisplay = []
  shows.keys.sort.each do |k|
    # Show name
    heading = k
    # Show episodes
    body = ""
    ranges = shows[k]
    season = nil
    comma = true
    ranges.episodeRanges.each do |r|
      if ! season || season != r.season
        body << "<br/>" if season
        body << "  Season #{r.season}: "
        season = r.season
        comma = false
      end
      body << "," if comma
      if r.size > 1
        body << " #{r.startEpisode}-#{r.endEpisode}"
      else
        body << " #{r.startEpisode}"
      end
      comma = true
    end
    showsForDisplay.push [heading, body]
  end
  showsForDisplay
end
