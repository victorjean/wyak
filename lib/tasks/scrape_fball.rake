require "football_team_helper"
require "fantasy_team_helper"
require "iron_worker"
require 'football_daily_worker'
require 'football_realtime_worker'



namespace :football do
  desc "Fetch players."
  task :espnteams => :environment do    
    user_info = UserInfo.find_by_email("victor.jean@gmail.com")
    load_espn_football_teams(user_info, true)    
  end
end

namespace :football do
  desc "Fetch players."
  task :yahooteams => :environment do    
    user_info = UserInfo.find_by_email("victor.jean@gmail.com")
    load_yahoo_football_teams(user_info, true)    
  end
end

namespace :football do
  desc "Fetch players."
  task :parse_espn => :environment do    
    team_parse = FootballTeam.find_by_league_id("856806")
    parse_espn_football_team(team_parse, false)    
  end
end

namespace :football do
  desc "Fetch players."
  task :parse_yahoo => :environment do    
    team_parse = FootballTeam.find_by_league_id("388110")
    
    parse_yahoo_football_team(team_parse, false)    
  end
end

namespace :football do
  desc "Fetch players."
  task :full_espn => :environment do
    user_info = UserInfo.find_by_email("victor.jean@gmail.com")    
    load_espn_football_first_time(user_info)
  end
end

namespace :football do
  desc "Fetch players."
  task :full_yahoo => :environment do
    user_info = UserInfo.find_by_email("victor.jean@gmail.com")    
    load_yahoo_football_first_time(user_info)
  end
end

namespace :football do
  desc "Fetch players."
  task :set_yahoo_lineup => :environment do
    team_parse = FootballTeam.find_by_league_id("388110")
    set_yahoo_inactive(team_parse)
  end
end

namespace :football do
  desc "Fetch players."
  task :set_espn_lineup => :environment do
    team_parse = FootballTeam.find_by_league_id("856806")
    set_espn_inactive(team_parse)
  end
end

namespace :football do
  desc "Iron Uploader for Daily Process"
  task :dailyworker => :environment do
    
    start = Time.now
    puts start
    
    worker = FootballDailyWorker.new
    worker.team_list = []
    worker.upload
      
    finish = Time.now
    puts finish
    puts finish-start 
  end
end

namespace :football do
  desc "Iron Uploader for Daily Process"
  task :realtimeworker => :environment do
    
    start = Time.now
    puts start
    
    worker = FootballRealtimeWorker.new
    worker.team_list = []
    worker.upload
      
    finish = Time.now
    puts finish
    puts finish-start 
  end
end

namespace :football do
  desc "Fetch players."
  task :parse_inactive_page => :environment do
    #Heroku Server is Pacific Time  -7 from UTC
    week = get_week()
    current_time = Time.now
    week_day = current_time.wday
    current_hour = current_time.hour
    
    puts current_time
    puts "Current Week #{week}"
    puts "Current Day #{week_day}"    
    puts "Current Hour #{current_hour}"
    
    
    parse_bool = true
    
    #For Thursday 4 Scrape Inactive List Between 16 and 18
    if (week_day == 4 && (current_hour >= 16 && current_hour< 18))
      parse_bool = false
    end
    #For Sunday 0 Scrape Inactive List Between 9 and 11,  12 and 14, 16 and 18
    if (week_day == 0 && (current_hour >= 9 && current_hour< 11))
      parse_bool = false
    end
    if (week_day == 0 && (current_hour >= 12 && current_hour< 14))
      parse_bool = false
    end
    if (week_day == 0 && (current_hour >= 16 && current_hour< 18))
      parse_bool = false
    end
    #For Monday 1 Scrape Inactive List Between 16 and 18
    if (week_day == 1 && (current_hour >= 16 && current_hour< 18))
      parse_bool = false
    end
    #For Thursday 4 Week 12 Scrape Inactive List Between  8 and 10,  12 and 14, 16 and 18
    if (week_day == 4 && week == 12 && (current_hour >= 8 && current_hour< 10))
      parse_bool = false
    end
    if (week_day == 4 && week == 12 && (current_hour >= 12 && current_hour< 14))
      parse_bool = false
    end
    if (week_day == 4 && week == 12 && (current_hour >= 16 && current_hour< 18))
      parse_bool = false
    end
    #For Saturday 6 Week 16 Scrape Inactive List  Between 16 and 18
    if (week_day == 6 && week == 16 && (current_hour >= 16 && current_hour< 18))
      parse_bool = false
    end
    
    if (parse_bool)
      puts 'Not within time range - Will Not Parse Inactive Page'
    end
    
                      
    team_list = {}
    parse_inactive_page()
    
    #Get Scratched Player List
    inactive_list = FootballInactive.find_all_by_inactive_and_processed_and_week(true,false,week)
    inactive_list.each do |plyr|
           
        stat = FootballPlayerStats.find_by_full_name_and_team(plyr.full_name,plyr.team)
        if (!stat.nil?)
          puts stat.full_name + '- Found'
          plyr.processed = true
          plyr.save
          stat.football_players.each do |p|
            puts "#{p.full_name} - |#{p.assign_pos}|"
            p.scratched = true
            p.save
            if(!p.football_team.nil? && !p.on_dl && p.assign_pos!=IR_POSITION && p.assign_pos!=ESPN_IR_SLOT)
              #Only Add to List of Team is Active
              if (p.football_team.active)
                if (team_list[p.football_team.auth_info_id].nil?)
                  team_list[p.football_team.auth_info_id] = []
                end 
                if (team_list[p.football_team.auth_info_id].index(p.football_team._id).nil?)
                  team_list[p.football_team.auth_info_id].push(p.football_team._id)
                end
                log_info('sys', p.football_team, 'inactive',p.full_name)
              end
            end
          end
        else
          #puts plyr.full_name + '- Not Found'
        end  
        
    end  #End Player Loop
    
    #Process Teams with Real Time Activated
      team_list.values.each do |t|
        begin
          #puts t.inspect
          IronWorker.config.no_upload = true
          worker = FootballRealtimeWorker.new
          worker.team_list = t
          resp = worker.queue
          #team = FootballTeam.find_by_id(t)
          #if (team.team_type == YAHOO_AUTH_TYPE)
          #  set_yahoo_inactive(team)
          #end
          #if (team.team_type == ESPN_AUTH_TYPE)
          #  set_espn_inactive(team)
          #end
        rescue => msg
          puts "ERROR OCCURED (#{msg})"
          log_error('sys', nil, 'footballironworker',msg)
          @success = false
        end 
      end
    #Body End
  end
end

namespace :football do
  desc "Fetch players."
  task :parse_all_players => :environment do
    parse_football_player_list(YAHOO_OFFENSE_SEASON_FOOTBALL_URL, 'OFF')
    parse_football_player_list(YAHOO_DEFENSE_SEASON_FOOTBALL_URL, 'DEF')
    parse_football_player_list(YAHOO_KICKER_SEASON_FOOTBALL_URL,'KICK')
    parse_football_player_list(YAHOO_DEF_PLAYER_SEASON_FOOTBALL_URL,'IDP')
       
  end
end