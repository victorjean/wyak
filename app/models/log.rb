class Log
  include MongoMapper::Document
  
  key :type, String
  key :email, String
  key :league_id, String
  key :team_id, String
  key :method, String
  key :msg, String
  
  timestamps!
end
