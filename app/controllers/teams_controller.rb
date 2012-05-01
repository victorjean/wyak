require "fantasy_team_helper"

class TeamsController < ApplicationController
    
  before_filter :login_required, :only=>['index', 'show', 'create', 'set_lineup', 'showbatters', 'showpitchers' ]
  
  def index
    refresh_time = 2*60*60
    #refresh_time = 1
      
    user_info = UserInfo.find_by_email(session[:user])
    @espn_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE)
    @yahoo_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE)
    @update = false
    @demo = true
    @demo_team = nil
    #get current time, if team's have not been updated in four hours, refresh
    last_update = nil
    now = Time.now
    
    if (@espn_teams.length != 0)
      last_update = @espn_teams.first.updated_at
      @demo = false
    end
    if (@yahoo_teams.length != 0)
      last_update = @yahoo_teams.first.updated_at
      @demo = false
    end
    
    if (@demo)
      @demo_team = Team.find_by_league_id_and_team_id("202052","12")
    end
    
    if (!last_update.nil?) 
      diff = now - last_update
      if (diff > refresh_time)
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

  def showbatters
    user_info = UserInfo.find_by_email(session[:user])
    @espn_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE)
    @yahoo_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE)
    
    bench_count = 0
    @team = Team.find(params[:id])
    @roster_list = Roster.where(:pos_text.ne=>DL_POSITION, :pos_type=>BENCH_BATTER_TYPE,:team_type=>@team.team_type, :team_id=>@team.team_id, :league_id=>@team.league_id).all
    @dl_list = Player.where(:team_type=>@team.team_type, :team_id=>@team.team_id, :league_id=>@team.league_id,
    :$or => [{:current_slot => DL_POSITION},{:current_slot => ESPN_DL_SLOT}]).all
    @bench_array = []
    @bench_player_array = []
    roster_bench_list = Roster.where(:pos_text=>BENCH_POSITION,:pos_type=>BENCH_BATTER_TYPE, :team_type=>@team.team_type, :team_id=>@team.team_id, :league_id=>@team.league_id).all
    roster_bench_list.each do |roster|
      if (!roster.player.nil? && (roster.player.current_slot != DL_POSITION && roster.player.current_slot != ESPN_DL_SLOT) )
        if (roster.player.action != NEVER_START_OPTION)
        bench_count += 1
        @bench_array.push(bench_count)
        end
        
        @bench_player_array.push(roster)
      end 
    end
    @bench_player_array = @bench_player_array.sort_by{|x| [x.player.priority]} 
    @pitch = false
    render :action => 'show'
  end

  def showpitchers
    user_info = UserInfo.find_by_email(session[:user])
    @espn_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE)
    @yahoo_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE)
    
    bench_count = 0
    @team = Team.find(params[:id])
    @roster_list = Roster.where(:pos_text.ne=>DL_POSITION, :pos_type=>BENCH_PITCHER_TYPE,:team_type=>@team.team_type, :team_id=>@team.team_id, :league_id=>@team.league_id).all
    @dl_list = Player.where(:team_type=>@team.team_type, :team_id=>@team.team_id, :league_id=>@team.league_id,
    :$or => [{:current_slot => DL_POSITION},{:current_slot => ESPN_DL_SLOT}]).all
    @bench_array = []
    @bench_player_array = []
    roster_bench_list = Roster.where(:pos_text=>BENCH_POSITION,:pos_type=>BENCH_PITCHER_TYPE, :team_type=>@team.team_type, :team_id=>@team.team_id, :league_id=>@team.league_id).all
    roster_bench_list.each do |roster|
      if (!roster.player.nil? && (roster.player.current_slot != DL_POSITION && roster.player.current_slot != ESPN_DL_SLOT) )
        bench_count += 1
        @bench_array.push(bench_count)
        @bench_player_array.push(roster)
      end 
    end
    @bench_player_array = @bench_player_array.sort_by{|x| [x.player.priority]} 
    @pitch = true
    render :action => 'show'
  end
  
  def set_lineup
    player_hash = {}
    roster_hash = {}
    @success = true
    begin
    @team = Team.find(params[:id])
    @roster_list = Roster.where(:pos_text.ne=>DL_POSITION, :team_type=>@team.team_type, :team_id=>@team.team_id, :league_id=>@team.league_id).all
    @roster_list.each do |roster|
      roster_hash[roster._id.to_s] = roster
      if (!roster.player.nil?)
        player_hash[roster.player._id.to_s] = roster.player
      end
    end
    
    #Update roster leave empty attribute
    roster_settings = params[:empty]
    if (!roster_settings.nil?)
      roster_settings.each do |r|
        oid = r.index.next 
        roster_hash[oid].leave_empty = (params[:empty][oid] == '1')
      end
    end
    #Update Start Option
    start_settings = params[:freqselect]
    if (!start_settings.nil?)
      start_settings.each do |r|
        oid = r.index.next 
        player_hash[oid].action = params[:freqselect][oid]
      end
    end
    #Update Priority Option
    
    priority_settings = params[:priorityselect]
    if (!priority_settings.nil?)
      priority_settings.each do |r|
        oid = r.index.next 
        player_hash[oid].priority = params[:priorityselect][oid].to_i
      end
    end
    #Update Assigned Roster Position
    
    pos_settings = params[:poselect]
    if (!pos_settings.nil?)
      pos_settings.each do |r|
        oid = r.index.next 
        player_hash[oid].assign_pos = params[:poselect][oid]
      end
    end
    #Remove Player from Roster
    @roster_list.each do |roster|
      if (!roster.player.nil?)
        roster.player = nil
      end
    end
    #Assign Players to Roster
    player_hash.values.each do |p|
      assign_player_in_roster(p, @roster_list)
    end
    
    rescue => msg
      @success = false
      logger.error("ERROR OCCURED while Updating Team Lineup #{@team.league_id} - (#{msg})")
      log_error(session[:user], @team, 'teams/set_lineup', msg)
    end
    
    
    #Save All Roster Information
    if (@success)
      @roster_list.each do |roster|
        roster.save!
      end
    end
    
    
    render(:partial => 'loading')    
  end
  
  def refresh_lineup
    @success = true
    begin
      team_parse = Team.find(params[:id])
      if (team_parse.team_type == YAHOO_AUTH_TYPE)
        parse_yahoo_team(team_parse, false, true)
      end
      if (team_parse.team_type == ESPN_AUTH_TYPE)
        parse_espn_team(team_parse, false, true)
      end
    rescue => msg
      @success = false
      logger.error("ERROR OCCURED while refresh_lineup Team #{team_parse.league_id} - #{session[:user]} - (#{msg})")
      log_error(session[:user], team_parse, 'teams/refresh_lineup', msg)  
    end
    render(:partial => 'loading')
  end
  
  def start_lineup
    @success = true
    begin
      team_parse = Team.find(params[:id])
      if (team_parse.team_type == YAHOO_AUTH_TYPE)
        set_yahoo_default(team_parse,true)
      end
      if (team_parse.team_type == ESPN_AUTH_TYPE)
        set_espn_default(team_parse,true)
      end
    rescue => msg
      @success = false
      logger.error("ERROR OCCURED while start_lineup Team #{team_parse.league_id} - #{session[:user]} - (#{msg})")
      log_error(session[:user], team_parse, 'teams/start_lineup', msg)  
    end
    render(:partial => 'loading')
  end
  
  def preview_lineup
    @player_hash = {}
    @player_list = []
    @success = true
    begin
      team_parse = Team.find(params[:id])
      #@player_list = Player.find_all_by_league_id_and_team_id_and_team_type(team_parse.league_id,team_parse.team_id,team_parse.team_type )
      @roster_list = Roster.where(:pos_text.ne=>BENCH_POSITION, :team_type=>team_parse.team_type, :team_id=>team_parse.team_id, :league_id=>team_parse.league_id).all
      if (team_parse.team_type == YAHOO_AUTH_TYPE)
        
        @player_list = preview_yahoo_default(team_parse)
      end
      if (team_parse.team_type == ESPN_AUTH_TYPE)
        
        @player_list = preview_espn_default(team_parse)
      end
      
      
      @player_list.each do |p|
          if (@player_hash[p.assign_pos].nil?)
            @player_hash[p.assign_pos] = []
            @player_hash[p.assign_pos].push(p)
          else
            @player_hash[p.assign_pos].push(p)  
          end
      end
      
    rescue => msg
      @success = false
      logger.error("ERROR OCCURED while preview_lineup Team #{team_parse.league_id} - #{session[:user]} - (#{msg})")
      log_error(session[:user], team_parse, 'teams/preview_lineup', msg)  
    end
    render(:partial => 'preview')
  end
  
  def update_all
    logger.info("Update All Function For #{session[:user]}")
    user_info = UserInfo.find_by_email(session[:user])
    @success = true
    
    yahoo_update= false
    espn_update = false
    
    mode = params[:mode]
    if (mode == 'all')
      yahoo_update = true
      espn_update = true
      begin
        load_espn_teams(user_info,false)
        load_yahoo_teams(user_info,false)
      rescue => msg
        @success = false
        logger.error("ERROR OCCURED while Updating Teams Info #{user_info.email} - (#{msg})")
        log_error(session[:user], nil, 'update_all_team_list',"Error Updating Team List - #{msg}")
      end
    end
    if(mode == 'yahoo')
      yahoo_update = true
      begin
      load_yahoo_teams(user_info,false)
      rescue => msg
        @success = false
        logger.error("ERROR OCCURED while Updating Yahoo Teams Info #{user_info.email} - (#{msg})")
        log_error(session[:user], nil, 'update_yahoo_team_list',"Error Updating Yahoo Team List - #{msg}")
      end
    end
    if(mode == 'espn')
      espn_update = true
      begin
      load_espn_teams(user_info,false)
      rescue => msg
        @success = false
        logger.error("ERROR OCCURED while Updating ESPN Teams Info #{user_info.email} - (#{msg})")
        log_error(session[:user], nil, 'update_espn_team_list',"Error Updating ESPN Team List - #{msg}")
      end
    end
    
    espn_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE)
    yahoo_teams = Team.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE)
    
    
    if (yahoo_update)
    yahoo_teams.each do |team|
      begin
        parse_yahoo_team(team, false, true)
        
      rescue => msg
        @success = false
        logger.error("ERROR OCCURED while Updating Yahoo Teams #{team.league_id} - #{user_info.email} - (#{msg})")
        log_error(session[:user], team, 'teams/update_all',"Updating Yahoo Teams - #{msg}")
      end  
    end
    end
    
    if (espn_update)
    espn_teams.each do |team|
      begin
        parse_espn_team(team, false, true)
        
      rescue => msg
        @success = false
        logger.error("ERROR OCCURED while Updating ESPN Teams #{team.league_id} - #{user_info.email} - (#{msg})")
        log_error(session[:user], team, 'teams/update_all',"Updating ESPN Teams - #{msg}")
      end
    end
    end
    
    render(:partial => 'updated')
  end
  
  def setup
    @team = Team.find(params[:teamid])
    @player_type = params[:playertype]

    if (@player_type == 'b' )
      @team.daily_auto_batter = (params[:setvalue] == 'true')
      @team.save     
    end
    if (@player_type == 'p' )
      @team.daily_auto_pitcher = (params[:setvalue] == 'true')
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
          load_espn_first_time(user_info)
          end
          if (@teamType == 'YAHOO')
          load_yahoo_first_time(user_info)
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
            
            load_espn_first_time(user_info)
          end
          if (@teamType == 'YAHOO' && @success)
            
            load_yahoo_first_time(user_info)
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
              load_espn_first_time(user_info)
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
              load_yahoo_first_time(user_info)
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
