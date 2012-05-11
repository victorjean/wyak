require "fantasy_team_helper"
require "real_time_helper"
require "iron_worker"
require 'team_realtime_worker'
require 'team_daily_worker'

#This is the cron/scheduler task used to set daily lineups
namespace :scraper do
  desc "Start All Teams Daily to Default Player Lineup With Games"
  task :dailystart => :environment do
    #Get Team List that is not empty and where batter or pitcher daily is true
    team_list = Team.where( :empty_team=>false, :$or => [
    {:daily_auto_batter => true},
    {:daily_auto_pitcher => true}]).sort(:auth_info_id.desc)
    
    team_list.each do |team|
      begin  
      if (team.team_type == ESPN_AUTH_TYPE)
         puts 'ESPN ESPN DEFAULT '+team.league_name + '-' + team.league_id
         set_espn_default(team, false)
         
      end
      if (team.team_type == YAHOO_AUTH_TYPE)
         puts 'YAHOO YAHOO DEFAULT '+team.league_name + '-' + team.league_id
         set_yahoo_default(team,false)
      end
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
        log_error('sys', nil, 'dailystart',msg)
      end  
    end
    
  end
end

#This is the cron/scheduler task used to set daily lineups for yahoo teams
namespace :scraper do
  desc "Start All Teams Daily to Default Player Lineup With Games"
  task :dailystartyahoo => :environment do
    #Get Team List that is not empty and where batter or pitcher daily is true
    team_list = Team.where(:team_type=>YAHOO_AUTH_TYPE, :empty_team=>false, :$or => [
    {:daily_auto_batter => true},
    {:daily_auto_pitcher => true}]).sort(:auth_info_id.desc)
    
    team_list.each do |team|
      begin  
      
         puts 'YAHOO YAHOO DEFAULT '+team.league_name + '-' + team.league_id
         set_yahoo_default(team,false)
      
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
        log_error('sys', team, 'dailystartyahoo',msg)
      end  
    end
    
  end
end

#This is the cron/scheduler task used to set daily lineups for ESPN
namespace :scraper do
  desc "Start All Teams Daily to Default Player Lineup With Games"
  task :dailystartespn => :environment do
    #Get Team List that is not empty and where batter or pitcher daily is true
    team_list = Team.where(:team_type=>ESPN_AUTH_TYPE, :empty_team=>false, :$or => [
    {:daily_auto_batter => true},
    {:daily_auto_pitcher => true}]).sort(:auth_info_id.desc)
    
    team_list.each do |team|
      begin  
      
         puts 'ESPN ESPN DEFAULT '+team.league_name + '-' + team.league_id
         set_espn_default(team, false)
      
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
        log_error('sys', team, 'dailystartespn',msg)
      end  
    end
    
  end
end

namespace :scraper do
  desc "Check Scoreboard for Real Time Scratches"
  task :scoreboard => :environment do
    parse_days_scoreboard('2012-04-10')
  end
end

namespace :scraper do
  desc "Check Scoreboard for Real Time Scratches"
  task :gameparse => :environment do
    parse_box('320427101')
  end
end

namespace :scraper do
  desc "Fetch yahoo team"
  task :yahoo => :environment do
    team_parse = Team.find_by_league_id_and_team_id("207097","2")
    parse_yahoo_team(team_parse, false, true)
    
  end
end

namespace :scraper do
  desc "Fetch yahoo team for real time table"
  task :yahoorealtime => :environment do
    team_parse = Team.find_by_league_id_and_team_id("21947","7")
    parse_yahoo_team_realtime(team_parse,false)
  end
end

namespace :scraper do
  desc "Fetch esyahoopn team for real time table"
  task :yahooscratch => :environment do
    team_parse = Team.find_by_league_id_and_team_id("21947","4")
    set_yahoo_scratch(team_parse)
  end
end

namespace :scraper do
  desc "Fetch espn team"
  task :espn => :environment do
    team_parse = Team.find_by_league_id("130711")
    parse_espn_team(team_parse, false, false)
    
  end
end

namespace :scraper do
  desc "Fetch espn team for real time table"
  task :espnrealtime => :environment do
    team_parse = Team.find_by_league_id_and_team_id("32280","7")
    parse_espn_team_realtime(team_parse,false)
  end
end

namespace :scraper do
  desc "Fetch espn team for real time table"
  task :espnscratch => :environment do
    team_parse = Team.find_by_league_id_and_team_id("32280","7")
    set_espn_scratch(team_parse)
  end
end

namespace :scraper do
  desc "Start Yahoo Team"
  task :yahoostart => :environment do
    team_parse = Team.find_by_league_id_and_team_id("116135","6")
   
    set_yahoo_default(team_parse,true)
    
  end
end

namespace :scraper do
  desc "Start ESPN Team"
  task :espnstart => :environment do
    team_parse = Team.find_by_league_id("130711")
    
    set_espn_default(team_parse, true)
    
  end
