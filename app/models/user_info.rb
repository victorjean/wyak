require 'digest/sha1'

class UserInfo
  include MongoMapper::Document
  plugin MongoMapper::Plugins::IdentityMap
  
  key :email, String, :required => true
  key :pass, String, :required => true
  key :salt, String, :required => true
  key :login_count, Integer, :default=>0
  key :subscribed, Boolean, :default=>false
  many :teams
  
  timestamps!
  
  validates_uniqueness_of :email
  validates_format_of :email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :message => "Invalid email format"
  validates_presence_of :password
  
  attr_accessor :password
  
  def self.authenticate(login, pass)
    u=find_by_email(login)
    return nil if u.nil?
     
    if UserInfo.encrypt(pass, u.salt)==u.pass
      u.password = pass
      u.login_count += 1
      u.save
      return u.email  
    end
    nil
  end  

  def password=(p)
    @password=p
    self.salt = UserInfo.random_string(10) if !self.salt?
    self.pass = UserInfo.encrypt(@password, self.salt)
  end

  protected

  def self.encrypt(pass, salt)
    Digest::SHA1.hexdigest(pass+salt)
  end
  
  def self.random_string(len)
    #generate a random password consisting of strings and digits
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
    return newpass
  end


end
