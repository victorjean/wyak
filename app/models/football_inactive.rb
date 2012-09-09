class FootballInactive
  include MongoMapper::Document
  
  key :team, String
  key :full_name, String
  key :position, String
  key :inactive, Boolean
  key :week, Integer 
  key :processed, Boolean, :default=>false 
  
  timestamps!
  
end
