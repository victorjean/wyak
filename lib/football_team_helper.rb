#require "fantasy_team_helper"
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

ESPN_FOOTBALL_PAGE_URL = "http://games.espn.go.com/ffl/tools/editmyteams"
ESPN_FOOTBALL_LEAGUE_URL = "http://games.espn.go.com/ffl/clubhouse?pnc=on&seasonId=#{Date.today.year}&leagueId="
ESPN_FOOTBALL_LINEUP_SET_URL = "http://games.espn.go.com/ffl/pnc/saveRoster?"

YAHOO_FOOTBALL_PAGE_URL = "http://football.fantasysports.yahoo.com/f1/"

YAHOO_OFFENSE_SEASON_FOOTBALL_URL = "http://football.fantasysports.yahoo.com/f1/560932/players?status=ALL&pos=O&cut_type=9&stat1=S_S_***&myteam=0&sort=AR&sdir=1&count=###"
YAHOO_KICKER_SEASON_FOOTBALL_URL = "http://football.fantasysports.yahoo.com/f1/560932/players?status=ALL&pos=K&cut_type=9&stat1=S_S_***&myteam=0&sort=AR&sdir=1&count=###"
YAHOO_DEFENSE_SEASON_FOOTBALL_URL = "http://football.fantasysports.yahoo.com/f1/560932/players?status=ALL&pos=DEF&cut_type=9&stat1=S_S_***&myteam=0&sort=AR&sdir=1&count=###"
YAHOO_DEF_PLAYER_SEASON_FOOTBALL_URL = "http://football.fantasysports.yahoo.com/f1/200/players?status=A&pos=DP&cut_type=9&stat1=S_S_***&myteam=0&sort=AR&sdir=1&count=###"


NA_TAG = 'NA'
BENCH_POSITION = 'BN'
ESPN_BENCH_POSITION = 'Bench'
ESPN_BENCH_SLOT_FOOTBALL = '20'
ESPN_IR_SLOT = '21'
IR_POSITION = 'IR'
ESPN_FLEX_SLOT = '23'
ESPN_RBWR_SLOT = '3'
ESPN_FLEX_POS = 'FLEX'

PLAYER_TYPE_FOOTBALL = 'F'


def load_yahoo_football_teams(user_info, reload)
  auth_user = AuthInfo.find_by_email_and_auth_type(user_info.email,YAHOO_AUTH_TYPE)
  if (auth_user.nil?)
    return
  end
  
  agent = authenticate_yahoo(auth_user)
  
  puts 'Loading all Yahoo Teams into Database for User - '+user_info.email
  team_list = FootballTeam.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE)
  
  if (reload)    
    puts 'Deleting Teams from DB...'
      
    team_list.each do |item|
      #Delete Real Time Player Info      
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
  
  page = agent.get(YAHOO_FOOTBALL_PAGE_URL)
  doc = Hpricot(page.parser.to_s)
  team_list_tag = doc.search("ul[@class=ysf-teamlist]").first
  #If Properly Logged In, User Should have a Team Tag Check for Nil
  if (!team_list_tag.nil?)
    doc.search("ul[@class=ysf-teamlist]") do |fantasy_team_tag|
    
      fantasy_team_tag.search("li") do |teamlink|
            
        #Get Tag Containing Team URL
        team_href_tag = teamlink.search("a[@class=yuimenuitemlabel name]").first
        if (!team_href_tag.get_attribute("href").index(YAHOO_FOOTBALL_PAGE_URL).nil?)
          #Get Tag Containing League ID
          league_href_tag = teamlink.search("a[@class=yuimenuitemlabel]").first
          #Get League and Team ID String
          league_team_ids = team_href_tag.get_attribute("href").strip.gsub(YAHOO_FOOTBALL_PAGE_URL,'')
           
          #team = Team.new
          team = FootballTeam.find_or_create_by_league_id_and_team_id_and_team_type(league_team_ids.split('/').first.strip,league_team_ids.split('/').last.strip,YAHOO_AUTH_TYPE)
          team.team_type = YAHOO_AUTH_TYPE
          team.auth_info = auth_user
          team.user_info = user_info
          team.team_name = team_href_tag.inner_html.strip.gsub("&amp;","&")
          team.league_id =  league_team_ids.split('/').first.strip
          team.team_id = league_team_ids.split('/').last.strip
          team.league_name = league_href_tag.inner_html.strip.gsub("&amp;","&")
          team.save
          
          puts 'Team Saved - '+team.inspect
        end# end baseball check
      end #end loop through teams
      
    end #Outer Team List Loop
  else
    puts 'No Teams found for the Yahoo User Info Provided'
  end
end

