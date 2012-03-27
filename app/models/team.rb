class Team
  include MongoMapper::Document
  
  key :team_id, String, :required => true
  key :league_id, String, :required => true
  key :team_type, String, :required => true
  key :league_name,String
  key :team_name, String
  key :daily_auto_batter, Boolean, :default=>true
  key :daily_auto_pitcher, Boolean, :default=>true
  key :empty_team, Boolean
  belongs_to :auth_info
  belongs_to :user_info
  
end
