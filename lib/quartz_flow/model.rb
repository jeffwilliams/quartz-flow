require 'data_mapper'


class Setting
  include DataMapper::Resource

  property :id,     Serial
  property :name,   String
  property :value,  String
  property :scope,  Enum[:global, :user]
end

DataMapper.finalize
