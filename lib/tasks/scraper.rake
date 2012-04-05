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
         set_espn_default(team)
         
      end
      if (team.team_type == YAHOO_AUTH_TYPE)
         puts 'YAHOO YAHOO DEFAULT '+team.league_name + '-' + team.league_id
         set_yahoo_default(team)
      end
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
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
         set_yahoo_default(team)
      
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
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
         set_espn_default(team)
      
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
      end  
    end
    
  end
end


namespace :scraper do
  desc "Fetch yahoo team"
  task :yahoo => :environment do
    team_parse = Team.find_by_league_id_and_team_id("116135","6")
    parse_yahoo_team(team_parse, true)
    
  end
end

namespace :scraper do
  desc "Fetch espn team"
  task :espn => :environment do
    team_parse = Team.find_by_league_id("130711")
    parse_espn_team(team_parse, true)
    
  end
end

namespace :scraper do
  desc "Start Yahoo Team"
  task :yahoostart => :environment do
    team_parse = Team.find_by_league_id_and_team_id("116135","6")
   
    set_yahoo_default(team_parse)
    
  end
end

namespace :scraper do
  desc "Start ESPN Team"
  task :espnstart => :environment do
    team_parse = Team.find_by_league_id("130711")
    
    set_espn_default(team_parse)
    
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
  desc "Fetch espn team from scratch"
  task :auth => :environment do
    team_parse = Team.find_by_league_id("32280") #ESPN
    authenticate_espn(team_parse.auth_info)
    #team_parse = Team.find_by_league_id("116135") #YAHOO
    #authenticate_yahoo(team_parse.auth_info)
  end
end

namespace :scraper do
  desc "Database Test"
  task :dbtest => :environment do
    
   
    puts Roster.all(:pos_text.ne=>BENCH_POSITION).length
    puts Roster.all(:pos_text=>BENCH_POSITION).length
    
    roster_list = Roster.all(:league_id=>'130711')
    roster_list.each do |item|
      if (item.player.nil?)
        puts item.pos_text + " - NONE"
      else
        puts item.pos_text + " - "+ item.player.full_name
      end
    end  
  end
end

