class UserInfo
  include MongoMapper::Document
  
  key :email, String, :required => true
  key :pass, String, :required => true
  key :yahoo_enabled, Boolean, :default=>false
  key :espn_enabled, Boolean, :default=>false
  key :cbs_enabled, Boolean, :default=>false
  key :login_count, Integer, :default=>0
  many :teams
  timestamps!
end
