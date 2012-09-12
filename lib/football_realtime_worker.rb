require 'iron_worker'
require 'socket'


class FootballRealtimeWorker < IronWorker::Base
  
  merge_gem 'mongo'
  merge_gem 'mongo_mapper'
  merge_gem 'hpricot'
  merge_gem 'mechanize'
  merge_gem 'actionmailer',:require => 'action_mailer'
  unmerge_gem 'nokogiri'
  
  merge_folder "../app/models/"
  #unmerge "../app/models/notifications.rb"
  
  merge "fantasy_team_helper.rb"
  merge "football_team_helper.rb"
  
  attr_accessor :team_list

  def run
    
    MongoMapper.config = { 
    Rails.env => { 'uri' => 'mongodb://rotostarter:rotopass@ds031847.mongolab.com:31847/heroku_app2029342' } 
    }
    MongoMapper.connect(Rails.env)
    
    puts 'connected to mongo db'
    
    team_list.each do |t|
        begin
          team = FootballTeam.find_by_id(t)
          if (team.team_type == YAHOO_AUTH_TYPE)
            set_yahoo_inactive(team)
          end
          if (team.team_type == ESPN_AUTH_TYPE)
            set_espn_inactive(team)
          end
        rescue => msg
          puts "ERROR OCCURED (#{msg})"
          log_error('sys', team, 'footballrealtimeworker',msg)
        end 
      end
  end
  

end