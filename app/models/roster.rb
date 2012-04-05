class Roster
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
  one :player
  
  before_update :set_player_update
  private 
  def set_player_update
    
    #Set Position Type to either PITCHER or BATTER
    if (self.pos_text.index(BENCH_PITCHER_TYPE).nil?)
      self.pos_type = BENCH_BATTER_TYPE
    else
      self.pos_type = BENCH_PITCHER_TYPE 
    end
    
    #If player is nil skip
    if (self.player.nil?)
      return
    end
    
    #Set Assigned Position and Slot to Player Object
    self.player.assign_pos = self.pos_text
    self.player.assign_slot = self.slot_number
    self.leave_empty = false    
    #Auto Populate if Action is Empty
    if (self.player.action == "")
        self.player.action = DEFAULT_START_OPTION
    end
    #If Player is not on Bench set priority to Zero
    if (self.player.assign_pos != BENCH_POSITION)
      self.player.priority = 0
    end
    
    #If Player Bench Make Sure Action is set Correctly
    if (self.player.assign_pos == BENCH_POSITION && (self.player.action == ALWAYS_START_OPTION ))
      self.player.action = DEFAULT_START_OPTION
    end
    
    if (self.player.assign_pos != BENCH_POSITION && (self.player.action == NEVER_START_OPTION ))
      self.player.action = DEFAULT_START_OPTION
    end

    
    
    #Set Position Type to either PITCHER or BATTER
    if (self.player.position_text.index(BENCH_PITCHER_TYPE).nil?)
      self.pos_type = BENCH_BATTER_TYPE
    else
      self.pos_type = BENCH_PITCHER_TYPE 
    end
    
    
    
    self.player.save
    
  end
end
