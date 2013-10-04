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

  @@settingsMetainfo = {
    :defaultUploadRateLimit => SettingMetainfo.new(
      :defaultUploadRateLimit,
      :global,
      Proc.new{ |v| QuartzTorrent::Formatter.parseSize(v) },
      Proc.new{ |v| QuartzTorrent::Formatter.formatSpeed(v) }
    ),
    :defaultDownloadRateLimit => SettingMetainfo.new(
      :defaultDownloadRateLimit,
      :global,
      Proc.new{ |v| QuartzTorrent::Formatter.parseSize(v) },
      Proc.new{ |v| QuartzTorrent::Formatter.formatSpeed(v) }
    ),
  }

  def set(settingName, value)
    setting = settingName.to_sym

    metaInfo = @@settingsMetainfo[setting]
    raise "Unknown setting #{settingName}" if ! metaInfo

    value = nil if metaInfo.emptyIsNil? && value.is_a?(String) && value.length == 0
    value = value.to_s if value
    value = metaInfo.filterOnSave(value)
    
    settingModel = Setting.first(:name => settingName)
    if ! settingModel
      Setting.create( :name => settingName, :value => value, :scope => metaInfo.scope )
    else
      settingModel.value = value
      settingModel.save
    end
  end

  def get(settingName, filter = :filter)
    setting = settingName.to_sym
    metaInfo = @@settingsMetainfo[setting]
    raise "Unknown setting #{settingName}" if ! metaInfo

    result = nil
    settingModel = Setting.first(:name => settingName)
    if settingModel
      result = settingModel.value
      result = metaInfo.filterOnLoad(result) if filter == :filter
    end
    result
  end

  # Return a hashtable of all global settings
  def globalSettingsHash
    result = {}

    @@settingsMetainfo.each do |k,v|
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
end
