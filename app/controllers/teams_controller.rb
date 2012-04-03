require "fantasy_team_helper"

class TeamsController < ApplicationController
    
  before_filter :login_required, :only=>['index', 'show', 'create']
  
  def index
    four_hours = 4*60*60
    
      
    user_info = UserInfo.find_by_email(session[:user])
    @espn_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE)
    @yahoo_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE)
    @update = false
    #get current time, if team's have not been updated in four hours, refresh
    last_update = nil
    now = Time.now
    
    if (@espn_teams.length != 0)
      last_update = @espn_teams.first.updated_at
    end
    if (@yahoo_teams.length != 0)
      last_update = @yahoo_teams.first.updated_at
    end
    
    if (!last_update.nil?) 
      diff = now - last_update
      if (diff > four_hours)
        @update = true
      end
    end
  end
  
  def create
    team_hash = {}
    user_info = UserInfo.find_by_email(session[:user])
    @espn_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE)
    @yahoo_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE)
    
    
    @espn_teams.each do |team|      
      team_hash[team._id.to_s] = team  
    end
    @yahoo_teams.each do |team|
      team_hash[team._id.to_s] = team  
    end
    
    batter_settings = params[:batter]
    pitcher_settings = params[:pitcher]
    
    batter_settings.each do |bat|
      oid = bat.index.next 
      team_hash[oid].daily_auto_batter = (params[:batter][oid] == '1')
    end
    pitcher_settings.each do |pitch|
      oid = pitch.index.next
      team_hash[oid].daily_auto_pitcher = (params[:pitcher][oid] == '1')
    end
    
    #save changes
    team_hash.values.each do |team|
      #logger.info("#{team.league_name} - #{team.daily_auto_batter}")
      team.save
    end
    
    
    flash[:message] = "Team Settings Updated"
    
    render :action => 'index'
  end

  def show
    #@roster_list = team_type, league_id, team_id get actual team page
  end

  def edit

  end

  def update
    
  end
  
  def update_all
    logger.info("Update All Function For #{session[:user]}")
    
    user_info = UserInfo.find_by_email(session[:user])
    espn_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE)
    yahoo_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE)
    @success = true
    
    yahoo_teams.each do |team|
      begin
        parse_yahoo_team(team, false)
        team.save
      rescue => msg
        @success = false
        logger.error("ERROR OCCURED while Updating Yahoo Teams #{team.league_id} - #{user_info.email} - (#{msg})")
      end  
    end
    
    espn_teams.each do |team|
      begin
        parse_espn_team(team, false)
        team.save
      rescue => msg
        @success = false
        logger.error("ERROR OCCURED while Updating ESPN Teams #{team.league_id} - #{user_info.email} - (#{msg})")
      end
    end
    
    render(:partial => 'updated')
  end
  
  def manage
    @teamType = params[:teamType]
    user_info = UserInfo.find_by_email(session[:user])
    @authInfo = nil
    #Get Authorization ESPN/YAHOO info
    if (@teamType == 'ESPN')
      @authInfo = AuthInfo.find_by_email_and_auth_type(user_info.email, ESPN_AUTH_TYPE)
    end
    if (@teamType == 'YAHOO')
      @authInfo = AuthInfo.find_by_email_and_auth_type(user_info.email, YAHOO_AUTH_TYPE)
    end
    
    @success = true
    if (request.post?)
      #Reload Teams for Request
      if (params[:manageAction] == 'R')
        begin
          if (@teamType == 'ESPN')
          load_espn_first_time(user_info)
          end
          if (@teamType == 'YAHOO')
          load_yahoo_first_time(user_info)
          end
        rescue => msg
          @success = false
          logger.error("ERROR OCCURED while Updating #{@teamType} Teams #{user_info.email} - (#{msg})")
        end
      #Create New ESPN/YAHOO authentication and load teams
      elsif(params[:manageAction] == 'U' && @authInfo.nil?)
        begin
          auth_info = AuthInfo.new
          auth_info.email = user_info.email
          auth_info.login = params[:userid]
          auth_info.password = params[:pass]
          
          if (@teamType == 'ESPN')
            auth_info.auth_type = ESPN_AUTH_TYPE 
            auth_info.save!
            load_espn_first_time(user_info)
          end
          if (@teamType == 'YAHOO')
            auth_info.auth_type = YAHOO_AUTH_TYPE
            auth_info.save!
            load_yahoo_first_time(user_info)
          end
        rescue => msg
          @success = false
          logger.error("ERROR OCCURED while Creating New #{@teamType} Teams #{user_info.email} - (#{msg})")
        end
      elsif(params[:manageAction] == 'U' && !@authInfo.nil?)
        begin
          if (@teamType == 'ESPN')
            if(@authInfo.login != params[:userid])
              @authInfo.login = params[:userid]
              @authInfo.password = params[:pass]
              @authInfo.save!
              load_espn_first_time(user_info)
            else
              @authInfo.password = params[:pass]
              @authInfo.save!
              authenticate_espn(@authInfo)
            end
          end
          if (@teamType == 'YAHOO')
            if(@authInfo.login != params[:userid])
              @authInfo.login = params[:userid]
              @authInfo.password = params[:pass]
              @authInfo.save!
              load_yahoo_first_time(user_info)
            else
              @authInfo.password = params[:pass]
              @authInfo.save!
              authenticate_yahoo(@authInfo)
            end
          end
        rescue => msg
          @success = false
          logger.error("ERROR OCCURED while Creating New #{@teamType} Teams #{user_info.email} - (#{msg})")
        end
      end
      render(:partial => 'loading')
    else
    render(:partial => 'manage')    
    end
     
    
  end

  
end
