class Team
  include MongoMapper::Document
  plugin MongoMapper::Plugins::IdentityMap
  
  key :team_id, String, :required => true
  key :league_id, String, :required => true
  key :team_type, String, :required => true
  key :league_name,String
  key :team_name, String
  key :daily_auto_batter, Boolean, :default=>true
  key :daily_auto_pitcher, Boolean, :default=>true
  key :real_time_batter, Boolean, :default=>false
  key :real_time_pitcher, Boolean, :default=>false
  key :weekly_team, Boolean, :default=>false 
  key :empty_team, Boolean
  belongs_to :auth_info
  belongs_to :user_info
  
  timestamps!
  
end
