class Game
  include MongoMapper::Document
  
  key :game_id, String
  
  timestamps!
  
end
