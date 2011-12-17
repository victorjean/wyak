class Item
  include MongoMapper::Document
  
  key :name, String, :required => true
end
