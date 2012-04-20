require "fantasy_team_helper"
require "real_time_helper"

class ProcessController < ApplicationController
  def players
    Game.delete_all()
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
  
  def players_seven
    @success = true
    begin   
      puts 'Get Pitcher Information Seven Day'
      parse_player_list(ALL_PITCHERS7_URL, "seven")      
    rescue => msg
      puts "ERROR OCCURED (#{msg})"
      log_error('sys', nil, 'parseplayer_pitcher_seven',msg)
      @success = false
    end
    
    begin   
      puts 'Get Batter Information Seven Day'
      parse_player_list(ALL_BATTER7_URL, "seven")      
    rescue => msg
      puts "ERROR OCCURED (#{msg})"
      log_error('sys', nil, 'parseplayer_batter_seven',msg)
      @success = false
    end
    
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
  
  def espnrealtime
    @success = true
    #Get Team List that is not empty and where batter or pitcher daily is true
    team_list = Team.where(:team_type=>ESPN_AUTH_TYPE, :empty_team=>false,
    :$or => [
    {:real_time_batter => true},
    {:real_time_pitcher => true}]).sort(:auth_info_id.desc)
    
    team_list.each do |team|
      begin  
        parse_espn_team_realtime(team,true)
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
        log_error('sys', team, 'espnrealtime',msg)
        @success = false
      end  
    end
    
    render(:partial => 'loading')
  end
  
  def yahoorealtime
    @success = true
    #Get Team List that is not empty and where batter or pitcher daily is true
    team_list = Team.where(:team_type=>YAHOO_AUTH_TYPE, :empty_team=>false,
    :$or => [
    {:real_time_batter => true},
    {:real_time_pitcher => true}]).sort(:auth_info_id.desc)
    
    team_list.each do |team|
      begin  
        parse_yahoo_team_realtime(team,true)
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
        log_error('sys', team, 'yahoorealtime',msg)
        @success = false
      end  
    end
    
    render(:partial => 'loading')
  end
  
  def logs
    @log_list = Log.all
    render(:partial => 'logs')
  end
  
  def users
    @user_list = UserInfo.sort(:updated_at.desc)
    render(:partial => 'users')
  end


end
