require "fantasy_team_helper"

class ProcessController < ApplicationController
  def players
    @success = true
    begin   
      puts 'Get Pitcher Information'
      parse_player_list(ALL_PITCHERS_URL, "SP")      
    rescue => msg
      puts "ERROR OCCURED (#{msg})"
      log_error('sys', nil, 'parseplayer_pitcher',msg)
      @success = false
    end
    
    begin   
      puts 'Get Batter Information'
      parse_player_list(ALL_BATTER_URL, "BAT")      
    rescue => msg
      puts "ERROR OCCURED (#{msg})"
      log_error('sys', nil, 'parseplayer_batter',msg)
      @success = false
    end
    
    rank_players_by_position()
    
    render(:partial => 'loading')
    
  end
  
  def yahoostart
    @success = true
    #Get Team List that is not empty and where batter or pitcher daily is true
    team_list = Team.where(:team_type=>YAHOO_AUTH_TYPE, 
    :empty_team=>false,
    :$or => [{:daily_auto_batter => true},{:daily_auto_pitcher => true}]).sort(:auth_info_id.desc)
    
    team_list.each do |team|
      begin  
      
         puts 'YAHOO YAHOO DEFAULT '+team.league_name + '-' + team.league_id
         set_yahoo_default(team,false)
      
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
        log_error('sys', team, 'dailystartyahoo',msg)
        @success = false
      end  
    end
    
    render(:partial => 'loading')
  end
  
  def espnstart
    @success = true
    #Get Team List that is not empty and where batter or pitcher daily is true
    team_list = Team.where(:team_type=>ESPN_AUTH_TYPE, :empty_team=>false,
    :$or => [
    {:daily_auto_batter => true},
    {:daily_auto_pitcher => true}]).sort(:auth_info_id.desc)
    
    team_list.each do |team|
      begin  
      
         puts 'ESPN ESPN DEFAULT '+team.league_name + '-' + team.league_id
         set_espn_default(team, false)
      
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
        log_error('sys', team, 'dailystartespn',msg)
        @success = false
      end  
    end
    
    render(:partial => 'loading')
  end

end
