class AuthInfo
  include MongoMapper::Document
  
  key :email, String, :required => true
  key :login, String, :required => true
  key :pass, String, :required => true
  key :auth_type, String, :required => true
  key :salt, String
  many :teams
  
  attr_accessor :password
  
  def password=(p)
    @password=p
    self.salt = random_string(10) if !self.salt?
    self.pass = Base64::encode64(@password+'|||||'+self.salt)
    
  end

  def get_pass()
    Base64::decode64(self.pass).to_s.split('|||||').first
  end
  
  def random_string(len)
    #generate a random password consisting of strings and digits
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
    return newpass
  end

  
end
