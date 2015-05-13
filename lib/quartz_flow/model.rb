require 'data_mapper'

class Setting
  include DataMapper::Resource

  property :id,     Serial
  property :name,   String
  property :value,  String
  property :scope,  Enum[:global, :user, :torrent]
  # For settings that are not global, owner identifies who they apply to.
  # For user settings, this is the user. For torrent settings this is the torrent infohash in hex ascii
  property :owner,  String
end

class UsageBucket
  include DataMapper::Resource

  property :id,             Serial
  property :type,           Enum[:daily, :monthly]
  property :index,          Integer
  property :label,          String
  property :criteriaData,   DateTime
  property :absoluteUsage,  Integer
  property :value,          Integer
end

DataMapper.finalize
