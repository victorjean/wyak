class FootballPlayerStats
  include MongoMapper::Document
  
  key :full_name, String
  key :position, String
  key :team, String
  key :yahoo_id, String
  key :espn_id, String
  key :owned, Integer
  key :pos_rank, Hash
  key :rank, Integer
  key :rank1, Integer, :default => 9999
  key :rank2, Integer, :default => 9999
  key :rank3, Integer, :default => 9999
  
  key :rank_change1, Integer, :default => 0
  key :rank_change2, Integer, :default => 0
  key :rank_change3, Integer, :default => 0
  
  key :pass_yds,  Integer, :default => 0
  key :pass_td,  Integer, :default => 0
  key :intercept,  Integer, :default => 0
  key :rush_yds,  Integer, :default => 0
  key :rush_td,  Integer, :default => 0
  key :rec,  Integer, :default => 0
  key :rec_yds,  Integer, :default => 0
  key :rec_td,  Integer, :default => 0
  key :ret_td,  Integer, :default => 0
  key :two_point,  Integer, :default => 0
  key :fumble,  Integer  , :default => 0
  key :pts_allow,  Integer, :default => 0
  key :sack,  Float, :default => 0
  key :safe,  Integer, :default => 0
  key :def_int,  Integer, :default => 0
  key :def_fumble,  Integer, :default => 0
  key :def_td,  Integer, :default => 0
  key :def_ret_td,  Integer, :default => 0
  key :block_kick,  Integer, :default => 0
  key :fg10,  Integer, :default => 0
  key :fg20,  Integer, :default => 0
  key :fg30,  Integer, :default => 0
  key :fg40,  Integer, :default => 0
  key :fg50,  Integer, :default => 0
  key :pat,  Integer, :default => 0
  
  key :scratched, Boolean, :default=>false
  key :processed, Boolean, :default=>false
  
  
  many :football_players
  #many :player_realtimes
end
