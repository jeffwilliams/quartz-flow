require 'quartz_flow/model'
require 'quartz_torrent/formatter'

class SettingsHelper
  class SettingMetainfo
    def initialize(name, scope, saveFilter = nil, loadFilter = nil, emptyIsNil = true)
      @name = name
      @scope = scope
      @saveFilter = saveFilter
      @loadFilter = loadFilter
      @emptyIsNil = emptyIsNil
    end
    attr_accessor :name
    attr_accessor :scope
    # If the value is empty, treat it as a nil value when writing to database
    def emptyIsNil?
      @emptyIsNil
    end
    def filterOnSave(v)
      filter @saveFilter, v
    end
    def filterOnLoad(v)
      filter @loadFilter, v
    end
    private
    def filter(afilter, v)
      if afilter && v
        afilter.call(v)
      else
        v
      end
    end
  end

  @@floatValidator = Proc.new do |v|
    raise "Invalid ratio" if v !~ /^\d+(\.\d+)?$/
    v.to_s
  end

  @@saveFilterForSize = Proc.new do |v|
    if v.nil? || v.length == 0
      nil
    else
      QuartzTorrent::Formatter.parseSize(v) 
    end
  end

  @@saveFilterForDuration = Proc.new do |v|
    if v.nil? || v.length == 0
      nil
    else
      QuartzTorrent::Formatter.parseTime(v) 
    end
  end

  @@settingsMetainfo = {
    :defaultUploadRateLimit => SettingMetainfo.new(
      :defaultUploadRateLimit,
      :global,
      @@saveFilterForSize,
      Proc.new{ |v| QuartzTorrent::Formatter.formatSpeed(v) }
    ),
    :defaultDownloadRateLimit => SettingMetainfo.new(
      :defaultDownloadRateLimit,
      :global,
      @@saveFilterForSize,
      Proc.new{ |v| QuartzTorrent::Formatter.formatSpeed(v) }
    ),
    :defaultRatio => SettingMetainfo.new(
      :defaultRatio,
      :global,
      @@floatValidator,
      Proc.new{ |v| v.to_f }
    ),
    :defaultUploadDuration => SettingMetainfo.new(
      :defaultUploadDuration,
      :global,
      @@saveFilterForDuration,
      Proc.new{ |v| QuartzTorrent::Formatter.formatTime(v) }
    ),
    :uploadRateLimit => SettingMetainfo.new(
      :uploadRateLimit,
      :torrent,
      @@saveFilterForSize,
      Proc.new{ |v| QuartzTorrent::Formatter.formatSpeed(v) }
    ),
    :downloadRateLimit => SettingMetainfo.new(
      :downloadRateLimit,
      :torrent,
      @@saveFilterForSize,
      Proc.new{ |v| QuartzTorrent::Formatter.formatSpeed(v) }
    ),
    :ratio => SettingMetainfo.new(
      :ratio,
      :torrent,
      @@floatValidator,
      Proc.new{ |v| v.to_f }
    ),
    :uploadDuration => SettingMetainfo.new(
      :uploadDuration,
      :torrent,
      @@saveFilterForDuration,
      Proc.new{ |v| QuartzTorrent::Formatter.formatTime(v) }
    ),
    :paused => SettingMetainfo.new(
      :paused,
      :torrent,
      Proc.new{ |v| v.to_s },
      Proc.new{ |v| v.downcase == "true" }
    ),
    :bytesUploaded => SettingMetainfo.new(
      :bytesUploaded,
      :torrent,
      Proc.new{ |v| v.to_s },
      Proc.new{ |v| v.to_i }
    ),
    :bytesDownloaded => SettingMetainfo.new(
      :bytesDownloaded,
      :torrent,
      Proc.new{ |v| v.to_s},
      Proc.new{ |v| v.to_i }
    ),
    :itemsPerPage => SettingMetainfo.new(
      :itemsPerPage,
      :global,
    ),
  }

  def set(settingName, value, owner = nil)
    setting = settingName.to_sym

    metaInfo = @@settingsMetainfo[setting]
    raise "Unknown setting #{settingName}" if ! metaInfo

    value = nil if metaInfo.emptyIsNil? && value.is_a?(String) && value.length == 0
    value = value.to_s if value
    value = metaInfo.filterOnSave(value)
    
    settingModel = loadWithOwner(settingName, owner)

    if ! settingModel
      settingModel = Setting.create( :name => settingName, :value => value, :scope => metaInfo.scope, :owner => owner )
      settingModel.save
    else
      settingModel.value = value
      settingModel.save
    end
  end

  def get(settingName, filter = :filter, owner = nil)
    setting = settingName.to_sym
    metaInfo = @@settingsMetainfo[setting]
    raise "Unknown setting #{settingName}" if ! metaInfo

    result = nil
    settingModel = loadWithOwner(settingName, owner)
    
    if settingModel
      result = settingModel.value
      result = metaInfo.filterOnLoad(result) if filter == :filter
    end
    result
  end

  def deleteForOwner(owner)
    Setting.all(:owner => owner).destroy!
  end

  # Return a hashtable of all global settings
  def globalSettingsHash
    result = {}

    @@settingsMetainfo.each do |k,v|
      next if v.scope != :global
      result[k] = get(k)
    end
    
    result
  end

  # Set global settings as a hash
  def setGlobalSettingsHash(hash)
    @@settingsMetainfo.each do |k,v|
      set(k, hash[k.to_s]) if hash.has_key?(k.to_s)
    end
  end

  private
  def loadWithOwner(settingName, owner)
    if owner
      Setting.first(:name => settingName, :owner => owner)
    else
      Setting.first(:name => settingName)
    end
  end
end