def load_espn_football_teams(user_info, reload)
  auth_user = AuthInfo.find_by_email_and_auth_type(user_info.email,ESPN_AUTH_TYPE)
  if (auth_user.nil?)
    return
  end
  
  agent = authenticate_espn(auth_user)
  
  puts 'Loading all FOOTBALL ESPN Teams into Database for User - '+user_info.email
  team_list = FootballTeam.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE)
  
  if (reload)
    puts 'Deleting Teams from DB...'
      
    team_list.each do |item|      
      item.destroy
      puts item.league_id + ' Deleted'
    end
  end

  
  page = agent.get(ESPN_FOOTBALL_PAGE_URL)
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
      page = agent.get(ESPN_FOOTBALL_LEAGUE_URL + league_id)
      puts page.uri
      if (page.uri.to_s.index('error').nil?)
        #Get TeamId and LeagueId
        url_str = page.uri.to_s.split('?').last.split('&')
        league_id = url_str.first.split('=').last.strip
        team_id = url_str.last.split('=').last.strip
        
        
      else
        league_id = league_id.chop
        puts 'trying second URL with league_id - '+ league_id
        page = agent.get(ESPN_FOOTBALL_LEAGUE_URL + league_id)
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
      team = FootballTeam.find_or_create_by_league_id_and_team_id_and_team_type(league_id,team_id,ESPN_AUTH_TYPE)
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

def load_yahoo_football_first_time(user_info)
  #First Load Yahoo Teams into Database
  load_yahoo_football_teams(user_info,true)
  #parse through each team page and store data
  FootballTeam.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE).each do |team|
    parse_yahoo_football_team(team,true)
  end
end

def load_espn_football_first_time(user_info)
  #First Load ESPN Teams into Database
  load_espn_football_teams(user_info,true)
  #parse through each team page and store data
  FootballTeam.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE).each do |team|
    parse_espn_football_team(team,true)
  end
end

def parse_espn_football_team(team, first_time)
  @slotToPosHash = {}
  @posToSlotHash = {}  
  @rosterHash = {}
  @rosterPlayerHash = {}
  @playerHash = {}
  @dbplayerHash = {}
  teamHash = {}
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
  
  
  page = agent.get(ESPN_FOOTBALL_LEAGUE_URL+team.league_id)
  #page = agent.get("http://games.espn.go.com/ffl/clubhouse?leagueId=856806&teamId=4&seasonId=2012&scoringPeriodId=5")

  
  document = Hpricot(page.parser.to_s)
  
  #get scoring period id to post espn lineup
  scoringPeriodTag = document.search("input[@name=scoringPeriodId]")
  if(!scoringPeriodTag.first.nil?)
    currentScoringPeriodId = scoringPeriodTag.first.get_attribute("value").strip
  end
  
  
  #Get Team Hash
  
  playerNameHash = {}
  playerInLineupHash = {}
  playerDLHash = {}
  posTextHash = {}
  priorityHash = {}
  count = 0
  puts 'Get Team Hash Table for Players'
  document.search("td[@class=playertablePlayerName]").each do |item|
    count += 1
    player_name = item.search("a").first.inner_html.strip
    playerNameHash[count] = player_name
    priorityHash[player_name] = count
    
    #Get Team Name for Player
    if (item.inner_html.split(',')[1].nil?)
      teamHash[player_name] = ''
      posTextHash[player_name] = ''
    else
      teamHash[player_name] = item.inner_html.split(',')[1].strip[0..2].upcase.gsub(/\u00A0/,"")
      posTextHash[player_name] = item.inner_html.split(',')[1].split(/\u00A0/)[1].strip[0..1]
    end    
    
  end
  
  
  proj_hash = {}
  gameTimeHash = {}
  puts 'Get Game Status for Players'
  count = 0
  (document/"tr.pncPlayerRow").each do |item|
    count +=1
    name_cell = item.search("a").first
    opp_cell = item.search("td")[4].search("a").first
    proj_cell = item.search("td[@class=playertableStat appliedPoints]").last
    status_cell = item.search("td")[5].search("a").first
    
    if (!name_cell.nil?)
      if (opp_cell.nil?)
        @statusHash[name_cell.innerHTML.strip] = ''
      else
        @statusHash[name_cell.innerHTML.strip] = opp_cell.innerHTML.strip
      end
      #puts name_cell.innerHTML.strip + '-' + @statusHash[name_cell.innerHTML.strip]
      if (proj_cell.nil?)
        proj_hash[name_cell.innerHTML.strip] = 0
      else
        proj_hash[name_cell.innerHTML.strip] = proj_cell.innerHTML.strip
      end
      
      if (!status_cell.nil?)        
        gameTimeHash[name_cell.innerHTML.strip] = (status_cell[:href].index('preview').nil?)
      else 
        gameTimeHash[name_cell.innerHTML.strip] = true
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
          puts posText
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
  
  @total_players = @statusHash.keys.length
  
  
  #Delete and Store Roster Data If first_time is TRUE
  if (first_time)
    puts 'Deleting and Storing Roster Information for Team...'
    
    count = 0
    roster_list = FootballRoster.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
    roster_list.each do |item|
      item.destroy
      count += 1
    end
    puts "Items Deleted - #{count}"    
    count = 0
    
    player_type = 'F'
    
    parsed_roster_list.each do |position|
      
      #Save Position Data
      count += 1
            
      @roster = FootballRoster.new
      @roster.team_type = team.team_type
      @roster.league_id = team.league_id
      @roster.team_id = team.team_id
      @roster.order = count
      @roster.pos_text = position
      @roster.pos_type = PLAYER_TYPE_FOOTBALL
      @roster.slot_number = @posToSlotHash[position]
      #puts @roster.inspect
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
      @roster = FootballRoster.new
      @roster.team_type = team.team_type
      @roster.league_id = team.league_id
      @roster.team_id = team.team_id
      @roster.order = count
      @roster.pos_text = BENCH_POSITION
      @roster.pos_type = PLAYER_TYPE_FOOTBALL
      @roster.slot_number = @posToSlotHash[BENCH_POSITION]
      @roster.save
      @rosterHash[count] = @roster
      extra_bench_number -= 1
    end while extra_bench_number > 0
  
  end #End Storing Roster Block if first_time
  
  
  
  #If not first_time store player list in DB
  if (!first_time)
    puts 'Getting Current Player List from DB...'
    player_db_list = FootballPlayer.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
    player_db_list.each do |item|
      @dbplayerHash[item.espn_id] = item
    end
  else
    puts 'Reload Players - Delete All From Database for Team'
    player_db_list = FootballPlayer.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
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
      @player = FootballPlayer.find_or_create_by_espn_id_and_league_id_and_team_id(espn_id, team.league_id, team.team_id)
      
      @player.team_type = team.team_type
      @player.league_id = team.league_id
      @player.team_id = team.team_id
      @player.espn_id = espn_id
      @player.full_name = full_name
      @player.current_slot = curr_slot 
      @player.eligible_slot = slotPosArray
      @player.eligible_pos = textPosArray

      @player.team_name = teamHash[full_name]      
      @player.game_status = @statusHash[full_name]
      @player.game_today = (@statusHash[full_name] != '' )
      @player.proj_points = proj_hash[full_name]      
      @player.player_set = gameTimeHash[full_name]
      @player.football_team = team
      
      #If First time prioritize based on starting lineup
      if (first_time)
        @player.priority = priorityHash[full_name]   
      end
      
      if posTextHash[full_name] == ''
        @player.position_text = pos_text
      else
        @player.position_text =  posTextHash[full_name].gsub("<","")
      end
      
           
      
      
      #TODO:  IR
      #@player.on_dl = playerDLHash[full_name]
      
      
      
      plyr_stats = FootballPlayerStats.find_by_espn_id(espn_id)
      if (!plyr_stats.nil?)        
        @player.football_player_stats = plyr_stats
      else        
        plyr_stats = FootballPlayerStats.find_by_full_name_and_team(full_name,@player.team_name)
        
        if (!plyr_stats.nil?)
          @player.football_player_stats = plyr_stats
          plyr_stats.espn_id = espn_id
          plyr_stats.save
        end
      end
      
      if (@player.current_slot == ESPN_IR_SLOT)
        @player.football_roster_id = nil
        @player.on_dl = true  
      end
      
      @player.save
      #puts @player.inspect
      
      @playerHash[espn_id] = @player
      @rosterPlayerHash[count] = @player
    end
  end #End Player Loop
  
  
  #First Time Assign Players to Roster Positions
  if (first_time)
    puts 'First Time Assigning Players to Roster Positions'
    @rosterHash.keys.each do |counter|
      if (@rosterHash[counter].slot_number != ESPN_IR_SLOT)
      
      @rosterHash[counter].football_player = get_player_by_roster_slot(@rosterHash[counter].slot_number)
      @rosterHash[counter].save
      end
      #if (@rosterHash[counter].slot_number == ESPN_UTIL_SLOT)
      #  @rosterHash[counter].save
      #end
    end
    assign_football_players_bench(team)
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
      assign_football_players(team)
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

