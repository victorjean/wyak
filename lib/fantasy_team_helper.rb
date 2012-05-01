require "rubygems"
require "hpricot"
require "open-uri"
require "date"
require 'timeout'



USER_AGENT = "Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/532.5 (KHTML, like Gecko) Chrome/4.0.249.89 Safari/532.5"
ACCEPT = "application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5"
#ACCEPT_ENCODING = "gzip,deflate,sdch"
#ACCEPT_LANGUAGE = "en-US,en;q=0.8"
ACCEPT_CHARSET = "utf-8;q=0.7,*;q=0.3"

SP_PITCHERS_URL = "http://baseball.fantasysports.yahoo.com/b1/1000/players?status=ALL&pos=SP&stat1=S_S_2012&sort=AR&sdir=1&count=###"
RP_PITCHERS_URL = "http://baseball.fantasysports.yahoo.com/b1/1000/players?status=ALL&pos=RP&stat1=S_S_2012&sort=AR&sdir=1&count=###"
ALL_BATTER_URL = "http://baseball.fantasysports.yahoo.com/b1/1000/players?&sort=AR&sdir=1&status=ALL&pos=B&stat1=S_S_2012&count=###"
ALL_PITCHERS_URL = "http://baseball.fantasysports.yahoo.com/b1/1000/players?status=ALL&pos=P&stat1=S_S_2012&sort=AR&sdir=1&count=###"
ALL_BATTER7_URL = "http://baseball.fantasysports.yahoo.com/b1/1000/players?&sort=AR&sdir=1&status=ALL&pos=B&stat1=S_L7&count=###"
ALL_PITCHERS7_URL = "http://baseball.fantasysports.yahoo.com/b1/1000/players?status=ALL&pos=P&stat1=S_L7&sort=AR&sdir=1&count=###"

YAHOO_BASEBALL_PAGE_URL = "http://baseball.fantasysports.yahoo.com/b1/"
ESPN_BASEBALL_PAGE_URL = "http://games.espn.go.com/flb/tools/editmyteams"

ESPN_LINEUP_SET_URL = "http://games.espn.go.com/flb/pnc/saveRoster?"

ESPN_BASEBALL_LEAGUE_URL = "http://games.espn.go.com/flb/clubhouse?pnc=on&seasonId=#{Date.today.year}&leagueId="

YAHOO_LOGIN_URL = "https://login.yahoo.com/config/login"
ESPN_LOGIN_URL = "http://games.espn.go.com/flb/signin"

STATUS_NO_GAME = 'N'

YAHOO_AUTH_TYPE = 'Y'
ESPN_AUTH_TYPE = 'E'
CBS_AUTH_TYPE = 'C'

ALWAYS_START_OPTION = 'A'
DEFAULT_START_OPTION = 'D'
BENCH_START_OPTION = 'B'
NEVER_START_OPTION = 'N'
PROB_PITCHER_START_OPTION = 'P'

BENCH_BATTER_TYPE = 'B'
BENCH_PITCHER_TYPE = 'P'

NA_TAG = 'NA'
BENCH_POSITION = 'BN'
ESPN_BENCH_POSITION = 'Bench'
ESPN_BENCH_SLOT = '16'
ESPN_DL_SLOT = '17'
DL_POSITION = 'DL'
ESPN_UTIL_SLOT = '12'
YAHOO_UTIL_SLOT = 'Util'

