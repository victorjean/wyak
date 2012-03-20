class AuthInfo
  include MongoMapper::Document
  
  key :email, String, :required => true
  key :login, String, :required => true
  key :pass, String, :required => true
  key :auth_type, String, :required => true
  many :teams

  
end