def parse_yahoo_football_team(team, first_time)
  @rosterHash = {}
  @rosterPlayerHash = {}
  @playerHash = {}
  @dbplayerHash = {}
  @currentRosterAssignHash = {}
  @total_players = 0
  
  #If Team empty reload entire team set first_time true
  if (team.empty_team.nil? || team.empty_team) 
    first_time = true
  end
    
  puts "Loading team Data First Time = #{first_time}"
  puts "Parsing yahoo league id - #{team.league_id} for team id - #{team.team_id} team name - #{team.team_name}"
  if (team.team_type != YAHOO_AUTH_TYPE)
    puts 'YAHOO Parser - Incorrect Team Type Passed Into Method'
    return
  end
  
  agent = authenticate_yahoo(team.auth_info)
  
  
  #puts YAHOO_FOOTBALL_PAGE_URL+team.league_id+"/"+team.team_id+"/team?stat1=P&ssort=W"
  page = agent.get(YAHOO_FOOTBALL_PAGE_URL+team.league_id+"/"+team.team_id+"/team?stat1=P&ssort=W")
  #page = agent.get('http://football.fantasysports.yahoo.com/f1/388110/10?week=5')
 
  
  document = Hpricot(page.parser.to_s)
  
  #Get Crumb and Ret Type Information Used for Setting Lineup
  crumbHash = {}
  crumb_value = document.search("input[@name=crumb]").first.get_attribute("value").strip
  week_value = document.search("input[@name=week]").first.get_attribute("value").strip
    
  ret_mode = 'classic'
 
  dnd_status_div = document.search("div[@id=dnd-status]").first
  
  if (dnd_status_div.nil?)
    team.empty_team = true
    team.save
    return 
  end
  
  radio_dnd = dnd_status_div.search("input").first
  radio_classic = dnd_status_div.search("input").last
  if (!radio_dnd.to_s.index('checked').nil? )
    ret_mode = 'dnd'
  end
  if (!radio_classic.to_s.index('checked').nil? )
    ret_mode = 'classic'
  end
  
  
  crumbHash['crumb_value']=crumb_value
  crumbHash['ret_mode']=ret_mode
  crumbHash['week']=week_value
 
  
  puts 'Get Current Roster Assigned Hash'
  count = 0
  document.search("td[@class=pos first]").each do |position|
      #Save Position Data
      count += 1
      pos_data = position.inner_html.strip
      @currentRosterAssignHash[count] = pos_data
      #puts @currentRosterAssignHash[count]
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
    #puts statusHash[count]
  end
  
  puts 'Getting Week Proj Point'
  #Get Positions from Drop Down
  count = 0
  projHash = {}
  document.search("td[@class=pts last]").each do |item|
    count+=1
    projHash[count] = item.inner_text.strip
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
  
  
  #Delete and Store Roster Data If first_time is TRUE
  if (first_time)
    puts 'Deleting and Storing Roster Information for Team...'
    
    count = 0
    roster_list = FootballRoster.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
    roster_list.each do |item|
      item.destroy
      count += 1
    end
    puts "Items Deleted - #{count}"
    
    count = 0
    bench_count = 0
    player_type = PLAYER_TYPE_FOOTBALL
    document.search("td[@class=pos first]").each do |position|
      
      #Save Position Data
      count += 1
      pos_data = position.inner_html.strip
      
      #Increment Counter if BN Position
      if(pos_data == BENCH_POSITION)
        bench_count += 1
      end
            
      @roster = FootballRoster.new
      @roster.team_type = team.team_type
      @roster.league_id = team.league_id
      @roster.team_id = team.team_id
      @roster.order = count
      @roster.pos_text = pos_data
      @roster.pos_type = player_type
      @roster.slot_number = pos_data
      @roster.save!
      
      @rosterHash[count] = @roster
    end
    #Create Extra Roster Bench Slots as Place Holders
    extra_bench_number = @total_players - bench_count + 4
    puts "Total Players - #{@total_players}"
    puts "Bench Count - #{bench_count}"
    puts "Create Extra + 4BN - #{extra_bench_number}"
    begin
      count += 1
      @roster = FootballRoster.new
      @roster.team_type = team.team_type
      @roster.league_id = team.league_id
      @roster.team_id = team.team_id
      @roster.order = count
      @roster.pos_text = BENCH_POSITION
      @roster.pos_type = PLAYER_TYPE_FOOTBALL
      @roster.slot_number = BENCH_POSITION
      @roster.save!
      extra_bench_number -= 1
    end while extra_bench_number > 0
  
  end #End Storing Roster Block if first_time
  
  
  #If not first_time store player list in DB
  if (!first_time)
    puts 'Getting Current Player List from DB...'
    player_db_list = FootballPlayer.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
    player_db_list.each do |item|
      @dbplayerHash[item.yahoo_id] = item
    end
  else
    puts 'Reload Players - Delete All From Database for Team'
    player_db_list = FootballPlayer.find_all_by_league_id_and_team_id_and_team_type(team.league_id,team.team_id,team.team_type )
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
      @player = FootballPlayer.find_or_create_by_yahoo_id_and_league_id_and_team_id(yahoo_id, team.league_id, team.team_id)
      @player.team_type = team.team_type
      @player.league_id = team.league_id
      @player.team_id = team.team_id
      @player.yahoo_id = yahoo_id
      @player.full_name = full_name
      if(!positionHash[count].nil? && positionHash[count].length != 0)
      @player.eligible_pos = positionHash[count]
      @player.eligible_slot = positionHash[count]
      @player.player_set = false
      else
        @player.player_set = true
      end
      @player.position_text = position_elig
      @player.team_name = team_name
      @player.current_slot = @currentRosterAssignHash[count]
      @player.game_status = statusHash[count]
      @player.game_today = (statusHash[count] != 'Bye' )
      @player.proj_points = projHash[count]
      @player.football_team = team
      
      plyr_stats = FootballPlayerStats.find_by_yahoo_id(yahoo_id)
      if (!plyr_stats.nil?)
        @player.football_player_stats = plyr_stats
      end
      
      if (@player.current_slot == IR_POSITION)
        @player.football_roster_id = nil  
      end
      
      #If First time prioritize based on starting lineup
      if (first_time)
        @player.priority = count  
      end
      
      #Check if DL Status is Marked next to Player
      if (!statustag.nil? && statustag.inner_html.strip == IR_POSITION)
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
      if(@rosterHash[counter].pos_text != IR_POSITION )
      @rosterHash[counter].football_player = @rosterPlayerHash[counter]
      @rosterHash[counter].save
      end
      #if (@rosterHash[counter].pos_text == YAHOO_UTIL_SLOT)
      #  @rosterHash[counter].save
      #end
    end
    
    assign_football_players_bench(team)
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
      assign_football_players(team)
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