def parse_yahoo_team(team, first_time, tomm)
  @rosterHash = {}
  @rosterPlayerHash = {}
  @playerHash = {}
  @dbplayerHash = {}
  @currentRosterAssignHash = {}
  @total_players = 0
  
  #If Team empty reload entire team set first_time true
  if (team.empty_team.nil? || team.empty_team || team.weekly_team) 
    first_time = true
  end
    
  puts "Loading team Data First Time = #{first_time}"
  puts "Parsing yahoo league id - #{team.league_id} for team id - #{team.team_id} team name - #{team.team_name}"
  if (team.team_type != YAHOO_AUTH_TYPE)
    puts 'YAHOO Parser - Incorrect Team Type Passed Into Method'
    return
  end
  
  agent = authenticate_yahoo(team.auth_info)
 
  
  
  if (tomm)
    curr_date = Date.today
    curr_date = curr_date+1
    page = agent.get(YAHOO_BASEBALL_PAGE_URL+team.league_id+"/"+team.team_id+"?date="+curr_date.strftime('%Y-%m-%d'))
  else
    page = agent.get(YAHOO_BASEBALL_PAGE_URL+team.league_id+"/"+team.team_id)
  end
  
  document = Hpricot(page.parser.to_s)
  
  #Get Crumb and Ret Type Information Used for Setting Lineup
  crumbHash = {}
  crumb_value = document.search("input[@name=crumb]").first.get_attribute("value").strip
  ret_classic_mode = document.search("input[@id=ret-classic]").first.to_s  
  ret_mode = 'classic'
  if (ret_classic_mode.index('checked').nil?)
    ret_mode = 'dnd'
  end
  crumbHash['crumb_value']=crumb_value
  crumbHash['ret_mode']=ret_mode
  
  
  puts 'Get Current Roster Assigned Hash'
  count = 0
  document.search("td[@class=pos first]").each do |position|
      #Save Position Data
      count += 1
      pos_data = position.inner_html.strip
      @currentRosterAssignHash[count] = pos_data
  end
  
  puts 'Getting Status Information'
  #Get Positions from Drop Down
  count = 0
  statusHash = {}
  document.search("td[@class=opp]").each do |item|
    count+=1
    statusHash[count] = item.inner_text.strip
    
    if (item.inner_text.strip.length == 1)
      statusHash[count] = ''
    else
      statusHash[count] = item.inner_text.strip
    end
  end
  
  
  puts 'Getting Player Position Information'
  #Get Positions from Drop Down
  count = 0
  positionHash = {}
  document.search("td[@class=edit]").each do |item|
    
    count += 1
    posArray = Array.new
    posdropdown = item.search("option")
    posinput = item.search("input")
    #check in case roster spot is empty need to validate drop down or input in edit td
    if (posdropdown.length != 0 || posinput.length != 0)
      @total_players+=1
    end
    
    posdropdown.each do |pos|
    #  puts pos.inner_html.strip
      posArray.push(pos.inner_html.strip)
    end
    positionHash[count] = posArray
  end
  
  
  puts 'Getting Player Count'
  @total_players = 0
  document.search("td[@class=player]").each do |player|
    @total_players+=1
  end
  
  if (positionHash.keys.length == 0 && @total_players !=0)
    puts 'Weekly League Found'
    team.weekly_team = true
    team.daily_auto_batter = false
    team.daily_auto_pitcher = false
  end
  
  
  #Delete and Store Roster Data If first_time is TRUE
  if (first_time)
    puts 'Deleting and Storing Roster Information for Team...'
    
    count = 0
    roster_list = Roster.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
    roster_list.each do |item|
      item.destroy
      count += 1
    end
    puts "Items Deleted - #{count}"
    
    count = 0
    bench_count = 0
    player_type = BENCH_BATTER_TYPE
    document.search("td[@class=pos first]").each do |position|
      
      #Save Position Data
      count += 1
      pos_data = position.inner_html.strip
      
      #Increment Counter if BN Position
      if(pos_data == BENCH_POSITION)
        bench_count += 1
      end
            
      @roster = Roster.new
      @roster.team_type = team.team_type
      @roster.league_id = team.league_id
      @roster.team_id = team.team_id
      @roster.order = count
      @roster.pos_text = pos_data
      @roster.pos_type = player_type
      @roster.slot_number = pos_data
      @roster.save
      
      @rosterHash[count] = @roster
    end
    #Create Extra Roster Bench Slots as Place Holders
    extra_bench_number = @total_players - bench_count + 4
    puts "Total Players - #{@total_players}"
    puts "Bench Count - #{bench_count}"
    puts "Create Extra + 4BN - #{extra_bench_number}"
    begin
      count += 1
      @roster = Roster.new
      @roster.team_type = team.team_type
      @roster.league_id = team.league_id
      @roster.team_id = team.team_id
      @roster.order = count
      @roster.pos_text = BENCH_POSITION
      @roster.pos_type = BENCH_PITCHER_TYPE
      @roster.slot_number = BENCH_POSITION
      @roster.save
      extra_bench_number -= 1
    end while extra_bench_number > 0
  
  end #End Storing Roster Block if first_time
  
  #If not first_time store player list in DB
  if (!first_time)
    puts 'Getting Current Player List from DB...'
    player_db_list = Player.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
    player_db_list.each do |item|
      @dbplayerHash[item.yahoo_id] = item
    end
  else
    puts 'Reload Players - Delete All From Database for Team'
    player_db_list = Player.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
    player_db_list.each do |item|
      item.destroy
    end
  end
  
  
  puts 'Updating/Creating Player Information'
  #Get Players on Team
  count = 0
  document.search("td[@class=player]").each do |player|
    count += 1
    nametag = player.search("a").first
    idtag = player.search("a").last
    postag = player.search("span").first
    statustag = player.search("span[@class=status]").first
    
    if (!nametag.nil? && !idtag.nil? && !postag.nil?)
      full_name = nametag.inner_html.strip            
      yahoo_id = idtag.get_attribute("data-ys-playerid").strip
      split_postag = postag.inner_html.strip.split("-")
      #Store Team Name on Page to Match Yahoo Box ???
      team_name = split_postag.first[1..-1].strip.upcase
      position_elig = split_postag.last.chomp(')').strip
      @player = Player.find_or_create_by_yahoo_id_and_league_id_and_team_id(yahoo_id, team.league_id, team.team_id)
      @player.team_type = team.team_type
      @player.league_id = team.league_id
      @player.team_id = team.team_id
      @player.yahoo_id = yahoo_id
      @player.full_name = full_name
      if(!positionHash[count].nil? && positionHash[count].length != 0)
      @player.eligible_pos = positionHash[count]
      @player.eligible_slot = positionHash[count]
      end
      @player.position_text = position_elig
      @player.team_name = team_name
      @player.current_slot = @currentRosterAssignHash[count]
      @player.game_status = statusHash[count]
      @player.game_today = (statusHash[count] != '' )
      @player.in_lineup = (!statusHash[count].index('^').nil?)
      
      plyr_stats = PlayerStats.find_by_yahoo_id(yahoo_id)
      if (!plyr_stats.nil?)
        @player.player_stats = plyr_stats
        if (plyr_stats.is_sp && first_time)
          @player.action = PROB_PITCHER_START_OPTION 
        end
      end
      
      if (@player.current_slot == DL_POSITION)
        @player.roster_id = nil  
      end
      
      #Check if DL Status is Marked next to Player
      if (!statustag.nil? && statustag.inner_html.strip == DL_POSITION)
        @player.on_dl = true
      else
        @player.on_dl = false  
      end
      
      #Check if NA Status is Marked next to Player
      if (!statustag.nil? && statustag.inner_html.strip == NA_TAG)
        @player.on_na = true
      else
        @player.on_na = false  
      end
      
      @player.save     
      
      @playerHash[yahoo_id] = @player
      @rosterPlayerHash[count] = @player
    end
    
  end  # End Loop through players
  
  #First Time Assign Players to Roster Positions
  if (first_time)
    puts 'First Time Assigning Players to Roster Positions'
    #Assign Only if Roster Position is not DL
    @rosterHash.keys.each do |counter|
      if(@rosterHash[counter].pos_text != DL_POSITION && @rosterHash[counter].pos_text != YAHOO_UTIL_SLOT)
      @rosterHash[counter].player = @rosterPlayerHash[counter]
      @rosterHash[counter].save
      end
      if (@rosterHash[counter].pos_text == YAHOO_UTIL_SLOT)
        @rosterHash[counter].save
      end
    end
    puts 'DL Players Assign to Bench'
    assign_players_bench(team)
  else
    #If Roster Player Hash Empty or No Players, then don't delete
    #May be a authentication error
    if (@playerHash.length != 0)  
      puts 'Remove Players No Longer on Team From DB'
      @dbplayerHash.keys.each do |yid|
        if (@playerHash[yid].nil?)
          puts 'Deleting - ' + @dbplayerHash[yid].inspect 
          @dbplayerHash[yid].destroy
        end
      end
      assign_players_bench(team)
    end
    
  
  end #End Else Statement
  
  #Check if players are empty
  if (@rosterPlayerHash.length == 0 && first_time)
    team.empty_team = true
  end
  if (@rosterPlayerHash.length != 0 && first_time)
    team.empty_team = false
  end
  
  team.save
  #Return Crumb Info to Set Lineup
  crumbHash
  
end

def get_player_by_roster_slot(roster_slot)
  @rosterPlayerHash.keys.each do |counter|
      if (@rosterPlayerHash[counter].current_slot == roster_slot && @rosterPlayerHash[counter].assign_slot.nil? )
          @rosterPlayerHash[counter].assign_slot = roster_slot
          return  @rosterPlayerHash[counter]
      end
    end
    nil
end

def assign_players_bench(team)
    
    benchHash = {}
    puts 'Get Empty Bench Slot List'
    count = 0
    Roster.all(:pos_text=>BENCH_POSITION, :league_id=>team.league_id, :team_id=>team.team_id,:team_type=>team.team_type ).each do |bench|
      if (bench.player.nil?)
        count += 1
        benchHash[count] = bench
      end
    end
    puts 'Assign New Player or DL to Empty Bench Slot'
    count = 0
    @rosterPlayerHash.keys.each do |counter|
      if (@rosterPlayerHash[counter].roster_id.nil?)
        count += 1
        benchHash[count].player = @rosterPlayerHash[counter]
        benchHash[count].save
      end
    end
end

def authenticate_yahoo(auth)
  if (@agent.nil? || @current_auth_id != auth._id)
    puts 'Starting Yahoo Authentication...'
    @agent = Mechanize.new
    @agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
    #Locale Check
    login_url = YAHOO_LOGIN_URL
    if (auth.region.nil? || auth.region == 'US')
      
    else
      login_url = YAHOO_LOGIN_URL+'?.intl='+auth.region
    end
    page = @agent.get(login_url)
    form = page.form_with(:id => "login_form")
    form['login'] = auth.login
    form['passwd'] = auth.get_pass
    page = @agent.submit form
    puts 'Finished Authentication Post'
    @current_auth_id = auth._id
    puts page.uri.to_s
    #Throw Exception if Authentication Fails
    if (!page.uri.to_s.index('login?').nil?)
      @agent = nil
      raise 'Authentication Failed for URL|'+login_url+'|YAHOO ID|'+auth.login+'/'+auth.get_pass+'|-' + page.uri.to_s
    end
  end
  @agent
