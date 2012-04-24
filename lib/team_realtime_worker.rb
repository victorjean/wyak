require 'iron_worker'


class TeamRealtimeWorker < IronWorker::Base
  unmerge_gem 'nokogiri'
  merge_gem 'mongo_mapper'
  merge_gem 'hpricot'
  merge_gem 'mechanize'
  
  merge "fantasy_team_helper.rb"
  merge "real_time_helper.rb"
  merge "../models/team.rb"
  merge "../models/log.rb"
  merge "../models/auth_info.rb"
  merge "../models/player_realtime.rb"
  merge "../models/player_stats.rb"
  merge "../models/player.rb"
  merge "../models/roster.rb"
  merge "../models/user_info.rb"
  
  attr_accessor :team_list

  def run
    #espn_team_list = Team.where(:auth_info_id=>"4f6509368a92f11c94000001").all
    
    team_list.each do |t|
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