def load_yahoo_football_first_time(user_info)
  #First Load Yahoo Teams into Database
  load_yahoo_football_teams(user_info, true)
  #parse through each team page and store data
  FootballTeam.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE).each do |team|
    parse_yahoo_football_team(team, true)
  end
end

def load_espn_football_first_time(user_info)
  #First Load ESPN Teams into Database
  load_espn_football_teams(user_info, true)
  #parse through each team page and store data
  FootballTeam.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE).each do |team|
    parse_espn_football_team(team, true)
  end
end

def set_yahoo_football_lineup(team,player_list,crumbHash)
  agent = authenticate_yahoo(team.auth_info)
  
  curr_date = Date.today
  
  
  postHash = {}

  #puts crumbHash['ret_mode']
  puts crumbHash['crumb_value']
  puts crumbHash['week']
     
  postHash['ret'] = crumbHash['ret_mode']
  postHash['crumb'] = crumbHash['crumb_value']
  postHash['week'] = crumbHash['week']
  postHash['stat1'] = 'S'
  postHash['stat2'] = 'W'
  postHash['jsubmit'] = ''
  
 
  
    player_list.each do |item|
      #ignore any player in DL position
      if (item.current_slot == IR_POSITION)
        postHash[item.yahoo_id] = IR_POSITION      
      else
        postHash[item.yahoo_id] = item.assign_pos
        #puts "#{item.yahoo_id} - #{item.assign_pos}"
        
      end 
    end
    
  
  page = agent.post(YAHOO_FOOTBALL_PAGE_URL+"#{team.league_id}/#{team.team_id}/editroster",postHash)
  puts 'done posting'