end

def authenticate_espn(auth)
  if (@agent.nil? || @current_auth_id != auth._id)
    puts 'Starting ESPN Authentication...'
    @agent = Mechanize.new
    @agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
    page = @agent.get(ESPN_LOGIN_URL)
    form = page.form_with(:name => "loginForm")
    form['username'] = auth.login
    form['password'] = auth.get_pass
    page = @agent.submit form
    puts 'Finished Authentication Post'
    @current_auth_id = auth._id
    #puts page.uri.to_s
    #Throw Exception if Authentication Fails
    if (!page.uri.to_s.index('secureRedirect').nil?)
      @agent = nil
      raise 'Authentication Failed for ESPN ID - '+auth.login 
    end
  end
  @agent
end

def load_yahoo_first_time(user_info)
  #First Load Yahoo Teams into Database
  load_yahoo_teams(user_info,true)
  #parse through each team page and store data
  Team.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE).each do |team|
    parse_yahoo_team(team,true, true)
  end
end

def load_espn_first_time(user_info)
  #First Load ESPN Teams into Database
  load_espn_teams(user_info,true)
  #parse through each team page and store data
  Team.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE).each do |team|
    parse_espn_team(team,true, true)
  end
end

def load_yahoo_teams(user_info, reload)
  auth_user = AuthInfo.find_by_email_and_auth_type(user_info.email,YAHOO_AUTH_TYPE)
  if (auth_user.nil?)
    return
  end
  
  agent = authenticate_yahoo(auth_user)
  
  puts 'Loading all Yahoo Teams into Database for User - '+user_info.email
  team_list = Team.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE)
  
  if (reload)    
    puts 'Deleting Teams from DB...'
      
    team_list.each do |item|
      #Delete Real Time Player Info
      PlayerRealtime.delete_all(:team_id=>item._id)
      item.destroy
      puts item.league_id + ' Deleted'
    end
  end
  
  #Delete any AUTO league teams until drafted
  team_list.each do |item|
      if (item.league_id == 'auto')
      item.destroy
      puts item.league_id + ' Deleted'
      end
  end
  
  page = agent.get(YAHOO_BASEBALL_PAGE_URL)
  doc = Hpricot(page.parser.to_s)
  team_list_tag = doc.search("ul[@class=ysf-teamlist]").first
  #If Properly Logged In, User Should have a Team Tag Check for Nil
  if (!team_list_tag.nil?)
    doc.search("ul[@class=ysf-teamlist]") do |fantasy_team_tag|
    
      fantasy_team_tag.search("li") do |teamlink|
            
        #Get Tag Containing Team URL
        team_href_tag = teamlink.search("a[@class=yuimenuitemlabel name]").first
        if (!team_href_tag.get_attribute("href").index(YAHOO_BASEBALL_PAGE_URL).nil?)
          #Get Tag Containing League ID
          league_href_tag = teamlink.search("a[@class=yuimenuitemlabel]").first
          #Get League and Team ID String
          league_team_ids = team_href_tag.get_attribute("href").strip.gsub(YAHOO_BASEBALL_PAGE_URL,'')
           
          #team = Team.new
          team = Team.find_or_create_by_league_id_and_team_id_and_team_type(league_team_ids.split('/').first.strip,league_team_ids.split('/').last.strip,YAHOO_AUTH_TYPE)
          team.team_type = YAHOO_AUTH_TYPE
          team.auth_info = auth_user
          team.user_info = user_info
          team.team_name = team_href_tag.inner_html.strip
          team.league_id =  league_team_ids.split('/').first.strip
          team.team_id = league_team_ids.split('/').last.strip
          team.league_name = league_href_tag.inner_html.strip
          team.save
          
          puts 'Team Saved - '+team.inspect
        end# end baseball check
      end #end loop through teams
      
    end #Outer Team List Loop
  else
    puts 'No Teams found for the Yahoo User Info Provided'
  end
end

def load_espn_teams(user_info, reload)
  auth_user = AuthInfo.find_by_email_and_auth_type(user_info.email,ESPN_AUTH_TYPE)
  if (auth_user.nil?)
    return
  end
  
  agent = authenticate_espn(auth_user)
  
  puts 'Loading all ESPN Teams into Database for User - '+user_info.email
  team_list = Team.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE)
  
  if (reload)
    puts 'Deleting Teams from DB...'
      
    team_list.each do |item|
      #Delete Real Time Player Info
      PlayerRealtime.delete_all(:team_id=>item._id)
      item.destroy
      puts item.league_id + ' Deleted'
    end
  end
  
  page = agent.get(ESPN_BASEBALL_PAGE_URL)
  doc = Hpricot(page.parser.to_s)
  team_list_tag = doc.search("ul[@id=myteams]").first
  #If Properly Logged In, User Should have a Team Tag Check for Nil
  if (!team_list_tag.nil?)
    team_list_tag.search("li") do |teamlink|
      team_name = teamlink.search("span").first.inner_html
      league_name = teamlink.search("span").last.inner_html
      team_name = team_name.strip
      league_name = league_name.strip[2..-1]
      
      puts league_name +' - '+team_name
      league_team_ids = teamlink.get_attribute("id").gsub('myteams_','').strip
      
      #try leagueid by chopping off the last digit, if it fails, then remove the last 2 digits
      team_id = ''
      league_id = league_team_ids.chop
      
      puts 'trying URL with league_id - '+ league_id
      page = agent.get(ESPN_BASEBALL_LEAGUE_URL + league_id)
      puts page.uri
      if (page.uri.to_s.index('error').nil?)
        #Get TeamId and LeagueId
        url_str = page.uri.to_s.split('?').last.split('&')
        league_id = url_str.first.split('=').last.strip
        team_id = url_str.last.split('=').last.strip
        
        
      else
        league_id = league_id.chop
        puts 'trying second URL with league_id - '+ league_id
        page = agent.get(ESPN_BASEBALL_LEAGUE_URL + league_id)
        puts page.uri
        if (page.uri.to_s.index('error').nil?)
          #Get TeamId and LeagueId
          url_str = page.uri.to_s.split('?').last.split('&')
          league_id = url_str.first.split('=').last.strip
          team_id = url_str.last.split('=').last.strip
        else
          #If Error found skip this team
          puts 'could not find correct league id url...skipping'
          next
        end    
      end
      
      #team = Team.new
      team = Team.find_or_create_by_league_id_and_team_id_and_team_type(league_id,team_id,ESPN_AUTH_TYPE)
      team.team_type = ESPN_AUTH_TYPE
      team.auth_info = auth_user
      team.user_info = user_info
      team.team_name = team_name
      team.league_id =  league_id
      team.team_id = team_id
      team.league_name = league_name
      team.save
      
      puts 'Team Saved - '+team.inspect
    end #End Team Loop
  else
    puts 'No Teams found for the ESPN User Info Provided'
  end
