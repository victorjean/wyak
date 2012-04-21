require "fantasy_team_helper"
require "real_time_helper"


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
    parse_days_scoreboard('')
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
    team_parse = Team.find_by_league_id_and_team_id("21947","1")
    parse_yahoo_team_realtime(team_parse,false)
  end
end

namespace :scraper do
  desc "Fetch esyahoopn team for real time table"
  task :yahooscratch => :environment do
    team_parse = Team.find_by_league_id_and_team_id("116135","6")
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
    user_info = UserInfo.find_by_email("victor.jean@gmail.com")
    
    load_yahoo_first_time(user_info)
    
  end
end

namespace :scraper do
  desc "Fetch espn team from scratch"
  task :espnfull => :environment do
    user_info = UserInfo.find_by_email("victor.jean@gmail.com")
    
    load_espn_first_time(user_info)
    
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
    
    if (t.hour < 20 || t.hour >= 7)
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
            if(p.assign_pos.index('P').nil? && p.assign_pos!=DL_POSITION && p.assign_pos!=ESPN_DL_SLOT)
              team_list[p.team._id]=p.team
              log_error('sys', team, 'scratch',p.full_name)
            end
          end
        end
        player_stat.processed = false
        player_stat.save
      end
      
      #Process Teams with Real Time Activated
      team_list.values.each do |t|
        begin
          if (t.team_type == YAHOO_AUTH_TYPE)
            set_yahoo_scratch(t)
          end
          if (t.team_type == ESPN_AUTH_TYPE)
            set_espn_scratch(t)
          end
        rescue => msg
          puts "ERROR OCCURED (#{msg})"
          log_error('sys', team, 'realtimeprocess',msg)
          @success = false
        end 
      end
    else
      puts 'skipping - ' + t.hour
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