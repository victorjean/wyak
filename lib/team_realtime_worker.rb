require 'iron_worker'


class TeamRealtimeWorker < IronWorker::Base
  
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
    #user_info = UserInfo.find_by_email("demo@example.com")
    #puts user_info.inspect
    
    espn_team_list = Team.where(:auth_info_id=>"4f6509368a92f11c94000001").all
    
    espn_team_list.each do |t|
        begin
          if (t.team_type == YAHOO_AUTH_TYPE)
            parse_yahoo_team(t, false, true)
          end
          if (t.team_type == ESPN_AUTH_TYPE)
            parse_espn_team(t, false, true)
          end
        rescue => msg
          puts "ERROR OCCURED (#{msg})"
          log_error('sys', t, 'realtimeworker',msg)
        end 
      end
  end
  

end