require "football_team_helper"



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
  task :parse_all_offense => :environment do
    parse_football_player_list(YAHOO_OFFENSE_SEASON_FOOTBALL_URL, 'OFF')
    parse_football_player_list(YAHOO_DEFENSE_SEASON_FOOTBALL_URL, 'DEF')
    parse_football_player_list(YAHOO_KICKER_SEASON_FOOTBALL_URL,'KICK')    
  end
end