# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Wyak::Application.initialize!


ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.smtp_settings = {
:address => 'smtpout.secureserver.net',
:domain  => 'www.rotostarter.com',
:port      => 80,
:user_name => 'support@rotostarter.com',
:password => 'setty99*',
:authentication => :plain
}