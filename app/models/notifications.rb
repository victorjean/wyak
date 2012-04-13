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
  
end
