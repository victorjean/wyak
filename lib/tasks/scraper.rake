require "fantasy_team_helper"

namespace :scraper do
  desc "Fetch yahoo team"
  task :yahoo => :environment do
    team_parse = Team.find_by_league_id("77729")
    parse_yahoo_team(team_parse, false)
    
  end
end

namespace :scraper do
  desc "Fetch espn team"
  task :espn => :environment do
    team_parse = Team.find_by_league_id("32280")
    parse_espn_team(team_parse, false)
    
  end
end

namespace :scraper do
  desc "Start Yahoo Team"
  task :yahoostart => :environment do
    team_parse = Team.find_by_league_id("77729")
    agent = authenticate_yahoo(team_parse.auth_info)
    set_yahoo_default(team_parse, agent)
    
  end
end

namespace :scraper do
  desc "Start ESPN Team"
  task :espnstart => :environment do
    team_parse = Team.find_by_league_id("32280")
    agent = authenticate_espn(team_parse.auth_info)
    set_espn_default(team_parse, agent)
    
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

namespace :scraper do
  desc "Yahoo Test"
  task :yahootest => :environment do
    auth_user = AuthInfo.find_by_email_and_auth_type("victor.jean@gmail.com",YAHOO_AUTH_TYPE)
    
    #open_yahoo(auth_user) 
    post_yahoo(auth_user) 
  end
end

namespace :scraper do
  desc "ESPN Test"
  task :espntest => :environment do
    auth_user = AuthInfo.find_by_email_and_auth_type("victor.jean@gmail.com",ESPN_AUTH_TYPE)
    puts auth_user.login
    puts auth_user.pass
    post_espn(auth_user) 
  end
end

namespace :scraper do
  desc "Create User"
  task :createuser => :environment do
    user = UserInfo.new
    user.email = 'victor.jean@gmail.com'
    user.pass = 'test'
    #user.save   
    
    auth = AuthInfo.new
    auth.email = 'victor.jean@gmail.com'
    auth.login = 'vhjean'
    auth.pass = 'biatch1'
    auth.auth_type = ESPN_AUTH_TYPE
    auth.save
  end
end