end

def set_espn_football_lineup(team,player_list,scoring_period_id)
  
  agent = authenticate_espn(team.auth_info)
  
  
  set_lineup_str = ''
  postHash = {}
  
  player_list.each do |item|
    
    if (item.current_slot != ESPN_IR_SLOT && item.assign_slot != item.current_slot)
            
        set_lineup_str = set_lineup_str + "1_#{item.espn_id}_#{item.current_slot}_#{item.assign_slot}|"      
      
    end
  end
  #puts set_lineup_str.chop
  puts ESPN_FOOTBALL_LINEUP_SET_URL+"leagueId=#{team.league_id}&teamId=#{team.team_id}&scoringPeriodId=#{scoring_period_id}&returnSm=true&trans="+set_lineup_str.chop
  
  agent.post(ESPN_FOOTBALL_LINEUP_SET_URL+"leagueId=#{team.league_id}&teamId=#{team.team_id}&scoringPeriodId=#{scoring_period_id}&returnSm=true&trans="+set_lineup_str.chop, postHash)
  #http://games.espn.go.com/ffl/pnc/saveRoster?leagueId=193126&teamId=7&scoringPeriodId=1&returnSm=true&trans=1_13271_20_4|1_13934_4_20

  
  puts 'done posting'

end

def set_yahoo_inactive(team)
  #update team in database
  scoring_period_id = parse_yahoo_football_team(team,false)
  #Get roster list where position is not bench and dl and empty 
  
  player_list = FootballPlayer.where(:team_type=>team.team_type, :team_id=>team.team_id, :league_id=>team.league_id).all
  
 
  player_list = football_player_assignment_inactive(player_list,team.start_type)
  
  set_yahoo_football_lineup(team, player_list, scoring_period_id)
    
end

def set_espn_inactive(team)
  #update team in database
  scoring_period_id = parse_espn_football_team(team,false)
  #Get roster list where position is not bench and dl and empty 
  
  player_list = FootballPlayer.where(:team_type=>team.team_type, :team_id=>team.team_id, :league_id=>team.league_id).all
 
 
  player_list = football_player_assignment_inactive(player_list,team.start_type)
  
  set_espn_football_lineup(team, player_list, scoring_period_id)
    
end



def assign_football_players(team)
  
  roster_list = FootballRoster.all(:league_id=>team.league_id, :team_id=>team.team_id,:team_type=>team.team_type )
  roster_list.each do |rosterspot|
    rosterspot.football_player = nil  
  end
  
  @rosterPlayerHash.keys.each do |counter|
    @rosterPlayerHash[counter].football_roster_id = nil
    i = 0
    begin
    if (roster_list[i].slot_number == @rosterPlayerHash[counter].current_slot && roster_list[i].football_player.nil?)
      roster_list[i].football_player = @rosterPlayerHash[counter]
      roster_list[i].save
    end
    i += 1
    end while @rosterPlayerHash[counter].football_roster_id.nil?   
  end
   
end

def assign_football_players_bench(team)
    
    benchHash = {}
    puts 'Get Empty Bench Slot List'
    count = 0
    FootballRoster.all(:pos_text=>BENCH_POSITION, :league_id=>team.league_id, :team_id=>team.team_id,:team_type=>team.team_type ).each do |bench|
      if (bench.football_player.nil?)
        count += 1
        benchHash[count] = bench
      end
    end
    puts 'Assign New Player or DL to Empty Bench Slot'
    count = 0
    @rosterPlayerHash.keys.each do |counter|
      if (@rosterPlayerHash[counter].football_roster_id.nil?)
        count += 1
        benchHash[count].football_player = @rosterPlayerHash[counter]
        benchHash[count].save
      end
    end
