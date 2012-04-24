require 'iron_worker'


class TeamRealtimeWorker < IronWorker::Base
  unmerge_gem 'nokogiri'
  merge_gem 'mongo_mapper'
  merge_gem 'hpricot'
  merge_gem 'mechanize'
  
  merge "fantasy_team_helper.rb"
  merge "real_time_helper.rb"
  merge "../app/models/team.rb"
  merge "../app/models/log.rb"
  merge "../app/models/auth_info.rb"
  merge "../app/models/player_realtime.rb"
  merge "../app/models/player_stats.rb"
  merge "../app/models/player.rb"
  merge "../app/models/roster.rb"
  merge "../app/models/user_info.rb"
  
  attr_accessor :team_list

  def run
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