end

def post_espn(auth)
  agent = authenticate_espn(auth)

  page = agent.get('http://games.espn.go.com/frontpage/baseball')
  doc = Hpricot(page.parser.to_s)
  doc.search("a[@class=clubhouse-link]").each do |team|
    puts team  
  end
  
  postHash = {}
  
  agent.post('http://games.espn.go.com/flb/pnc/saveRoster?leagueId=32280&teamId=7&scoringPeriodId=1&returnSm=true&trans=1_613_1_16', postHash)
  
  
  puts 'done posting'
  
  
end

def post_yahoo(auth)
  agent = authenticate_yahoo(auth)
  page = agent.get('http://baseball.fantasysports.yahoo.com/b1/77729/9')
  doc = Hpricot(page.parser.to_s)
  crumb_value = doc.search("input[@name=crumb]").first.get_attribute("value").strip
  puts crumb_value
  postHash = {}
  
  postHash['8395'] = 'C'
  postHash['7054'] = 'BN'
  postHash['7631'] = '2B'
  postHash['8874'] = '3B'
  postHash['5406'] = 'BN'
  postHash['6679'] = 'OF'
  postHash['8034'] = 'OF'
  postHash['7498'] = 'OF'
  postHash['7746'] = 'Util'
  postHash['6423'] = 'Util'
  postHash['7278'] = '1B'
  postHash['8795'] = 'BN'
  postHash['8762'] = 'BN'
  postHash['7981'] = 'BN'
  postHash['8567'] = 'BN'
  postHash['7964'] = 'RP'
  postHash['7679'] = 'RP'
  postHash['8172'] = 'P'
  postHash['8193'] = 'P'
  postHash['7547'] = 'P'
  postHash['8540'] = 'P'
  postHash['6893'] = 'BN'
  postHash['7504'] = 'SP'
  postHash['date'] = '2012-03-17'
  postHash['jsubmit'] = 'submit changes' 
  postHash['ret'] = 'classic'
  postHash['crumb'] = crumb_value
  
  page = agent.post('http://baseball.fantasysports.yahoo.com/b1/77729/9/editroster',postHash)
  puts 'done posting'
  #puts page.parser.to_s
end