end

def parse_inactive_page()
  
  week = get_week()
  puts "http://www.nfl.com/inactives?week=#{week.to_s}"
  doc = Hpricot(open_url("http://www.nfl.com/inactives?week=#{week.to_s}"))  
  
  current_team = ''
  doc.search("table[@class=data-table1]") do |teamtable|
    teamtable.search("tr") do |row|
      if (!row[:class].nil?)
        if (!row[:class].strip.index("colors").nil?)
          current_team = row.search("b").first.innerHTML          
        end
        
        #Player Row
        if (!row[:class].strip.index("tbdy1").nil?)
          if (!row.search("a").first.nil?)
            player_name = row.search("a").first.innerHTML.strip
            inactive_bool = (!row.innerHTML.strip.index("Inactive").nil?)
            
            #puts player_name +'-'+current_team+'-'+inactive_bool.to_s
            player = FootballInactive.find_or_create_by_full_name_and_team_and_week(player_name,current_team,week)
            player.inactive = inactive_bool
            player.save
            
          end          
        end
        
      end
    end
  end
  
end

def get_week(date=Time.now)
    #set to Tuesday 3am EST, assumption of when games for prev week is over
    first_tuesday = DateTime.new(2012,9,11,8)
    if date <= first_tuesday
      return 1
    else
      week = 2
      football_tues = first_tuesday + 7
      while date > football_tues && week <= 17
        football_tues += 7
        week += 1
      end
      return week
    end
end

def parse_football_player_list(url, player_type)
  year = Time.now.year
  
  rank_count = 0
  1000.times do |n|
    count = 0
    url_with_count = url.gsub("###","#{n*25}")
    url_with_count = url_with_count.gsub("***","#{year}")
    puts url_with_count
    doc = Hpricot(open_url(url_with_count))
    #doc = Hpricot(open_url('http://127.0.0.1:3000/football.html'))
    tbody = (doc/"table.teamtable//tbody").first
    (tbody/"tr").each do |row|
      name_cell = (row/"td//a.name").first
      return if name_cell.nil?
      
      rank_count += 1
      name = name_cell.innerHTML.strip
       
     
      player_url = name_cell[:href].strip
      
      #For Team Defense
      if (player_url.index('teams').nil?)     
        yahooid = player_url.scan(/http:\/\/sports.yahoo.com\/nfl\/players\/(\d+)/).flatten.compact.first.strip
      else
        yahooid = player_url.scan(/http:\/\/sports.yahoo.com\/nfl\/teams\/(\w+)/).flatten.compact.first.strip
      end
      

      detail_cell = (row/"td//div.detail//span").first
      detail_cell_scan = detail_cell.innerHTML.scan(/([a-zA-Z]+) - ([a-zA-Z0-9,]+)/).flatten
      team_short_name = detail_cell_scan[0].upcase.strip
      position = detail_cell_scan[1].upcase.strip
    
      owned_cell = (row/"td")[7]
      percent_owned = owned_cell.innerHTML.gsub('%', '').to_i
      
      player = FootballPlayerStats.find_or_create_by_yahoo_id(yahooid)

      player.full_name = ActiveSupport::Inflector.transliterate(name)  
      player.position = position
      player.yahoo_id = yahooid
      player.team = team_short_name.upcase
      player.owned = percent_owned.to_i
      player.scratched = false
      player.processed = false
      
      
        player.rank3 = player.rank2
        player.rank2 = player.rank1
        player.rank1 = player.rank
        player.rank = rank_count
        if (player.rank3 != 9999)
        player.rank_change3 = player.rank3 - player.rank
        end
        if (player.rank2 != 9999)
        player.rank_change2 = player.rank2 - player.rank
        end
        if (player.rank1 != 9999)
        player.rank_change1 = player.rank1 - player.rank
        end
     
     if (player_type == 'OFF')
       if ((row/"td")[6].innerHTML.strip.to_s.index('-').nil?)
         
        
        player.pass_yds = (row/"td")[8].innerHTML.to_i        
        player.pass_td = (row/"td")[9].innerHTML.to_i
        player.intercept = (row/"td")[10].innerHTML.to_i
        player.rush_yds = (row/"td")[12].innerHTML.to_i
        player.rush_td = (row/"td")[13].innerHTML.to_i
        player.rec = (row/"td")[15].innerHTML.to_i
        player.rec_yds = (row/"td")[16].innerHTML.to_i
        player.rec_td = (row/"td")[17].innerHTML.to_i
        player.ret_td = (row/"td")[19].innerHTML.to_i
        player.two_point = (row/"td")[20].innerHTML.to_i
        player.fumble = (row/"td")[21].innerHTML.to_i
        
       end
     end
     if (player_type == 'DEF')
       if ((row/"td")[6].innerHTML.strip.to_s.index('-').nil?)
         
        
        player.pts_allow = (row/"td")[8].innerHTML.to_i        
        player.sack = (row/"td")[9].innerHTML.to_i
        player.safe = (row/"td")[10].innerHTML.to_i
        player.def_int = (row/"td")[12].innerHTML.to_i
        player.def_fumble = (row/"td")[13].innerHTML.to_i
        player.def_td = (row/"td")[14].innerHTML.to_i
        player.block_kick = (row/"td")[15].innerHTML.to_i
        player.def_ret_td = (row/"td")[16].innerHTML.to_i
        
       end
     end
     if (player_type == 'KICK')
       if ((row/"td")[6].innerHTML.strip.to_s.index('-').nil?)
         
        
        player.fg10 = (row/"td")[8].innerHTML.to_i        
        player.fg20 = (row/"td")[9].innerHTML.to_i
        player.fg30 = (row/"td")[10].innerHTML.to_i
        player.fg40 = (row/"td")[11].innerHTML.to_i
        player.fg50 = (row/"td")[12].innerHTML.to_i
        player.pat = (row/"td")[15].innerHTML.to_i
        
       end
     end  
     
      
     puts player.full_name+"-"+percent_owned.to_s+"-"+player.position+"-"+yahooid+"-"+team_short_name.upcase
     player.save

      count = count + 1
    end
    return if count == 0

    sleep rand(10)
  end              
