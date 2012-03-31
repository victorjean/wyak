require "fantasy_team_helper"

class TeamsController < ApplicationController
    
  before_filter :login_required, :only=>['index', 'show', 'create']
  
  def index
   
    user_info = UserInfo.find_by_email(session[:user])
    @espn_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE)
    @yahoo_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE)
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

  
end
