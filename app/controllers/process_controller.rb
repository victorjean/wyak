require "fantasy_team_helper"
require "real_time_helper"
require "iron_worker"
require 'team_daily_worker'
require 'football_team_helper'
require 'football_daily_worker'
require 'football_realtime_worker'


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
  
  def yahoostartworker
    
    @success = true
    #Get Team List that is not empty and where batter or pitcher daily is true
    team_list = Team.where(:team_type=>YAHOO_AUTH_TYPE, 
    :empty_team=>false,
    :$or => [{:daily_auto_batter => true},{:daily_auto_pitcher => true}]).sort(:auth_info_id.desc)
    
    send_team_list = []
    current_auth_id = ''
    counter = 0
         
    team_list.each do |team|
      begin           
         
         if (counter%75 == 0 && counter!=0)
           #puts "#{counter}  Mod - #{counter%5}"
           sleep 5
         end
    
         if (current_auth_id != team.auth_info_id)
            if (send_team_list.length!=0)
              puts "Create and Send Worker for List"
              IronWorker.config.no_upload = true
              worker = TeamDailyWorker.new
              worker.team_list = send_team_list
              resp = worker.queue
              counter += 1
            end
            send_team_list = []
            #puts 'YAHOO DEFAULT '+team.league_name + '-' + team.team_name
            send_team_list.push(team._id)
            current_auth_id = team.auth_info_id
         else
           #puts 'YAHOO DEFAULT '+team.league_name + '-' + team.team_name
           send_team_list.push(team._id)
         end
      
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
        log_error('sys', team, 'dailystartyahooworker',msg)
        @success = false
      end  
    end
    
    if (send_team_list.length!=0)
      begin
        puts "Create and Send Worker for List"
        IronWorker.config.no_upload = true
        worker = TeamDailyWorker.new
        worker.team_list = send_team_list
        resp = worker.queue
        counter += 1
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
        log_error('sys', nil, 'dailystartyahooworker',msg)
        @success = false
      end
    end
    
    log_info('sys', nil, 'dailystartyahooworker',"Finished Daily Start Yahoo Total User Processed - #{counter}")
    
    render(:partial => 'loading')
  end
  
  def espnstartworker
    
    @success = true
    #Get Team List that is not empty and where batter or pitcher daily is true
    team_list = Team.where(:team_type=>ESPN_AUTH_TYPE, 
    :empty_team=>false,
    :$or => [{:daily_auto_batter => true},{:daily_auto_pitcher => true}]).sort(:auth_info_id.desc)
    
    send_team_list = []
    current_auth_id = ''
    counter = 0
         
    team_list.each do |team|
      begin           
         
         if (counter%75 == 0 && counter!=0)
           #puts "#{counter}  Mod - #{counter%5}"
           sleep 5
         end
    
         if (current_auth_id != team.auth_info_id)
            if (send_team_list.length!=0)
              puts "Create and Send Worker for List"
              IronWorker.config.no_upload = true
              worker = TeamDailyWorker.new
              worker.team_list = send_team_list
              resp = worker.queue
              counter += 1
            end
            send_team_list = []
            
            send_team_list.push(team._id)
            current_auth_id = team.auth_info_id
         else
           
           send_team_list.push(team._id)
         end
      
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
        log_error('sys', team, 'dailystartespnworker',msg)
        @success = false
      end  
    end
    
    if (send_team_list.length!=0)
      begin
        puts "Create and Send Worker for List"
        IronWorker.config.no_upload = true
        worker = TeamDailyWorker.new
        worker.team_list = send_team_list
        resp = worker.queue
        counter += 1
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
        log_error('sys', nil, 'dailystartespnworker',msg)
        @success = false
      end
    end
    
    log_info('sys', nil, 'dailystartespnworker',"Finished Daily Start ESPN Total User Processed - #{counter}")
    
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
  
  def clearfootballscratch
    @success = true
    #Get Scratch List where scratch = true to set to false
    scratch_list = FootballPlayer.where(:scratched=>true)
    
    
    scratch_list.each do |player|
      begin  
        player.scratched = false
        player.save
        puts player.full_name
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
        log_error('sys', team, 'espnrealtime',msg)
        @success = false
      end  
    end
    
    render(:partial => 'loading')
  end
  
  def players_football
    @success = true                    
    
    begin   
      puts 'Get All Offense'
      parse_football_player_list(YAHOO_OFFENSE_SEASON_FOOTBALL_URL, 'OFF')      
    rescue => msg
      puts "ERROR OCCURED (#{msg})"
      log_error('sys', nil, 'error getting football offense',msg)
      @success = false
    end
    
    begin   
      puts 'Get Team Defense'
      parse_football_player_list(YAHOO_DEFENSE_SEASON_FOOTBALL_URL, 'DEF')      
    rescue => msg
      puts "ERROR OCCURED (#{msg})"
      log_error('sys', nil, 'error getting team defense',msg)
      @success = false
    end
    
    begin   
      puts 'Get All Kicker'
      parse_football_player_list(YAHOO_KICKER_SEASON_FOOTBALL_URL,'KICK')      
    rescue => msg
      puts "ERROR OCCURED (#{msg})"
      log_error('sys', nil, 'error getting football kickers',msg)
      @success = false
    end
    
    begin   
      puts 'Get All IDP'
      parse_football_player_list(YAHOO_DEF_PLAYER_SEASON_FOOTBALL_URL,'IDP')      
    rescue => msg
      puts "ERROR OCCURED (#{msg})"
      log_error('sys', nil, 'error getting football IDP',msg)
      @success = false
    end
    
    render(:partial => 'loading')
    
  end
  
  def logs
    @log_list = Log.where(:method.ne=>'inactive_process').all
    render(:partial => 'logs')
  end
  
  def log_inactive
    @log_list = Log.where(:method=>'inactive_process').all
     render(:partial => 'logs')
  end
  
  def users
    @user_list = UserInfo.sort(:updated_at.desc)
    render(:partial => 'users')
  end
  
  def footballworker
    
    @success = true
    #Get Team List that is not empty and active = true
    team_list = FootballTeam.where( 
    :empty_team=>false,
    :active=>true).sort(:auth_info_id.desc)
    
    send_team_list = []
    current_auth_id = ''
    counter = 0
         
    team_list.each do |team|
      begin           
         
         if (counter%75 == 0 && counter!=0)
           #puts "#{counter}  Mod - #{counter%5}"
           sleep 5
         end
    
         if (current_auth_id != team.auth_info_id)
            if (send_team_list.length!=0)
              puts "Create and Send Worker for List"
              IronWorker.config.no_upload = true
              worker = FootballDailyWorker.new
              worker.team_list = send_team_list
              resp = worker.queue
              #puts send_team_list.inspect
              counter += 1
            end
            send_team_list = []
            #puts 'FOOTBALL DEFAULT '+team.league_name + '-' + team.team_name
            send_team_list.push(team._id)
            current_auth_id = team.auth_info_id
         else
           #puts 'FOOTBALL DEFAULT '+team.league_name + '-' + team.team_name
           send_team_list.push(team._id)
         end
      
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
        log_error('sys', team, 'footballworker',msg)
        @success = false
      end  
    end
    
    if (send_team_list.length!=0)
      begin
        puts "Create and Send Worker for List"
        IronWorker.config.no_upload = true
        worker = FootballDailyWorker.new
        worker.team_list = send_team_list
        resp = worker.queue
        #puts send_team_list.inspect
        counter += 1
      rescue => msg
        puts "ERROR OCCURED (#{msg})"
        log_error('sys', nil, 'footballworker',msg)
        @success = false
      end
    end
    
    log_info('sys', nil, 'footballworker',"Finished Daily Football Total Teams Processed - #{counter}")
    
    render(:partial => 'loading')
  end
  
  def football_monitor
    @success = true
    #Heroku Server is Pacific Time  -7 from UTC
    week = get_week()
    current_time = Time.now
    week_day = current_time.wday
    current_hour = current_time.hour
    
    puts current_time
    puts "Current Week #{week}"
    puts "Current Day #{week_day}"    
    puts "Current Hour #{current_hour}"
    
    
    parse_bool = true
    
    #For Thursday 4 Scrape Inactive List Between 16 and 18
    if (week_day == 4 && (current_hour >= 16 && current_hour< 18))
      parse_bool = false
    end
    #For Sunday 0 Scrape Inactive List Between 8 and 11,  11 and 14, 15 and 18
    if (week_day == 0 && (current_hour >= 8 && current_hour< 11))
      parse_bool = false
    end
    if (week_day == 0 && (current_hour >= 11 && current_hour< 14))
      parse_bool = false
    end
    if (week_day == 0 && (current_hour >= 15 && current_hour< 18))
      parse_bool = false
    end
    #For Monday 1 Scrape Inactive List Between 16 and 18
    if (week_day == 1 && (current_hour >= 16 && current_hour< 18))
      parse_bool = false
    end
    #For Thursday 4 Week 12 Scrape Inactive List Between  8 and 10,  11 and 14, 15 and 18
    if (week_day == 4 && week == 12 && (current_hour >= 8 && current_hour< 10))
      parse_bool = false
    end
    if (week_day == 4 && week == 12 && (current_hour >= 11 && current_hour< 14))
      parse_bool = false
    end
    if (week_day == 4 && week == 12 && (current_hour >= 15 && current_hour< 18))
      parse_bool = false
    end
    #For Saturday 6 Week 16 Scrape Inactive List  Between 16 and 18
    if (week_day == 6 && week == 16 && (current_hour >= 16 && current_hour< 18))
      parse_bool = false
    end
    

    
    if (parse_bool)
    
      puts 'Not within time range - Will Not Parse Inactive Page'
      log_info('sys', nil, 'inactive_process',"No Parse: Week #{week} - Day #{week_day} - Hour #{current_hour}")
      render(:partial => 'loading')
      return
    end
    
    puts 'Starting Parsing Inactive Process...'
    log_info('sys', nil, 'inactive_process',"START Parse: Week #{week} - Day #{week_day} - Hour #{current_hour}")
    
                      
    team_list = {}
    parse_inactive_page()
    
    #Get Scratched Player List
    inactive_list = FootballInactive.find_all_by_inactive_and_processed_and_week(true,false,week)

    
    inactive_list.each do |plyr|
        #TODO Translate Steve Johnson to Stevie Johnson   
        stat = FootballPlayerStats.find_by_full_name_and_team(plyr.full_name,plyr.team)
        if (!stat.nil?)
          puts stat.full_name + '- Found'
          plyr.processed = true
          plyr.save
          stat.football_players.each do |p|
            #puts "#{p.full_name} - |#{p.assign_pos}|"
            log_info('sys', nil, 'inactive_process',p.full_name+' Inactive and Owned')
            p.scratched = true
            p.save
            if(!p.football_team.nil? && p.assign_pos!=IR_POSITION && p.assign_pos!=ESPN_IR_SLOT)
              #Only Add to List of Team is Active
              if (p.football_team.active)
                if (team_list[p.football_team.auth_info_id].nil?)
                  team_list[p.football_team.auth_info_id] = []
                end 
                if (team_list[p.football_team.auth_info_id].index(p.football_team._id).nil?)
                  team_list[p.football_team.auth_info_id].push(p.football_team._id)
                end
                log_info('sys', p.football_team, 'inactive_player_found',p.full_name)
              end
            end
          end
        else
          #puts plyr.full_name + '- Not Found'
        end  
        
    end  #End Player Loop
    
    #Process Teams with Real Time Activated
      team_list.values.each do |t|
        begin
          puts t.inspect
          IronWorker.config.no_upload = true
          worker = FootballRealtimeWorker.new
          worker.team_list = t
          resp = worker.queue
                    
        rescue => msg
          puts "ERROR OCCURED (#{msg})"
          log_error('sys', nil, 'footballironworker',msg)
          @success = false
        end 
      end
    #Body End
    
    render(:partial => 'loading')
    
  end

  def mcat
    puts 'Starting MCAT Authentication...'
    agent = Mechanize.new
    agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
      login_url = "https://services.aamc.org/20/mcat/user/validate"
      
      nysite_am_url = "https://services.aamc.org/20/mcat/findSite/reschedule?date=300128&search_type=state&search_state=NY"
      nysite_pm_url = "https://services.aamc.org/20/mcat/findSite/reschedule?date=300129&search_type=state&search_state=NY"
      
      test_good_url = "https://services.aamc.org/20/mcat/findSite/reschedule?date=300129&search_type=state&search_state=NM"
    
    page = agent.get(login_url)
    form = page.form_with(:name => "login")
    form['username'] = 'krhee1029'
    form['password'] = 'kat35kat'
    page = agent.submit form
    puts 'Finished Authentication Post'
   
    #puts page.uri.to_s    
    
    #page = agent.get(test_good_url)
    page = agent.get(nysite_pm_url)
    
    document = Hpricot(page.parser.to_s)
        
    found = document.search("td[@class=chart_cell_header_x]")
    puts found.length
    if (found.length == 0)
      puts 'Testing Site Not Available'      
    else
      puts 'Testing Site Available'
        
      Notifications.em_found('sys', 'mcat', 'Afternoon 2pm', nil).deliver
    end
    puts page.uri.to_s  
        
    page = agent.get(nysite_am_url)
    document = Hpricot(page.parser.to_s)
        
    found = document.search("td[@class=chart_cell_header_x]")
    puts found.length
    if (found.length == 0)
      puts 'Testing Site Not Available'      
    else
      puts 'Testing Site Available'
      
      Notifications.em_found('sys', 'mcat', 'Morning 8am', nil).deliver
    end
    puts page.uri.to_s
    render(:partial => 'loading')
  end

end
