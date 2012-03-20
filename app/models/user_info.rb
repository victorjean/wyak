class UserInfo
  include MongoMapper::Document
  
  key :email, String, :required => true
  key :pass, String, :required => true
  key :yahoo_enabled, Boolean
  key :espn_enabled, Boolean
  key :cbs_enabled, Boolean
  many :teams
end
