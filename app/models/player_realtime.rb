class PlayerRealtime
  include MongoMapper::Document
  
  key :full_name, String
  key :assign_pos, String
  key :game_status, String, :default=>"TBD"
  key :game_today, Boolean, :default=>false
  key :assign_slot, String
  key :current_slot, String
  key :position_text, String
  key :eligible_slot, Array
  key :player_set, Boolean, :default=>false
  key :scratched, Boolean, :default=>false
  key :on_dl, Boolean
  key :espn_id, String
  key :yahoo_id, String
  
  belongs_to :team
  belongs_to :player_stats
  belongs_to :player
  
end
