require "fantasy_team_helper"


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
  desc "Fetch yahoo team"
  task :yahoo => :environment do
    team_parse = Team.find_by_league_id_and_team_id("auto","187997")
    parse_yahoo_team(team_parse, true, true)
    
  end
end

namespace :scraper do
  desc "Fetch espn team"
  task :espn => :environment do
    team_parse = Team.find_by_league_id("130711")
    parse_espn_team(team_parse, true, false)
    
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

namespace :scraper do
  desc "Test using app server to run daily process"
  task :testweb => :environment do
    proxy = nil
    
    now = Time.now
    puts now.to_s
    
    #agent = Mechanize.new
    #page = agent.get("http://localhost:3000/process/yahoostart"
    #open("http://localhost:3000/process/yahoostart", :proxy => proxy, 'User-Agent' => USER_AGENT, 'Accept' => ACCEPT, 'Accept-Charset' => ACCEPT_CHARSET)
     EventMachine.run {
      http = EventMachine::HttpRequest.new('http://localhost:3000/process/yahoostart').get
      sleep 1
      EM.stop 
     }
    
    
    finish = Time.now
    puts finish.to_s
    diff = finish - now
    puts diff
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
    team_list = []
    #Read Scoreboard and Update PlayerStat table for scratched player
    
    #Get Scratched Player List
    player_list = PlayerStats.find_all_by_scratched_and_processed(true,false)
    player_list.each do |player_stat|
      #add to team array
      
      player_stat.processed = true
      player_stat.save
    end
    
    #Process Teams with Real Time Activated
    
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