def parse_espn_team(team, first_time, tomm)
  @slotToPosHash = {}
  @posToSlotHash = {}  
  @rosterHash = {}
  @rosterPlayerHash = {}
  @playerHash = {}
  @dbplayerHash = {}
  @teamHash = {}
  @statusHash = {}
  
  #If Team empty reload entire team set first_time true
  if (team.empty_team.nil? || team.empty_team) 
    first_time = true
  end
    
  puts "Loading team Data First Time = #{first_time}"
  
  puts "Parsing espn league id - #{team.league_id} for team id - #{team.team_id} team name - #{team.team_name}"
  if (team.team_type != ESPN_AUTH_TYPE)
    puts 'ESPN Parser - Incorrect Team Type Passed Into Method'
    return
  end
  
  agent = authenticate_espn(team.auth_info)
  
  
  page = agent.get(ESPN_BASEBALL_LEAGUE_URL+team.league_id)
  #page = agent.get(ESPN_BASEBALL_LEAGUE_URL+team.league_id+"&teamId=5&scoringPeriodId=20")
  
  document = Hpricot(page.parser.to_s)
  
  #get scoring period id to post espn lineup
  
  currentScoringPeriodId = '1'
  scoringPeriodTag = document.search("input[@name=scoringPeriodId]")
  if(!scoringPeriodTag.first.nil?)
    currentScoringPeriodId = scoringPeriodTag.first.get_attribute("value").strip
  end
  
  if (tomm)
    currentScoringPeriodId = currentScoringPeriodId.to_i + 1
    page = agent.get(ESPN_BASEBALL_LEAGUE_URL+team.league_id+"&teamId=#{team.team_id}&scoringPeriodId=#{currentScoringPeriodId}")
    document = Hpricot(page.parser.to_s)
  end
  
  #Get Team Hash
  
  playerNameHash = {}
  playerInLineupHash = {}
  playerDLHash = {}
  count = 0
  puts = 'Get Team Hash Table for Players'
  document.search("td[@class=playertablePlayerName]").each do |item|
    count += 1
    player_name = item.search("a").first.inner_html.strip
    @teamHash[player_name] = item.inner_html.split(',')[1].strip[0..2].upcase
    playerNameHash[count] = player_name
    #Check Here for PP or S for ESPN item.search("strong") check nil
    status_tag = item.search("strong").first
    if (status_tag.nil?)
      playerInLineupHash[player_name] = false
    else
      #Check here for ! mark or P for real time for now set to TRUE
      playerInLineupHash[player_name] = true
    end
    dl_tag = item.search("span").first
    if (!dl_tag.nil? && !dl_tag.inner_html.strip.index(DL_POSITION).nil?)
      playerDLHash[player_name] = true
    else
      playerDLHash[player_name] = false
    end
  end
  
  
  puts 'Get Game Status for Players'
  count = 0
  (document/"tr.pncPlayerRow").each do |item|
    count +=1
    name_cell = item.search("a").first
    opp_cell = item.search("td")[4].search("a").first
    if (!name_cell.nil?)
      if (opp_cell.nil?)
        @statusHash[name_cell.innerHTML.strip] = ''
        
      else
        @statusHash[name_cell.innerHTML.strip] = opp_cell.innerHTML.strip  
        
      end
    end
    
  end
  
  roster_str = []
  player_str = []
  
  document.search("script").each do |script|
    if(!script.inner_html.to_s.index('createSlot').nil?)
      roster_str = script.inner_html.to_s.split('rosterManager.createSlot')
      player_str = script.inner_html.to_s.split('rosterManager.createPlayer')
    end
  end
  
  
  bench_count = 0
  parsed_roster_list = Array.new
  roster_str.each do |item|
    slotId = ''
    posText = ''
    if(!item.index('fullAbbrev').nil?)
      item.split(',').each do |attribs|
        if (!attribs.index('slotCategoryId').nil?)
          slotId = attribs.split(':').last.strip
        end
        if (!attribs.index('fullAbbrev').nil?)
          posText = attribs.split(':').last.strip
          posText = posText.gsub(/"/, '').strip
          
          if (posText == ESPN_BENCH_POSITION)
            posText = BENCH_POSITION
            bench_count += 1          
          end
        end
      end
      
      @slotToPosHash[slotId] = posText
      @posToSlotHash[posText] = slotId
      parsed_roster_list.push(posText)
      
      
    end #End Abbrev Roster Block
    
  end # End Roster Loop
  
  @total_players = 0
  player_str.each do |item|
    if(!item.index('firstName').nil?)
      @total_players += 1
      
    end
  end #End Player Loop
  
  #Delete and Store Roster Data If first_time is TRUE
  if (first_time)
    puts 'Deleting and Storing Roster Information for Team...'
    
    count = 0
    roster_list = Roster.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
    roster_list.each do |item|
      item.destroy
      count += 1
    end
    puts "Items Deleted - #{count}"    
    count = 0
    
    player_type = BENCH_PITCHER_TYPE
    
    parsed_roster_list.each do |position|
      
      #Save Position Data
      count += 1
            
      @roster = Roster.new
      @roster.team_type = team.team_type
      @roster.league_id = team.league_id
      @roster.team_id = team.team_id
      @roster.order = count
      @roster.pos_text = position
      @roster.pos_type = player_type
      @roster.slot_number = @posToSlotHash[position]
      @roster.save
      
      @rosterHash[count] = @roster
    end
    #Create Extra Roster Bench Slots as Place Holders
    extra_bench_number = @total_players - bench_count + 4
    puts "Total Players - #{@total_players}"
    puts "Bench Count - #{bench_count}"
    puts "Create Extra + 4BN - #{extra_bench_number}"
    begin
      count += 1
      @roster = Roster.new
      @roster.team_type = team.team_type
      @roster.league_id = team.league_id
      @roster.team_id = team.team_id
      @roster.order = count
      @roster.pos_text = BENCH_POSITION
      @roster.pos_type = BENCH_PITCHER_TYPE
      @roster.slot_number = @posToSlotHash[BENCH_POSITION]
      @roster.save
      @rosterHash[count] = @roster
      extra_bench_number -= 1
    end while extra_bench_number > 0
  
  end #End Storing Roster Block if first_time
  
  
  #If not first_time store player list in DB
  if (!first_time)
    puts 'Getting Current Player List from DB...'
    player_db_list = Player.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
    player_db_list.each do |item|
      @dbplayerHash[item.espn_id] = item
    end
  else
    puts 'Reload Players - Delete All From Database for Team'
    player_db_list = Player.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
    player_db_list.each do |item|
      item.destroy
    end
  end
  
  
  puts 'Updating/Creating Player Information'
  #Get Players on Team
  count = 0
  player_str.each do |item|
    if(!item.index('firstName').nil?)
      count += 1
      espn_id = ''
      first_name = ''
      last_name = ''
      curr_slot = ''
      
      
      #Get Position Eligible Array
      slotPosArray = Array.new
      textPosArray = Array.new
      pos_text = ''
      start_bracket = item.index('[')+1
      end_bracket = item.index(']')-1
      slot_ids = item[start_bracket..end_bracket].split(',')
      slot_ids.each do |id|
        slotPosArray.push(id.strip)
        textPosArray.push(@slotToPosHash[id.strip])
        if (@slotToPosHash[id.strip]!='UTIL'&&@slotToPosHash[id.strip]!='BN'&&@slotToPosHash[id.strip]!='DL')
          pos_text = pos_text + @slotToPosHash[id.strip] + ','
        end
      end
      #Check to see if player is just UTIL
      if(pos_text == '')
        pos_text = 'UTIL'
      else
        pos_text = pos_text.chop
      end
      
      
      item.split(',').each do |attribs|
        if (!attribs.index('playerId').nil?)
          espn_id = attribs.split(':').last.strip
        end
        if (!attribs.index('initialSlotCategoryId').nil?)
          curr_slot = attribs.split(':').last.strip
        end
        if (!attribs.index('firstName').nil?)
          first_name = attribs.split(':').last.strip
          first_name = first_name.gsub(/"/, '').strip
        end
        if (!attribs.index('lastName').nil?)
          last_name = attribs.split(':').last.strip
          last_name = last_name.gsub(/"/, '').strip
        end
      end
      
      full_name = first_name + ' '+ last_name
      @player = Player.find_or_create_by_espn_id_and_league_id_and_team_id(espn_id, team.league_id, team.team_id)
      #@player = Player.new
      @player.team_type = team.team_type
      @player.league_id = team.league_id
      @player.team_id = team.team_id
      @player.espn_id = espn_id
      @player.full_name = full_name
      @player.current_slot = curr_slot 
      @player.eligible_slot = slotPosArray
      @player.eligible_pos = textPosArray
      @player.position_text = pos_text
      @player.team_name = @teamHash[full_name]
      if (playerInLineupHash[full_name])
      @player.game_status = "^"+@statusHash[full_name]
      else
      @player.game_status = @statusHash[full_name]
      end
      @player.in_lineup = playerInLineupHash[full_name]
      @player.game_today = (@statusHash[full_name] != '' )
      @player.on_dl = playerDLHash[full_name]
      
      plyr_stats = PlayerStats.find_by_espn_id(espn_id)
      if (!plyr_stats.nil?)
        @player.player_stats = plyr_stats
        if (plyr_stats.is_sp && first_time)
          @player.action = PROB_PITCHER_START_OPTION 
        end
      else
        plyr_stats = PlayerStats.find_by_full_name(full_name)
        if (!plyr_stats.nil?)
          @player.player_stats = plyr_stats
          if (plyr_stats.is_sp && first_time)
            @player.action = PROB_PITCHER_START_OPTION 
          end
          plyr_stats.espn_id = espn_id
          plyr_stats.save
        end
      end
      
      if (@player.current_slot == ESPN_DL_SLOT)
        @player.roster_id = nil  
      end
      
      @player.save
      
      @playerHash[espn_id] = @player
      @rosterPlayerHash[count] = @player
    end
  end #End Player Loop
  
  #First Time Assign Players to Roster Positions
  if (first_time)
    puts 'First Time Assigning Players to Roster Positions'
    @rosterHash.keys.each do |counter|
      if (@rosterHash[counter].slot_number != ESPN_DL_SLOT && @rosterHash[counter].slot_number != ESPN_UTIL_SLOT)
      @rosterHash[counter].player = get_player_by_roster_slot(@rosterHash[counter].slot_number)
      @rosterHash[counter].save
      end
      if (@rosterHash[counter].slot_number == ESPN_UTIL_SLOT)
        @rosterHash[counter].save
      end
    end
    assign_players_bench(team)
  else
    #If Roster Player Hash Empty or No Players, then don't delete
    #May be a authentication error
    if (@playerHash.length != 0)
      puts 'Remove Players No Longer on Team From DB'
      @dbplayerHash.keys.each do |yid|
        if (@playerHash[yid].nil?)
          puts 'Deleting - ' + @dbplayerHash[yid].inspect 
          @dbplayerHash[yid].destroy
        end
      end
      assign_players_bench(team)
    end
  
  end #End Else Statement
  
  
  #Check if players are empty
  if (@rosterPlayerHash.length == 0 && first_time)
    team.empty_team = true
  end
  if (@rosterPlayerHash.length != 0 && first_time)
    team.empty_team = false
  end
  team.save
  #return value
  currentScoringPeriodId
end

def print_player_list(player_list)
  player_list.each do |item|
    puts "#{item.assign_pos} - #{item.full_name} - #{item.player_set} - #{item.assign_slot}"
  end
end

def print_roster_list(roster_list)
  roster_list.each do |item|
    puts "#{item.pos_text}(#{item.slot_number}) - #{item.leave_empty} - #{item.elig_players.length} - #{item.pos_type}"
    
  end
end

def assign_player_position(roster_list)
    #loop through roster and for elig_players size = 1, assign  
    #else use priority to assign and re-loop until elig_players size = 0
    #roster_list = roster_list.sort{|x,y| x.elig_players.length<=>y.elig_players.length}
    roster_list = roster_list.sort_by{|x| [x.elig_players.length, x.order]}
    roster_list.each do |item|
      if (item.elig_players.length == 1 && item.leave_empty == false)
        puts "assign player #{item.elig_players[0].full_name} to #{item.pos_text} - #{item}"
        item.elig_players[0].assign_pos = item.pos_text
        item.elig_players[0].assign_slot = item.slot_number
        item.elig_players[0].player_set = true
        item.leave_empty = true
        item.elig_players = []
        return true
      end
      if (item.elig_players.length > 1 && item.leave_empty == false)
        #start highest priority player
        item.elig_players.sort!{|x,y| x.priority<=>y.priority}
        puts "length #{item.elig_players.length} - assign player #{item.elig_players[0].full_name} to #{item.pos_text} - #{item}"
        item.elig_players[0].assign_pos = item.pos_text
        item.elig_players[0].assign_slot = item.slot_number
        item.elig_players[0].player_set = true
        item.leave_empty = true
        item.elig_players = []
        return true
      end
    end
    
    false  
end

def set_assigned_player_in_empty_roster(player, roster_list)
  if (player.scratched)
    roster_list.each do |item|
      if (player.temp_pos == item.pos_text && !item.leave_empty && item.pos_text != DL_POSITION)
           player.assign_slot = player.temp_slot
           player.assign_pos = player.temp_pos
           item.leave_empty = true
           
           return
      end
    end
  end
end

def set_eligible_player_in_roster(player, roster_list)
  roster_list.each do |item|
    if (!item.leave_empty && !player.eligible_slot.index(item.slot_number).nil?)
      item.elig_players.push(player)
    end
  end
end

def set_player_in_roster(player, roster_list)
  roster_list.each do |item|
    #puts "|#{item.pos_text}| - |#{player.assign_pos}|"
    if (!item.leave_empty && player.assign_pos == item.pos_text)
      item.leave_empty = true
      return
    end
    #DL Slots Set to Leave Empty
    if (item.pos_text == DL_POSITION)
      item.leave_empty = true
    end
    
  end
end

def assign_player_in_roster(player, roster_list)
  roster_list.each do |item|
    if (item.player.nil? && player.assign_pos == item.pos_text)
      item.player = player
      return
    end
  end
  #if no room for player, assign to bench
  player.assign_pos = BENCH_POSITION 
  roster_list.each do |item|
    if (item.player.nil? && player.assign_pos == item.pos_text)
      item.player = player
      return
    end
  end
end

def player_assignment_daily(player_list, roster_list)
  #apply daily algorithm for setting player lineup
  
  #any player in the DL spot don't move
  player_list.each do |item|
    if ((item.current_slot == DL_POSITION || item.current_slot == ESPN_DL_SLOT) && !item.player_set)
      item.player_set = true
      item.assign_pos = DL_POSITION
      item.assign_slot = ESPN_DL_SLOT
    end
  end
  
  #set any player with always start to player_set true
  player_list.each do |item|
    if (item.action == ALWAYS_START_OPTION && !item.player_set)
      item.player_set = true
    end
  end
  
  #set any player with never start to player_set true and bench
  player_list.each do |item|
    if (item.action == NEVER_START_OPTION && !item.player_set)
      item.assign_pos = BENCH_POSITION
      item.assign_slot = ESPN_BENCH_SLOT
      item.player_set = true
    end
  end
  
  #set any player on DL to the BENCH
  player_list.each do |item|
    if (item.on_dl  && !item.player_set)
      item.assign_pos = BENCH_POSITION
      item.assign_slot = ESPN_BENCH_SLOT
      item.player_set = true
    end
  end
  
  #set any player on NA to the BENCH
  player_list.each do |item|
    if (item.on_na  && !item.player_set)
      item.assign_pos = BENCH_POSITION
      item.assign_slot = ESPN_BENCH_SLOT
      item.player_set = true
    end
  end
  
  #if no game today set to BENCH and player_set true
  player_list.each do |item|
    if (!item.game_today && !item.player_set)
      #set :scratched temp field to indicate player was assigned to fill
      #empty spots if there are no bench players to fill that slot
      if (item.assign_pos != BENCH_POSITION)
        item.scratched = true
        item.temp_pos = item.assign_pos
        item.temp_slot = item.assign_slot
      end
      item.assign_pos = BENCH_POSITION
      item.assign_slot = ESPN_BENCH_SLOT
      item.player_set = true
    end
  end
  
  #if not probable pitcher today set to BENCH and player_set true
  player_list.each do |item|
    if (item.action == PROB_PITCHER_START_OPTION && !item.in_lineup && !item.player_set)
      item.assign_pos = BENCH_POSITION
      item.assign_slot = ESPN_BENCH_SLOT
      item.player_set = true
    end
  end
  
  #for default starter player and assigned to position set true
  player_list.each do |item|
    if (item.action == DEFAULT_START_OPTION && item.assign_pos != BENCH_POSITION && !item.player_set)
      item.player_set = true
    end
  end
  
  #set roster spots as filled from player list
  player_list.each do |player|
    if (player.assign_pos != BENCH_POSITION && player.player_set)
      set_player_in_roster(player, roster_list)
    end
  end
  
  #loop through open roster spots until all spot are filled
  not_all_zero = true
  begin
    #clear roster slots of playera
    roster_list.each do |item|
      item.elig_players = []
    end
    
    #assign available & eligible players to available roster slots
    #sort by priority
    player_list.sort_by!{|x| [x.priority]}
    player_list.each do |player|
      if (!player.player_set)
        set_eligible_player_in_roster(player, roster_list)
      end
    end
    
    not_all_zero = assign_player_position(roster_list)
  end while not_all_zero

  
  #print_roster_list(roster_list)
  #print_player_list(player_list)
  player_list
end

def set_yahoo_default(team, tomm)
  #update team in database
  crumbHash = parse_yahoo_team(team, false, tomm)
  #Get roster list where position is not bench and dl and empty 
  roster_list = Roster.where(:pos_text.ne=>BENCH_POSITION, :team_type=>team.team_type, :team_id=>team.team_id, :league_id=>team.league_id).all
  player_list = Player.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
  
  player_list = player_assignment_daily(player_list, roster_list)
  
  #try to set assigned players into roster spots that are still empty
  player_list.each do |p|
    set_assigned_player_in_empty_roster(p, roster_list)
  end
  
  set_yahoo_lineup(team, player_list, crumbHash, tomm)  
end

def set_espn_default(team, tomm)
  #update team in database
  scoring_period_id = parse_espn_team(team, false,tomm)
  #Get roster list where position is not bench and dl and empty 
  roster_list = Roster.where(:pos_text.ne=>BENCH_POSITION, :team_type=>team.team_type, :team_id=>team.team_id, :league_id=>team.league_id).all
  player_list = Player.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
  
  player_list = player_assignment_daily(player_list, roster_list)
  
  #try to set assigned players into roster spots that are still empty
  player_list.each do |p|
    set_assigned_player_in_empty_roster(p, roster_list)
  end
  
  set_espn_lineup(team, player_list, scoring_period_id)  
end

def set_yahoo_lineup(team,player_list,crumbHash,tomm, real = false)
  agent = authenticate_yahoo(team.auth_info)
  
  curr_date = Date.today
  if (tomm)
    curr_date = curr_date+1
  end
  puts curr_date.strftime('%Y-%m-%d')
  postHash = {}
  postHash['date'] = curr_date.strftime('%Y-%m-%d')   
  postHash['ret'] = crumbHash['ret_mode']
  postHash['crumb'] = crumbHash['crumb_value']
  #postHash['jsubmit'] = 'submit changes'
  
  if (real)
    puts "REAL TIME"
    player_list.each do |item|
      #ignore any player in DL position
      if (item.current_slot == DL_POSITION)
        postHash[item.yahoo_id] = DL_POSITION
      else
        postHash[item.yahoo_id] = item.assign_pos
      end 
    end
  else
  
    player_list.each do |item|
      #ignore any player in DL position
      if (item.current_slot == DL_POSITION)
        postHash[item.yahoo_id] = DL_POSITION
      #start batters only if team batters active
      elsif (team.daily_auto_batter && item.position_text.index('P').nil?)
        postHash[item.yahoo_id] = item.assign_pos
      #start pitchers only if team pitchers active
      elsif(team.daily_auto_pitcher && !item.position_text.index('P').nil?)
        postHash[item.yahoo_id] = item.assign_pos
      else
        postHash[item.yahoo_id] = item.current_slot
      end 
    end
    
  end
  page = agent.post(YAHOO_BASEBALL_PAGE_URL+"#{team.league_id}/#{team.team_id}/editroster",postHash)
  puts 'done posting'
end

def set_espn_lineup(team,player_list,scoring_period_id,real = false)
  
  agent = authenticate_espn(team.auth_info)
  
  
  set_lineup_str = ''
  postHash = {}
  
  player_list.each do |item|
    
    if (item.current_slot != ESPN_DL_SLOT && item.assign_slot != item.current_slot)
      
      if (real)
        set_lineup_str = set_lineup_str + "1_#{item.espn_id}_#{item.current_slot}_#{item.assign_slot}|"
      else
        #start batters only if team batters active
        if (team.daily_auto_batter && item.position_text.index('P').nil?)
          set_lineup_str = set_lineup_str + "1_#{item.espn_id}_#{item.current_slot}_#{item.assign_slot}|"
        end
        #start pitchers only if team pitchers active
        if (team.daily_auto_pitcher && !item.position_text.index('P').nil?)
          set_lineup_str = set_lineup_str + "1_#{item.espn_id}_#{item.current_slot}_#{item.assign_slot}|"
        end
      end
      
    end
  end
  puts set_lineup_str.chop
  
  agent.post(ESPN_LINEUP_SET_URL+"leagueId=#{team.league_id}&teamId=#{team.team_id}&scoringPeriodId=#{scoring_period_id}&returnSm=true&trans="+set_lineup_str.chop, postHash)
  
  
  puts 'done posting'

end

def preview_yahoo_default(team)
  #update team in database
  #crumbHash = parse_yahoo_team(team, false, true)
  #Get roster list where position is not bench and dl and empty 
  roster_list = Roster.where(:pos_text.ne=>BENCH_POSITION, :team_type=>team.team_type, :team_id=>team.team_id, :league_id=>team.league_id).all
  player_list = Player.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
  
  player_list = player_assignment_daily(player_list, roster_list)
  
  #try to set assigned players into roster spots that are still empty
  player_list.each do |p|
    set_assigned_player_in_empty_roster(p, roster_list)
  end
  
  player_list  
end

def preview_espn_default(team)
  #update team in database
  #scoring_period_id = parse_espn_team(team, false,true)
  #Get roster list where position is not bench and dl and empty 
  roster_list = Roster.where(:pos_text.ne=>BENCH_POSITION, :team_type=>team.team_type, :team_id=>team.team_id, :league_id=>team.league_id).all
  player_list = Player.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
  
  player_list = player_assignment_daily(player_list, roster_list)
  
  #try to set assigned players into roster spots that are still empty
  player_list.each do |p|
    set_assigned_player_in_empty_roster(p, roster_list)
  end
  
  player_list  
end

def rank_player(player, pos, rank)
  if (player.pos_rank.nil?)
    player.pos_rank = {}
  end

  player.pos_rank[pos] = rank 
  
  player.save
end

def return_color(rank_value, position)
  color = ''
  if (rank_value< 16)
    color = 'Green'
  end
  if (rank_value > 15 && rank_value < 31)
    color = 'Orange'
  end
  if (rank_value > 30)
    color = 'Red'
  end
   
  if((rank_value < 51) && (position == 'P' || position == 'SP' || position == 'RP'))
    color = 'Green'
  end 
  if (rank_value< 51 &&  position == 'OF')
    color = 'Green'
  end
  
   
  if((rank_value > 50 && rank_value < 76) && (position == 'P' || position == 'SP' || position == 'RP'))
    color = 'Orange'
  end 
  if (rank_value > 50 && rank_value < 76 &&  position == 'OF')
    color = 'Orange'
  end
  
   
  if((rank_value > 75) && (position == 'SP' || position == 'RP'))
    color = 'Red'
  end 
  if (rank_value > 75 &&  position == 'OF')
    color = 'Red'
  end

           
  color  
end

def rank_players_by_position()
  
  p_list = PlayerStats.where( :position=>/C/).sort(:rank.asc)
  count = 0
  p_list.each do |player|
    count += 1
    rank_player(player,'C', count)
  end
  
  p_list = PlayerStats.where( :position=>/1B/).sort(:rank.asc)
  count = 0
  p_list.each do |player|
    count += 1
    rank_player(player,'1B', count)
  end
  
  p_list = PlayerStats.where( :position=>/2B/).sort(:rank.asc)
  count = 0
  p_list.each do |player|
    count += 1
    rank_player(player,'2B', count)
  end
  
  p_list = PlayerStats.where( :position=>/3B/).sort(:rank.asc)
  count = 0
  p_list.each do |player|
    count += 1
    rank_player(player,'3B', count)
  end
  
  p_list = PlayerStats.where( :position=>/SS/).sort(:rank.asc)
  count = 0
  p_list.each do |player|
    count += 1
    rank_player(player,'SS', count)
  end
  
  p_list = PlayerStats.where( :position=>/OF/).sort(:rank.asc)
  count = 0
  p_list.each do |player|
    count += 1
    rank_player(player,'OF', count)
  end
  
  p_list = PlayerStats.where( :position=>/UTIL/).sort(:rank.asc)
  count = 0
  p_list.each do |player|
    count += 1
    rank_player(player,'UTIL', count)
  end
  
  p_list = PlayerStats.where( :position=>/SP/).sort(:rank.asc)
  count = 0
  p_list.each do |player|
    if (!player.ip.nil? && player.ip > 3)
      count += 1
      rank_player(player,'SP', count)
    end
  end
  
  p_list = PlayerStats.where( :position=>/RP/).sort(:rank.asc)
  count = 0
  p_list.each do |player|
    count += 1
    rank_player(player,'RP', count)
  end
  
  
  
end

def log_error(email, team, method, message)
  begin
    l = Log.new
    l.email = email
    l.method = method
    l.msg = message
    l.type = 'E'
    if (!team.nil?)
      l.league_id = team.league_id
      l.team_id = team.team_id
    end
    l.save
  rescue => msg
      puts "LOG ERROR Could not write to DB - (#{msg})"
  end
  
end

def parse_player_list(url, player_type)
  rank_count = 0
  100.times do |n|
    count = 0
    url_with_count = url.gsub("###","#{n*25}")
    puts url_with_count
    doc = Hpricot(open_url(url_with_count))
    tbody = (doc/"table.teamtable//tbody").first
    (tbody/"tr").each do |row|
      name_cell = (row/"td//a.name").first
      return if name_cell.nil?
      
      rank_count += 1
      name = name_cell.innerHTML.strip
      split_name = name.split(" ")
      first_name = split_name.first.strip
      
      
        #In case there are multiple spaces in the string we are parsing join them all back together
        if (split_name.length > 2)
          last_name = split_name.last(split_name.length - 1).join(" ").strip 
        else
          last_name = split_name.last.strip
        end
      
      #last_name = split_name.last.strip
      #if(last_name.downcase == 'jr' or last_name.downcase == 'jr.')
      #  last_name = split_name.last(2).join(" ").strip
      #end
      
      short_name = "#{first_name.first(1)} #{last_name}"
      player_url = name_cell[:href].strip
      yahooid = player_url.scan(/http:\/\/sports.yahoo.com\/mlb\/players\/(\d+)/).flatten.compact.first.strip

      detail_cell = (row/"td//div.detail//span").first
      detail_cell_scan = detail_cell.innerHTML.scan(/([a-zA-Z]+) - ([a-zA-Z0-9,]+)/).flatten
      team_short_name = detail_cell_scan[0].upcase.strip
      position = detail_cell_scan[1].upcase.strip
   
      owned_cell = (row/"td")[7]
      percent_owned = owned_cell.innerHTML.gsub('%', '').to_i
      
      player = PlayerStats.find_or_create_by_yahoo_id(yahooid)

      player.full_name = ActiveSupport::Inflector.transliterate(name)  
      player.position = position
      player.yahoo_id = yahooid
      player.team = team_short_name.upcase
      player.owned = percent_owned.to_i
      player.scratched = false
      player.processed = false
      
      if (player_type != 'seven')
        player.rank7 = player.rank6
        player.rank6 = player.rank5
        player.rank5 = player.rank4
        player.rank4 = player.rank3
        player.rank3 = player.rank2
        player.rank2 = player.rank1
        player.rank1 = player.rank
        player.rank = rank_count
        if (player.rank7 != 9999)
        player.rank_change = player.rank7 - player.rank
        end
      end
      
      if (player_type == 'SP' || player_type == 'RP')
        if ((row/"td")[13].innerHTML.strip.to_s.index('-').nil?)
          player.ip = (row/"td")[8].innerHTML.to_f
          player.win = (row/"td")[9].innerHTML.to_i
          player.sv = (row/"td")[10].innerHTML.to_i
          player.k = (row/"td")[11].innerHTML.to_i
          player.era = (row/"td")[12].innerHTML.to_f
          player.whip = (row/"td")[13].innerHTML.to_f
        else
          player.ip = 0
          player.win = 0
          player.sv = 0
          player.k = 0
          player.era = 0
          player.whip = 0
        end 
      end
      
      if (player_type == 'seven' && url == ALL_PITCHERS7_URL)
        if ((row/"td")[13].innerHTML.strip.to_s.index('-').nil?)
          player.ip_7day = (row/"td")[8].innerHTML.to_f
          player.win_7day = (row/"td")[9].innerHTML.to_i
          player.sv_7day = (row/"td")[10].innerHTML.to_i
          player.k_7day = (row/"td")[11].innerHTML.to_i
          player.era_7day = (row/"td")[12].innerHTML.to_f
          player.whip_7day = (row/"td")[13].innerHTML.to_f
          player.rank_7day = rank_count
        else
          player.ip_7day = 0
          player.win_7day = 0
          player.sv_7day = 0
          player.k_7day = 0
          player.era_7day = 0
          player.whip_7day = 0
          player.rank_7day = rank_count
        end 
      end
      
      if(player_type == 'BAT')
        if ((row/"td")[13].innerHTML.strip.to_s.index('-').nil?)
          player.hit = (row/"td")[8].innerHTML.split('/').first.strip
          player.ab = (row/"td")[8].innerHTML.split('/').last.strip
          player.run = (row/"td")[9].innerHTML.to_i
          player.hr = (row/"td")[10].innerHTML.to_i
          player.rbi = (row/"td")[11].innerHTML.to_i
          player.sb = (row/"td")[12].innerHTML.to_i
          player.avg = (row/"td")[13].innerHTML.to_f
        else
          player.hit = 0
          player.ab = 0
          player.run = 0
          player.hr = 0
          player.rbi = 0
          player.sb = 0
          player.avg = 0
        end
        
      end
      
      if(player_type == 'seven' && url == ALL_BATTER7_URL)
        if ((row/"td")[13].innerHTML.strip.to_s.index('-').nil?)
          player.hit_7day = (row/"td")[8].innerHTML.split('/').first.strip
          player.ab_7day = (row/"td")[8].innerHTML.split('/').last.strip
          player.run_7day = (row/"td")[9].innerHTML.to_i
          player.hr_7day = (row/"td")[10].innerHTML.to_i
          player.rbi_7day = (row/"td")[11].innerHTML.to_i
          player.sb_7day = (row/"td")[12].innerHTML.to_i
          player.avg_7day = (row/"td")[13].innerHTML.to_f
          player.rank_7day = rank_count
        else
          player.hit_7day = 0
          player.ab_7day = 0
          player.run_7day = 0
          player.hr_7day = 0
          player.rbi_7day = 0
          player.sb_7day = 0
          player.avg_7day = 0
          player.rank_7day = rank_count
        end
        
      end
      
      #puts player.full_name+"-"+percent_owned.to_s+"-"+player.position+"-"+yahooid+"-"+team_short_name.upcase+"-"+position
      
      player.save

      count = count + 1
    end
    return if count == 0

    sleep rand(10)
  end              
end


def open_url(url, retry_count = 5)
  begin
    sleep rand(2)
    if defined?(PROXY_SERVERS) and PROXY_SERVERS.length > 0
      proxy = PROXY_SERVERS[rand(PROXY_SERVERS.length)]
      puts "Using proxy: #{proxy}"
    else
      proxy = nil
    end
    download_url = url

    Timeout::timeout(10) {
      open(download_url, :proxy => proxy, 'User-Agent' => USER_AGENT, 'Accept' => ACCEPT, 'Accept-Charset' => ACCEPT_CHARSET) { |f|
        raise "Non-200 response." if f.status[0] != '200'
        html = ''
        f.each_line {|line| html << line}
        return html
      } #, 'Accept-Encoding' => ACCEPT_ENCODING, 'Accept-Language' => ACCEPT_LANGUAGE
    }

    #res = Net::HTTP.get_response(URI.parse(download_url))
    #return res.body
  rescue Exception => ee
    puts ee
    retry_count = retry_count - 1
    if(retry_count > 0)
      puts "Download error: trying again..."
      sleep rand(10)
      retry
    else
      raise ee
    end
  end
  

end

