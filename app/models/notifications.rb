class Notifications < ActionMailer::Base

  def em_password(to, login, pass, sent_at = Time.now)
    @subject    = "RotoStarter Password Reset"
    @login=login
    @pass=pass
    @recipients = to
    @from       = 'support@rotostarter.com'
    @sent_on    = sent_at
    @headers    = {}
  end
  
  def em_error(em,method,message,team, sent_at = Time.now)
    @subject    = "RotoStarter System Error"
    @message = message
    @em = em
    @method = method
    @team = team
    @recipients = 'victor.jean@gmail.com,leonard.li@gmail.com'
    @from       = 'support@rotostarter.com'
    @sent_on    = sent_at
    @headers    = {}
  end
  
  def em_found(em,method,message,sites, sent_at = Time.now)
    @subject    = "MCAT Testing Site Available "+message
    @message = message 
    @em = em
    @method = method
    @sites = sites
    @recipients = 'victor.jean@gmail.com,jairam.ronald@gmail.com'
    @from       = 'support@rotostarter.com'
    @sent_on    = sent_at
    @headers    = {}
    @content_type = 'text/html'
  end
  
end