end

def football_player_assignment_inactive(player_list, start_type)
    
    avail_players = []
    scratch_players = {}
    eligible_players = {}
    
    
    #Sort Players By Priority
    if (start_type=='projected')
      player_list = player_list.sort_by{|x| [x.proj_points]}.reverse!
    else
      player_list = player_list.sort_by{|x| [x.priority]}
    end
    
    
    # Get List of Position Scratched To Be Filled
    # If Double Header, Don't Mark as Scratched
    player_list.each do |item|
      
      if (!item.player_set && (item.scratched || !item.game_today) && item.assign_pos != BENCH_POSITION && item.assign_pos != IR_POSITION)
        eligible_players[item.current_slot] = []
        if (scratch_players[item.current_slot].nil?)
          scratch_players[item.current_slot] = []
          scratch_players[item.current_slot].push(item)
        else
          scratch_players[item.current_slot].push(item)  
        end
        
        puts "#{item.full_name} #{item.assign_pos} #{item.priority} "
        
        # Bench Inactive Players
        item.assign_pos = BENCH_POSITION
        item.assign_slot = ESPN_BENCH_SLOT_FOOTBALL 
        item.player_set = true
      end
    end
    
     if (start_type=='bench')
       return player_list
     end
    
    #Get List of Available Players on Bench 
    #That are not locked, on bench, not DL, has game today, not scratched
    player_list.each do |item|
      if (!item.player_set && item.assign_pos == BENCH_POSITION && !item.on_dl && item.game_today && !item.scratched)
        avail_players.push(item)
      end
    end
    
    #attempt to shuffle roster to start top bench guys first
    not_all_zero = true
    begin
      not_all_zero = find_football_player_in_lineup_for_scratch(eligible_players,scratch_players,avail_players,player_list)
    end while not_all_zero
    
    puts 'Left Over Slots Not Filled'
    eligible_players.keys.each do |key|
      puts key
    end
    
     #loop through open roster spots until all spot are filled
      not_all_zero = true
      begin
        #clear roster slots of playera
        eligible_players.keys.each do |key|
          eligible_players[key] = []
        end
        
        #Assign Eligible players to Eligible Hash for Each Position
        scratch_players.keys.each do |key|
          avail_players.each do |p|
            if (!p.eligible_slot.index(key).nil?)
              eligible_players[key].push(p)
            end
          end
        end
        
        not_all_zero = assign_football_player_scratch(eligible_players,scratch_players,avail_players)
      end while not_all_zero
    
    
    
    
    
    player_list    
end

def find_football_player_in_lineup_for_scratch(elig_hash,scratch_players,avail_players,player_list)
    avail_players.each do |avail|
      avail.eligible_slot.each do |slot|
        if (slot!=BENCH_POSITION && slot!=ESPN_BENCH_SLOT_FOOTBALL)
          player_list.each do |p|
            if (p.assign_slot==slot && !p.scratched && !p.player_set && p.assign_pos!=BENCH_POSITION && p.assign_pos!=ESPN_BENCH_SLOT_FOOTBALL)
              #Check to See if Player Can fill Any Position in Elig Hash
              elig_hash.keys.each do |key|
                if (key!=ESPN_RBWR_SLOT && key!=ESPN_FLEX_SLOT && key!='W/R/T' && key!='W/R' && !p.eligible_slot.index(key).nil?)
                  puts "#{avail.full_name} replace #{p.full_name} at #{p.assign_pos}"
                  puts "#{p.full_name} goes to scratch position - #{key}"
                  log_info('sys', nil, 'scratchalgorithm',"#{avail.full_name} replace #{p.full_name} at #{p.assign_pos}")
                  log_info('sys', nil, 'scratchalgorithm',"#{p.full_name} goes to scratch position - #{key}")
                  
                  
                  avail.assign_pos = p.assign_slot
                  avail.assign_slot = p.assign_slot
                  p.assign_pos = key
                  p.assign_slot = key
                  plyr = scratch_players[key].pop
                  plyr.assign_pos = BENCH_POSITION
                  plyr.assign_slot = ESPN_BENCH_SLOT_FOOTBALL
                  plyr.player_set = true
                  
                  avail_players.delete(avail)
                  if (scratch_players[key].length == 0)
                  scratch_players.delete(key)
                  elig_hash.delete(key)
                  end
                  
                  
                  return true  
                end
              end 
            end
          end
        end
      end
    end 
    false
