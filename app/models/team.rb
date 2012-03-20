class Team
  include MongoMapper::Document
  
  key :team_id, String, :required => true
  key :league_id, String, :required => true
  key :team_type, String, :required => true
  key :league_name,String
  key :team_name, String
  belongs_to :auth_info
  belongs_to :user_info
  
end
