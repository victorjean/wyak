class FootballRoster
  include MongoMapper::Document
  
  key :team_type, String, :required=>true
  key :league_id, String, :required=>true
  key :team_id, String, :required=>true
  key :season_id, String
  key :order, Integer, :numeric => true
  key :pos_text, String
  key :slot_number, String
  key :pos_type, String
  key :leave_empty, Boolean, :default=>false
  key :elig_players, Array
  one :football_player
  
  before_update :set_football_player_update
  private 
  def set_football_player_update
    
    
    #If player is nil skip
    if (self.football_player.nil?)
      return
    end
    
    #Set Assigned Position and Slot to Player Object
    self.football_player.assign_pos = self.pos_text
    self.football_player.assign_slot = self.slot_number
    self.leave_empty = false    
    #Auto Populate if Action is Empty
    if (self.football_player.action == "")
        self.football_player.action = DEFAULT_START_OPTION
    end

    
    #If Player Bench Make Sure Action is set Correctly
    if (self.football_player.assign_pos == BENCH_POSITION && (self.football_player.action == ALWAYS_START_OPTION ))
      self.football_player.action = DEFAULT_START_OPTION
    end
    
    if (self.football_player.assign_pos != BENCH_POSITION && (self.football_player.action == NEVER_START_OPTION ))
      self.football_player.action = DEFAULT_START_OPTION
    end


    
    
    
    self.football_player.save
    
  end
end
