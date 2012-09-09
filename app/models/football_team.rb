class FootballTeam
  include MongoMapper::Document
  plugin MongoMapper::Plugins::IdentityMap
  
  key :team_id, String, :required => true
  key :league_id, String, :required => true
  key :team_type, String, :required => true
  key :league_name,String
  key :team_name, String
  key :active, Boolean, :default=>true
  key :start_type, String, :default=>'projected' 
  key :empty_team, Boolean, :default=>false
  key :auto_start, Boolean, :default=>false
  belongs_to :auth_info
  belongs_to :user_info
  
  timestamps!
  
end
