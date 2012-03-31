require "fantasy_team_helper"

class TeamsController < ApplicationController
    
  before_filter :login_required, :only=>['index', 'show']
  
  def index
    @email = session[:user]
    user_info = UserInfo.find_by_email(session[:user])
    @espn_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE)
    @yahoo_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE)
  end

  def show
    #@roster_list = team_type, league_id, team_id
  end

  def edit

  end

  def update
    
  end

  
end