end

namespace :scraper do
  desc "Fetch yahoo team from scratch"
  task :yahoofull => :environment do
    user_info = UserInfo.find_by_email("none")
    
    load_yahoo_first_time(user_info)
    
  end
end

namespace :scraper do
  desc "Mark Starting Pitcher - One Time Process"
  task :mark_sp => :environment do
    
    p_list = PlayerStats.where( :position=>/SP,RP/).sort(:rank.asc)
    
    p_list.each do |player|
      if (!player.ip.nil? && player.ip > 12 && !player.position.index('SP').nil?)
        player.is_sp = true
      end
      player.save
    end
    
  end
end


namespace :scraper do
  desc "Fetch espn team from scratch"
  task :espnfull => :environment do
    user_info = UserInfo.find_by_email("none")
    
    load_espn_first_time(user_info)
    
  end
end

namespace :scraper do
  desc "Iron Uploader"
  task :ironworker => :environment do
    
    start = Time.now
    puts start
    
    worker = TeamRealtimeWorker.new
    worker.team_list = []
    worker.upload
      
    finish = Time.now
    puts finish
    puts finish-start 
  end
end

namespace :scraper do
  desc "Iron Uploader for Daily Process"
  task :dailyworker => :environment do
    
    start = Time.now
    puts start
    
    worker = TeamDailyWorker.new
    worker.team_list = []
    worker.upload
      
    finish = Time.now
    puts finish
    puts finish-start 
  end
end



#This is the cron/scheduler task used to set daily lineups
namespace :scraper do
  desc "Refresh All Teams"
  task :refreshall => :environment do
    #Get Team List that is not empty and where batter or pitcher daily is true
    team_list = Team.where( :$or => [
    {:team_type => 'Y'},
    {:team_type => 'E'}]).sort(:auth_info_id.desc)
    
    team_list.each do |team|
      begin  
      if (team.team_type == ESPN_AUTH_TYPE)
         parse_espn_team(team, false, true)
      end
      if (team.team_type == YAHOO_AUTH_TYPE)
         parse_yahoo_team(team,false, true)
      end
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
        log_error('sys', nil, 'refreshall',msg)
      end  
    end
    
  end
end

namespace :scraper do
  desc "Process to Bench and Replace Scratched Players"
  task :scratch => :environment do
    t = Time.now
    puts "Current Time Hour - #{t.hour}"
    if (t.hour < 20 && t.hour >= 7)
    puts 'Running Realtime Scratch Process'
    
    
    
      team_list = {}
      
      #Read Scoreboard and Update PlayerStat table for scratched player
      parse_days_scoreboard('')
      
      #Get Scratched Player List
      player_list = PlayerStats.find_all_by_processed(true)
      player_list.each do |player_stat|
        #add to team array if scratched
        if (player_stat.scratched)
          player_stat.player_realtimes.each do |p|
            puts "#{p.full_name} - |#{p.assign_pos}|"
            p.scratched = true
            p.save
            if(!p.team.nil? && p.position_text.index('P').nil? && !p.on_na && !p.on_dl && p.assign_pos!=DL_POSITION && p.assign_pos!=ESPN_DL_SLOT)
              if (team_list[p.team.auth_info_id].nil?)
                team_list[p.team.auth_info_id] = []
              end 
              if (team_list[p.team.auth_info_id].index(p.team._id).nil?)
                team_list[p.team.auth_info_id].push(p.team._id)
              end
              #log_info('sys', p.team, 'scratch',p.full_name)
            end
          end
        end
        player_stat.processed = false
        player_stat.save
      end
      
      #Process Teams with Real Time Activated
      team_list.values.each do |t|
        begin
          #puts t.inspect
          IronWorker.config.no_upload = true
          worker = TeamRealtimeWorker.new
          worker.team_list = t
          resp = worker.queue
        rescue => msg
          puts "ERROR OCCURED (#{msg})"
          log_error('sys', nil, 'ironworker',msg)
          @success = false
        end 
      end
    else
      puts "Skipping < 20 && >=7 - #{t.hour}"
    end # Time Block if Close
  end
end

namespace :scraper do
  desc "Fetch players."
  task :players => :environment do
    
    
    
    begin   
      puts 'Get Pitcher Information'
      parse_player_list(ALL_PITCHERS_URL, "SP")      
    rescue => msg
      puts "ERROR OCCURED (#{msg})"
      log_error('sys', nil, 'parseplayer_pitcher',msg)
    end
    
    begin   
      puts 'Get Batter Information'
      parse_player_list(ALL_BATTER_URL, "BAT")      
    rescue => msg
      puts "ERROR OCCURED (#{msg})"
      log_error('sys', nil, 'parseplayer_batter',msg)
    end
    
    rank_players_by_position()
    
  end
end