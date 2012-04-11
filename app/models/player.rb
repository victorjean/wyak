class Player
  include MongoMapper::Document
  
  key :team_type, String, :required=>true
  key :league_id, String, :required=>true
  key :team_id, String, :required=>true
  key :yahoo_id, String
  key :espn_id, String
  key :assign_pos, String
  key :eligible_pos, Array
  key :game_status, String, :default=>"TBD"
  key :game_today, Boolean, :default=>false
  key :in_lineup, Boolean, :default=>false
  key :action, String, :default=>""
  key :priority, Integer, :default => 99
  key :assign_slot, String
  key :current_slot, String
  key :eligible_slot, Array
  key :player_set, Boolean, :default=>false
  key :current_date, Date
  key :full_name, String
  key :team_name, String
  key :position_text, String
  key :temp_pos, String
  key :temp_slot, String
  key :scratched, Boolean, :default=>false
  belongs_to :roster
  belongs_to :player_stats
end
