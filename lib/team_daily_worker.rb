require 'iron_worker'



class TeamDailyWorker < IronWorker::Base
  
  merge_gem 'mongo'
  merge_gem 'mongo_mapper'
  merge_gem 'hpricot'
  merge_gem 'mechanize'
  unmerge_gem 'nokogiri'
  
  merge_folder "../app/models/"
  unmerge "../app/models/notifications.rb"
  
  merge "fantasy_team_helper.rb"
  merge "real_time_helper.rb"
  
  attr_accessor :team_list

  def run
    
    MongoMapper.config = { 
    Rails.env => { 'uri' => 'mongodb://rotostarter:rotopass@ds031847.mongolab.com:31847/heroku_app2029342' } 
    }
    MongoMapper.connect(Rails.env)
    
    puts 'connected to mongo db'
    
    team_list.each do |t|
        begin
          team = Team.find_by_id(t)
          if (team.team_type == YAHOO_AUTH_TYPE)
            set_yahoo_default(team,false)
          end
          if (team.team_type == ESPN_AUTH_TYPE)
            set_espn_default(team, false)
          end
        rescue => msg
          puts "ERROR OCCURED (#{msg})"
          log_error('sys', team, 'dailyworker',msg)
        end 
      end
  end
  

end