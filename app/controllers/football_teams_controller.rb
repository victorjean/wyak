require "fantasy_team_helper"
require "football_team_helper"

class FootballTeamsController < ApplicationController
    
  before_filter :login_required, :only=>['index', 'show', 'create', 'set_priority', 'showpriority']
  
  def index
    refresh_time = 12*60*60
    #refresh_time = 1
      
    user_info = UserInfo.find_by_email(session[:user])
    @espn_teams = FootballTeam.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE)
    @yahoo_teams = FootballTeam.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE)
    @update = false
    @demo = true
    @demo_team = nil
    #get current time, if team's have not been updated in four hours, refresh
    last_update = nil
    now = Time.now
    
    @demo = false
    if (@espn_teams.length != 0)
      last_update = @espn_teams.first.updated_at
      @demo = false
    end
    if (@yahoo_teams.length != 0)
      last_update = @yahoo_teams.first.updated_at
      @demo = false
    end
    
    if (@demo)
      @demo_team = FootballTeam.find_by_league_id_and_team_id("388110","10")
    end
    
    if (!last_update.nil?) 
      diff = now - last_update
      if (diff > refresh_time)
        
        @update = true
        
      end
    end
  end
  


  def showpriority
    user_info = UserInfo.find_by_email(session[:user])
    @espn_teams = FootballTeam.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE)
    @yahoo_teams = FootballTeam.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE)
    
    bench_count = 0
    @team = FootballTeam.find(params[:id])
    
    @player_list = FootballPlayer.where(:team_type=>@team.team_type, :team_id=>@team.team_id, :league_id=>@team.league_id).all
    
    @player_list = @player_list.sort_by{|x| [x.priority]} 
    
    render :action => 'show'
  end
  
  
  def set_priority
    priority_settings = params[:playertable]        
    count=0
    
    if (!priority_settings.nil?)      
      priority_settings.each do |pid|       
        if (pid!="")
          count +=1
          player = FootballPlayer.find(pid)
          player.priority = count
          player.save
          #puts player.full_name+'-'+count.to_s
        end
      end
    end
    
    render(:partial => 'loading')
  end

  
  
  def refresh_lineup
    @success = true
    begin
      team_parse = FootballTeam.find(params[:id])
      if (team_parse.team_type == YAHOO_AUTH_TYPE)
        parse_yahoo_football_team(team_parse, false)
      end
      if (team_parse.team_type == ESPN_AUTH_TYPE)
        parse_espn_football_team(team_parse, false)
      end
    rescue => msg
      @success = false
      logger.error("ERROR OCCURED while refresh_lineup Football Team #{team_parse.league_id} - #{session[:user]} - (#{msg})")
      log_error(session[:user], team_parse, 'football_teams/refresh_lineup', msg)  
    end
    render(:partial => 'loading')
  end
  

  
  def update_all
    logger.info("Football Update All Function For #{session[:user]}")
    user_info = UserInfo.find_by_email(session[:user])
    @success = true
    
    yahoo_update= false
    espn_update = false
    
    mode = params[:mode]
    if (mode == 'all')
      yahoo_update = true
      espn_update = true
      begin
        load_espn_football_teams(user_info,false)
        load_yahoo_football_teams(user_info,false)
      rescue => msg
        @success = false
        logger.error("ERROR OCCURED while Updating Football Teams Info #{user_info.email} - (#{msg})")
        log_error(session[:user], nil, 'update_all_team_list',"Error Updating Football Team List - #{msg}")
      end
    end
    if(mode == 'yahoo')
      yahoo_update = true
      begin
      load_yahoo_football_teams(user_info,false)
      rescue => msg
        @success = false
        logger.error("ERROR OCCURED while Updating Yahoo Football Teams Info #{user_info.email} - (#{msg})")
        log_error(session[:user], nil, 'update_yahoo_team_list',"Error Updating Yahoo Football Team List - #{msg}")
      end
    end
    if(mode == 'espn')
      espn_update = true
      begin
      load_espn_football_teams(user_info,false)
      rescue => msg
        @success = false
        logger.error("ERROR OCCURED while Updating ESPN Football Teams Info #{user_info.email} - (#{msg})")
        log_error(session[:user], nil, 'update_espn_team_list',"Error Updating ESPN Football Team List - #{msg}")
      end
    end
    
    espn_teams = FootballTeam.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE)
    yahoo_teams = FootballTeam.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE)
    
    
    if (yahoo_update)
    yahoo_teams.each do |team|
      begin        
        parse_yahoo_football_team(team, false)
      rescue => msg
        @success = false
        logger.error("ERROR OCCURED while Updating Football Yahoo Teams #{team.league_id} - #{user_info.email} - (#{msg})")
        log_error(session[:user], team, 'teams/update_all',"Updating Football Yahoo Teams - #{msg}")
      end  
    end
    end
    
    if (espn_update)
    espn_teams.each do |team|
      begin
        parse_espn_football_team(team, false)
        
      rescue => msg
        @success = false
        logger.error("ERROR OCCURED while Updating ESPN Football Teams #{team.league_id} - #{user_info.email} - (#{msg})")
        log_error(session[:user], team, 'teams/update_all',"Updating ESPN Football Teams - #{msg}")
      end
    end
    end
    
    render(:partial => 'updated')
  end
  
  def setup
    @team = FootballTeam.find(params[:teamid])
    @player_type = params[:playertype]

    if (@player_type == 'b' )
      @team.active = (params[:setvalue] == 'true')
      @team.save     
    end
    if (@player_type == 'p' )
      @team.start_type = params[:setvalue]
      @team.save
    end
    
    render(:partial => 'set')
  end
  
  def show_stat
    if (params[:yahooid]!='')
    @player = PlayerStats.find_by_yahoo_id(params[:yahooid])
    end
    if (params[:espnid]!='')
    @player = PlayerStats.find_by_espn_id(params[:espnid])
    end
    
    @pitch = (params[:pitch]=='true')
    
    render(:partial => 'playerstat')
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
      locale = Timeout::timeout(5) { Net::HTTP.get_response(URI.parse('http://api.hostip.info/country.php?ip=' + request.remote_ip )).body } rescue "US"
      #Reload Teams for Request
      if (params[:manageAction] == 'R')
        begin
          if (@teamType == 'ESPN')
          load_espn_football_first_time(user_info)
          end
          if (@teamType == 'YAHOO')
          load_yahoo_football_first_time(user_info)
          end
        rescue => msg
          @success = false
          logger.error("ERROR OCCURED while Updating #{@teamType} Teams #{user_info.email} - (#{msg})")
          log_error(session[:user], nil, 'teams/manage',"Reloading Teams - #{msg}")
        end
      #Create New ESPN/YAHOO authentication and load teams
      elsif(params[:manageAction] == 'U' && @authInfo.nil?)
        begin
          auth_info = AuthInfo.new
          auth_info.email = user_info.email
          auth_info.login = params[:userid]
          auth_info.password = params[:pass]
          auth_info.region = locale
          if (@teamType == 'ESPN')
            auth_info.auth_type = ESPN_AUTH_TYPE 
            auth_info.save!
            authenticate_espn(auth_info)
          end
          if (@teamType == 'YAHOO')
            auth_info.auth_type = YAHOO_AUTH_TYPE
            auth_info.save!
            authenticate_yahoo(auth_info)
          end
          
        rescue => msg
          auth_info.destroy
          @success = false
          logger.error("ERROR OCCURED while Creating New #{@teamType} Teams #{user_info.email} - (#{msg})")
          log_error(session[:user], nil, 'teams/manage',"Could not Authenticate or Save Auth Info - #{msg}")
        end
        
        begin  
          if (@teamType == 'ESPN' && @success)
            
            load_espn_football_first_time(user_info)
          end
          if (@teamType == 'YAHOO' && @success)
            
            load_yahoo_football_first_time(user_info)
          end
        rescue => msg
        
          @success = false
          logger.error("ERROR OCCURED while Creating New #{@teamType} Teams #{user_info.email} - (#{msg})")
          log_error(session[:user], nil, 'teams/manage',"Creating New Auth Info and Teams - #{msg}")
        end
      elsif(params[:manageAction] == 'U' && !@authInfo.nil?)
        begin
          if (@teamType == 'ESPN')
            if(@authInfo.login != params[:userid])
              @authInfo.login = params[:userid]
              @authInfo.password = params[:pass]
              @authInfo.region = locale
              @authInfo.save!
              load_espn_football_first_time(user_info)
            else
              @authInfo.region = locale
              @authInfo.password = params[:pass]
              @authInfo.save!
              authenticate_espn(@authInfo)
            end
          end
          if (@teamType == 'YAHOO')
            if(@authInfo.login != params[:userid])
              @authInfo.login = params[:userid]
              @authInfo.password = params[:pass]
              @authInfo.region = locale
              @authInfo.save!
              load_yahoo_football_first_time(user_info)
            else
              @authInfo.region = locale
              @authInfo.password = params[:pass]
              @authInfo.save!
              authenticate_yahoo(@authInfo)
            end
          end
        rescue => msg
          @success = false
          logger.error("ERROR OCCURED while Creating New #{@teamType} Teams #{user_info.email} - (#{msg})")
          log_error(session[:user], nil, 'teams/manage',"Changing Auth Info User/Password and Teams - #{msg}")
        end
      end
      render(:partial => 'loading')
    else
    render(:partial => 'manage')    
    end
     
    
  end

  
end