end

def assign_football_player_scratch(elig_hash,scratch_players,avail_players)
    elig_hash.keys.each do |key|
      if(elig_hash[key].length==1)
        puts "assign player #{elig_hash[key].first.full_name} to #{key}"
        log_info('sys', nil, 'scratchalgorithm',"assign player #{elig_hash[key].first.full_name} to #{key}")
        
        plyr = scratch_players[key].pop
        plyr.assign_pos = BENCH_POSITION
        plyr.assign_slot = ESPN_BENCH_SLOT_FOOTBALL
        plyr.player_set = true
        elig_hash[key].first.assign_pos = key
        elig_hash[key].first.assign_slot = key
        
        avail_players.delete(elig_hash[key].first)
        if (scratch_players[key].length == 0)
          scratch_players.delete(key)
          elig_hash.delete(key)
        end
        
        return true
      end
    end
    
    elig_hash.keys.each do |key|
      if(elig_hash[key].length>1)
        puts "assign player #{elig_hash[key].first.full_name} to #{key}"
        log_info('sys', nil, 'scratchalgorithm',"assign player #{elig_hash[key].first.full_name} to #{key}")
        
        plyr = scratch_players[key].pop
        plyr.assign_pos = BENCH_POSITION
        plyr.assign_slot = ESPN_BENCH_SLOT_FOOTBALL
        plyr.player_set = true
        elig_hash[key].first.assign_pos = key
        elig_hash[key].first.assign_slot = key
        
        avail_players.delete(elig_hash[key].first)
        if (scratch_players[key].length == 0)
          scratch_players.delete(key)
          elig_hash.delete(key)
        end
        
        return true

      end
    end
  
    false  
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

def mcat_check
  puts 'Starting MCAT Authentication...'
    agent = Mechanize.new
    agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
      login_url = "https://services.aamc.org/20/mcat/user/validate"
      
      nysite_am_url = "https://services.aamc.org/20/mcat/findSite/reschedule?date=300128&search_type=state&search_state=NY"
      nysite_pm_url = "https://services.aamc.org/20/mcat/findSite/reschedule?date=300129&search_type=state&search_state=NY"
      
      nysite_july = "https://services.aamc.org/20/mcat/findSite/reschedule?date=300130&search_type=state&search_state=NY"
      
      test_good_url = "https://services.aamc.org/20/mcat/findSite/reschedule?date=300128&search_type=state&search_state=NM"
    
    page = agent.get(login_url)
    form = page.form_with(:name => "login")
    form['username'] = 'krhee1029'
    form['password'] = 'kat35kat'
    page = agent.submit form
    puts 'Finished Authentication Post'
   
    #puts page.uri.to_s    
    
    #page = agent.get(test_good_url)
    
    #2pm June20th
    page = agent.get(nysite_pm_url)    
    document = Hpricot(page.parser.to_s)        
    found = document.search("td[@class=chart_cell_header_x]")
    puts found.length
    if (found.length == 0)
      puts 'Testing Site Not Available'      
    else
      puts 'Testing Site Available'
        
      Notifications.em_found('sys', 'mcat', 'June 20th 2pm', sites).deliver
    end
    puts page.uri.to_s  
    
    #10am June20th    
    page = agent.get(nysite_am_url)
    document = Hpricot(page.parser.to_s)        
    found = document.search("td[@class=chart_cell_header_x]")
    puts found.length
    if (found.length == 0)
      puts 'Testing Site Not Available'      
    else
      puts 'Testing Site Available'
      sites = document.search("td[@class=chart_cell_header_y]")
      Notifications.em_found('sys', 'mcat', 'June 20th 8am', sites).deliver
    end
    puts page.uri.to_s      
    
    #July 2nd
    page = agent.get(nysite_july)
    document = Hpricot(page.parser.to_s)        
    found = document.search("td[@class=chart_cell_header_x]")
    puts found.length
    if (found.length == 0)
      puts 'Testing Site Not Available'      
    else
      puts 'Testing Site Available'
      
      just_poughkeep = true
      sites = document.search("td[@class=chart_cell_header_y]")
      
      sites.each do |key|
        if (key.to_plain_text.index('POUGHKEEPSIE').nil?)
          just_poughkeep = false
        end
      end
      
      if (!just_poughkeep)
        puts 'Sending Email'
        Notifications.em_found('sys', 'mcat', 'July 13th 1pm', sites).deliver
      end
    end
    puts page.uri.to_s      

end


