class PlayerStats
  include MongoMapper::Document
  
  key :full_name, String
  key :position, String
  key :team, String
  key :yahoo_id, String
  key :espn_id, String
  key :owned, Integer
  key :ip, Float
  key :win, Integer
  key :sv, Integer
  key :k, Integer
  key :era, Float
  key :whip, Float
  key :hit, Integer
  key :ab, Integer
  key :run, Integer
  key :hr, Integer
  key :rbi, Integer
  key :sb, Integer
  key :avg, Float
  key :pos_rank, Hash
  key :rank, Integer
  key :rank1, Integer, :default => 9999
  key :rank2, Integer, :default => 9999
  key :rank3, Integer, :default => 9999
  key :rank4, Integer, :default => 9999
  key :rank5, Integer, :default => 9999
  key :rank6, Integer, :default => 9999
  key :rank7, Integer, :default => 9999
  key :rank_change, Integer, :default => 0
  key :scratched, Boolean, :default=>false
  key :processed, Boolean, :default=>false
  key :ip_7day, Float
  key :win_7day, Integer
  key :sv_7day, Integer
  key :k_7day, Integer
  key :era_7day, Float
  key :whip_7day, Float
  key :hit_7day, Integer
  key :ab_7day, Integer
  key :run_7day, Integer
  key :hr_7day, Integer
  key :rbi_7day, Integer
  key :sb_7day, Integer
  key :avg_7day, Float
  key :rank_7day, Integer
  key :is_sp, Boolean, :default=>false
  
  many :players
  many :player_realtimes
end
