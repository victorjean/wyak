require "rubygems"
require "hpricot"
require "open-uri"
require "date"
require 'timeout'



SCOREBOARD_URL = "http://sports.yahoo.com/mlb/scoreboard?d="
BOX_URL = "http://sports.yahoo.com/mlb/boxscore?gid="


def store_game(gid)
        #skip parse if game is in DB
        
        gamerecord = Game.find_by_game_id(gid)
        if (gamerecord.nil?)
          begin
            puts 'Storing PPD Game - '+gid
            gamerecord = Game.new
            gamerecord.game_id = gid
            gamerecord.save
            
            player_list = PlayerStats.where(:team => gid).all
  
            player_list.each do |player|
              #puts "#{player.full_name} - #{player.team}"
              player.processed = true
              player.scratched = true
              player.save
            end
            
          rescue => msg
            puts "ERROR OCCURED Saving PPD - (#{msg})"
            log_error('realtime_parser_ppd', nil,gid,msg)
          end
        else
            puts 'Game ID Found Skipping - '+gid
        end
  
end


def parse_days_scoreboard(score_date)
  
  curr_date = Date.today
  
  if(score_date!='')
    puts "parsing scoreboard for date - "+score_date
    doc = Hpricot(open_url(SCOREBOARD_URL+score_date))
  else
    puts "parsing scoreboard for date - "+curr_date.strftime('%Y-%m-%d')
    doc = Hpricot(open_url(SCOREBOARD_URL+curr_date.strftime('%Y-%m-%d')))
  end
  
    doc.search("a[@class=yspmore]").each do |item|
      if (item.inner_html == 'Box Score')      
        gid = item[:href].split("=").last
        
        #skip parse if game is in DB
        
        gamerecord = Game.find_by_game_id(gid)
        if (gamerecord.nil?)
          begin
            puts 'Parsing Game ID - '+gid
            gamerecord = Game.new
            gamerecord.game_id = gid
            
            parse_box(gid)
            gamerecord.save
            
            
          rescue => msg
            puts "ERROR OCCURED Parsing Box for Scratches - (#{msg})"
            log_error('realtime_parser', nil,gid,msg)
          end
        else
            puts 'Game ID Found Skipping - '+gid
        end
              
      end  # Close If Box Score
    end # Close Loop
    
  #Get PPD Games
  ppd_found = false
  doc.search("tr[@class=ysptblclbg5]").each do |item|
    
    teamrow = item.search("a").first
    team_name = teamrow[:href].gsub('/mlb/teams/','').strip.upcase
    team_name = change_team_text(team_name)
    
    if (ppd_found)
      puts "Processing PPD #{team_name}"
      store_game(team_name)
      ppd_found = false  
    end
    
    if (!item.search("span").first.nil?)
      status = item.search("span").first.inner_html.strip
      if (status == 'Ppd.')
        #Process Team PPD
        puts "Processing PPD #{team_name}"
        store_game(team_name)
        ppd_found = true
      end
    end
  end
  
end

def parse_box(gid)
  puts BOX_URL+gid
  doc = Hpricot(open_url(BOX_URL+gid))

  #Get the Game Date and Game ID
  return if doc.search("div[@class=ysp-dynamic]").first.nil?
  date_string = doc.search("div[@class=ysp-dynamic]").first[:id]
  split_date = date_string.split(":")
  game_date = split_date[2].strip
  game_id = split_date.last.split("_").first.strip

  puts 'game date - '+game_date
  puts 'after gameid - '+game_id
  
  #If Status is not Found Exit Function
  if (doc.search("td[@class=yspscores]").first.nil?)
    puts 'game status not found - boxscore may not be well formed for parsing - exiting'
    return
  end
  
  #Get Status of Game and Could be different in game

  game_status = doc.search("td[@class=yspscores]").first.innerHTML.strip
  
  puts 'game status - '+game_status  
  
  
  #Get Teams Playing in Box Score
  teamShortNameHash = {}
  team_list = []
  doc.search("td[@class=yspsctnhdln]/a").each do |teamrow|
    #puts teamrow.inner_html.strip
    teamShortNameHash[teamrow.inner_html.strip] = teamrow[:href].gsub('/mlb/teams/','').strip.upcase
    #team_name_box = teamrow[:href].gsub('/mlb/teams/','').strip.upcase
    team_name_box = change_team_text(teamrow[:href].gsub('/mlb/teams/','').strip.upcase)
    team_list.push(team_name_box)
    
    puts teamrow.inner_html.strip + teamShortNameHash[teamrow.inner_html.strip]
    
  end
  puts 'after teams boxscore'
  
  
  if teamShortNameHash.keys.length == 0
    puts 'no team names found - all star game - stop parse of boxscore'
    return
  end
  
  if (team_list.length != 2)
    puts 'no team names found - stop parse of boxscore'
    return
  end
  
  #Get All Players from Teams in Box from Database PlayerStats
  player_hash = {}
  player_list = PlayerStats.where(:$or => [{:team => team_list[0]},{:team => team_list[1]}]).all
  
  player_list.each do |player|
    #puts "#{player.full_name} - #{player.team}"
    player.processed = true
    player.scratched = true
    player_hash[player.yahoo_id] = player
  end
  
  puts 'starting players intial load'
  doc.search("tr.ysprow1 | tr.ysprow2").each do |boxtable|
       count = 1
      (boxtable/"td").each do |col|
        if (count == 1)
          playerlink = (col/"a")
          player_id = playerlink.first[:href].split("/").last.strip
          #puts "#{playerlink.inner_html.strip}|#{player_id}"
          if (!player_hash[player_id].nil?)
            player_hash[player_id].scratched = false
          end
        end
        count = count + 1
      end # end player loop through TD in row
  end #end loop through all player rows
  
  player_list.each do |player|
    player.save
  end

end  #method end

def change_team_text(team_text)
  return_text = team_text
  if (team_text == 'CHW')
    return_text = 'CWS'
  elsif(team_text == 'KAN')
    return_text = 'KC'
  elsif(team_text == 'SDG')
    return_text = 'SD'
  elsif(team_text == 'SFO')
    return_text = 'SF'
  elsif(team_text == 'TAM')
    return_text = 'TB'
  else
    return_text = team_text
  end
  return_text
end

def parse_espn_team_realtime(team, clear)
  slotToPosHash = {}
  posToSlotHash = {}  
  
  playerHash = {}
  dbplayerHash = {}
  
  statusHash = {}
  gameTimeHash = {}  
  assignPosHash={}
  
  puts "Real Time Parsing espn league id - #{team.league_id} for team id - #{team.team_id} team name - #{team.team_name}"
  if (team.team_type != ESPN_AUTH_TYPE)
    puts 'ESPN Parser - Incorrect Team Type Passed Into Method'
    return
  end
  
  agent = authenticate_espn(team.auth_info)
  
  
  page = agent.get(ESPN_BASEBALL_LEAGUE_URL+team.league_id)
  
  
  document = Hpricot(page.parser.to_s)
  
  #get scoring period id to post espn lineup
  
  currentScoringPeriodId = '1'
  scoringPeriodTag = document.search("input[@name=scoringPeriodId]")
  if(!scoringPeriodTag.first.nil?)
    currentScoringPeriodId = scoringPeriodTag.first.get_attribute("value").strip
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
    pos_cell = item.search("td")[0].inner_html
    name_cell = item.search("a").first
    opp_cell = item.search("td")[4].search("a").first
    double_opp_cell = item.search("td")[4].search("a")[1]
    status_cell = item.search("td")[5].search("a").first
    
    
    
    if (!name_cell.nil?)
      assignPosHash[name_cell.innerHTML.strip] = (pos_cell=='Bench')?'BN':pos_cell
      if (opp_cell.nil?)
        statusHash[name_cell.innerHTML.strip] = ''
      else
        if (double_opp_cell.nil?)
          statusHash[name_cell.innerHTML.strip] = opp_cell.innerHTML.strip
        else
          statusHash[name_cell.innerHTML.strip] = opp_cell.innerHTML.strip+","+opp_cell.innerHTML.strip
        end
      end
      
      if (!status_cell.nil?)
        gameTimeHash[name_cell.innerHTML.strip] = (status_cell.inner_html.index('AM').nil? && status_cell.inner_html.index('PM').nil?)
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
          
          if (posText == ESPN_BENCH_POSITION)
            posText = BENCH_POSITION
            bench_count += 1          
          end
        end
      end
      
      slotToPosHash[slotId] = posText
      posToSlotHash[posText] = slotId
      parsed_roster_list.push(posText)
      
      
    end #End Abbrev Roster Block
    
  end # End Roster Loop
  
  
  
  
  #If not first_time store player list in DB
    puts 'Getting Current Player List from DB...'
    player_db_list = PlayerRealtime.find_all_by_team_id(team._id )
    player_db_list.each do |item|
      dbplayerHash[item.espn_id] = item
      
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
        textPosArray.push(slotToPosHash[id.strip])
        if (slotToPosHash[id.strip]!='UTIL'&&slotToPosHash[id.strip]!='BN'&&slotToPosHash[id.strip]!='DL')
          pos_text = pos_text + slotToPosHash[id.strip] + ','
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
      player_save = PlayerRealtime.find_or_create_by_espn_id_and_team_id(espn_id, team._id)
      
      player_save.team = team
      player_save.espn_id = espn_id
      player_save.full_name = full_name
      player_save.current_slot = curr_slot 
      player_save.eligible_slot = slotPosArray
      #player_save.eligible_pos = textPosArray
      player_save.assign_slot = curr_slot
      player_save.assign_pos = assignPosHash[full_name]
      player_save.position_text = pos_text
  
      if (playerInLineupHash[full_name])
      player_save.game_status = "^"+statusHash[full_name]
      else
      player_save.game_status = statusHash[full_name]
      end
      player_save.player_set = gameTimeHash[full_name]
      player_save.game_today = (statusHash[full_name] != '' )
      player_save.on_dl = playerDLHash[full_name]
      
      plyr_stats = PlayerStats.find_by_espn_id(espn_id)
      if (!plyr_stats.nil?)
        player_save.player_stats = plyr_stats
      else
        plyr_stats = PlayerStats.find_by_full_name(full_name)
        if (!plyr_stats.nil?)
          player_save.player_stats = plyr_stats
          plyr_stats.espn_id = espn_id
          plyr_stats.save
        end
      end
      
      plyr_info = Player.find_by_espn_id_and_league_id_and_team_id(espn_id, team.league_id, team.team_id)
      if (plyr_info.nil?)
        player_save.player = nil
      else
        player_save.player = plyr_info
      end
      
      if (clear)
        player_save.scratched = false
      end
      
      player_save.save
      
      playerHash[espn_id] = player_save
      
    end
  end #End Player Loop
  
    
    #If Roster Player Hash Empty or No Players, then don't delete
    #May be a authentication error
    if (playerHash.length != 0)
    
      puts 'Remove Players No Longer on Team From DB'
      dbplayerHash.keys.each do |yid|
        if (playerHash[yid].nil?)
          puts 'Deleting - ' + dbplayerHash[yid].inspect 
          dbplayerHash[yid].destroy
        end
      end
    end
 
  
  currentScoringPeriodId
end #method end

def parse_yahoo_team_realtime(team, clear)
  
  
  playerHash = {}
  dbplayerHash = {}
  currentRosterAssignHash = {}  
  
  puts "Parsing yahoo league id - #{team.league_id} for team id - #{team.team_id} team name - #{team.team_name}"
  if (team.team_type != YAHOO_AUTH_TYPE)
    puts 'YAHOO Parser - Incorrect Team Type Passed Into Method'
    return
  end
  
  agent = authenticate_yahoo(team.auth_info)
 
  
  page = agent.get(YAHOO_BASEBALL_PAGE_URL+team.league_id+"/"+team.team_id)
  #page = agent.get(YAHOO_BASEBALL_PAGE_URL+team.league_id+"/"+team.team_id+"?date=2012-04-20")
  
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
      currentRosterAssignHash[count] = pos_data
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
  gameStartedHash = {}
  document.search("td[@class=edit]").each do |item|
    
    count += 1
    posArray = Array.new
    posdropdown = item.search("option")
    posinput = item.search("input")
    #check in case roster spot is empty need to validate drop down or input in edit td
    if (posinput.length != 0)
      gameStartedHash[count] = true
    else
      gameStartedHash[count] = false
    end
    
    posdropdown.each do |pos|
    #  puts pos.inner_html.strip
      posArray.push(pos.inner_html.strip)
    end
    positionHash[count] = posArray
  end
  
  
  #If not first_time store player list in DB

    puts 'Getting Current Player List from DB...'
    
    player_db_list = PlayerRealtime.find_all_by_team_id(team._id )
    player_db_list.each do |item|
      dbplayerHash[item.yahoo_id] = item
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
      player_save = PlayerRealtime.find_or_create_by_yahoo_id_and_team_id(yahoo_id, team._id)
      player_save.team = team
      player_save.position_text = position_elig    
      player_save.yahoo_id = yahoo_id
      player_save.full_name = full_name
      if(!positionHash[count].nil? && positionHash[count].length != 0)
      #player_save.eligible_pos = positionHash[count]
      player_save.eligible_slot = positionHash[count]
      end
      
      player_save.assign_pos = currentRosterAssignHash[count]
      player_save.assign_slot = currentRosterAssignHash[count]
      player_save.current_slot = currentRosterAssignHash[count]
      player_save.game_status = statusHash[count]
      player_save.game_today = (statusHash[count] != '' )
      player_save.player_set = gameStartedHash[count]
      
      
      if (!player_save.game_today)
        player_save.player_set = true
      end
      
      plyr_stats = PlayerStats.find_by_yahoo_id(yahoo_id)
      if (!plyr_stats.nil?)
        player_save.player_stats = plyr_stats
      end
            
      #Check if DL Status is Marked next to Player
      if (!statustag.nil? && statustag.inner_html.strip == DL_POSITION)
        player_save.on_dl = true
      else
        player_save.on_dl = false  
      end
      
      plyr_info = Player.find_by_yahoo_id_and_league_id_and_team_id(yahoo_id, team.league_id, team.team_id)
      if (plyr_info.nil?)
        player_save.player = nil
      else
        player_save.player = plyr_info
      end
      
      if (clear)
        player_save.scratched = false
      end
      
      player_save.save     
      
      playerHash[yahoo_id] = player_save
      
    end
    
  end  # End Loop through players
  
    #If Roster Player Hash Empty or No Players, then don't delete
    #May be a authentication error
    if (playerHash.length != 0)  
      puts 'Remove Players No Longer on Team From DB'
      dbplayerHash.keys.each do |yid|
        if (playerHash[yid].nil?)
          puts 'Deleting - ' + dbplayerHash[yid].inspect 
          dbplayerHash[yid].destroy
        end
      end
    end
    
  
  #Return Crumb Info to Set Lineup
  crumbHash
  
end  #method end

def set_espn_scratch(team)
  #update team in database
  scoring_period_id = parse_espn_team_realtime(team,false)
  #Get roster list where position is not bench and dl and empty 
  
  player_list = PlayerRealtime.find_all_by_team_id(team._id )
  player_list = player_assignment_scratch(player_list)
  
  set_espn_lineup(team, player_list, scoring_period_id,true)
  log_error('sys', team, 'scratch','lineup espn set success')  
end

def set_yahoo_scratch(team)
  #update team in database
  scoring_period_id = parse_yahoo_team_realtime(team,false)
  #Get roster list where position is not bench and dl and empty 
  
  player_list = PlayerRealtime.find_all_by_team_id(team._id )
  player_list = player_assignment_scratch(player_list)
  
  set_yahoo_lineup(team, player_list, scoring_period_id,false, true)
  log_error('sys', team, 'scratch','lineup yahoo set success')  
end

def player_assignment_scratch(player_list)
    
    avail_players = []
    scratch_players = {}
    eligible_players = {}
    
    #For Sorting By Priority Set to 100 if player is not found
    player_list.each do |item|
      if (item.player.nil?)
        item.player = Player.new
        item.player.priority = 100
      end
    end
    
    #Sort Players By Priority
    player_list = player_list.sort_by{|x| [x.player.priority]}
    
    # Get List of Position Scratched To Be Filled
    # If Double Header, Don't Mark as Scratched
    player_list.each do |item|
      
      if (item.game_status.index(',').nil? && item.position_text.index('P').nil? && !item.player_set && item.scratched && item.assign_pos != BENCH_POSITION && item.assign_pos != DL_POSITION)
        eligible_players[item.current_slot] = []
        if (scratch_players[item.current_slot].nil?)
          scratch_players[item.current_slot] = []
          scratch_players[item.current_slot].push(item)
        else
          scratch_players[item.current_slot].push(item)  
        end
        
        puts "#{item.full_name} #{item.assign_pos} #{item.player.priority} "
      end
    end
    
    #Get List of Available Players on Bench 
    #That are not locked, on bench, not DL, has game today, not scratched
    player_list.each do |item|
      if (item.position_text.index('P').nil? && !item.player_set && item.assign_pos == BENCH_POSITION && !item.on_dl && item.game_today && !item.scratched)
        avail_players.push(item)
      end
    end
    
    #attempt to shuffle roster to start top bench guys first
    not_all_zero = true
    begin
      not_all_zero = find_player_in_lineup_for_scratch(eligible_players,scratch_players,avail_players,player_list)
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
        
        not_all_zero = assign_player_scratch(eligible_players,scratch_players,avail_players)
      end while not_all_zero
    
    
    
    
    
    player_list    
end


def find_player_in_lineup_for_scratch(elig_hash,scratch_players,avail_players,player_list)
    avail_players.each do |avail|
      avail.eligible_slot.each do |slot|
        if (slot!=BENCH_POSITION && slot!=ESPN_BENCH_SLOT)
          player_list.each do |p|
            if (p.assign_slot==slot && !p.scratched && !p.player_set && p.assign_pos!=BENCH_POSITION && p.assign_pos!=ESPN_BENCH_SLOT)
              #Check to See if Player Can fill Any Position in Elig Hash
              elig_hash.keys.each do |key|
                if (key!=ESPN_UTIL_SLOT && key!=YAHOO_UTIL_SLOT && !p.eligible_slot.index(key).nil?)
                  puts "#{avail.full_name} replace #{p.full_name} at #{p.assign_pos}"
                  puts "#{p.full_name} goes to scratch position - #{key}"
                  log_error('sys', nil, 'scratchalgorithm',"#{avail.full_name} replace #{p.full_name} at #{p.assign_pos}")
                  log_error('sys', nil, 'scratchalgorithm',"#{p.full_name} goes to scratch position - #{key}")
                  
                  
                  avail.assign_pos = p.assign_slot
                  avail.assign_slot = p.assign_slot
                  p.assign_pos = key
                  p.assign_slot = key
                  plyr = scratch_players[key].pop
                  plyr.assign_pos = BENCH_POSITION
                  plyr.assign_slot = ESPN_BENCH_SLOT
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

def assign_player_scratch(elig_hash,scratch_players,avail_players)
    elig_hash.keys.each do |key|
      if(elig_hash[key].length==1)
        puts "assign player #{elig_hash[key].first.full_name} to #{key}"
        log_error('sys', nil, 'scratchalgorithm',"assign player #{elig_hash[key].first.full_name} to #{key}")
        
        plyr = scratch_players[key].pop
        plyr.assign_pos = BENCH_POSITION
        plyr.assign_slot = ESPN_BENCH_SLOT
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
        log_error('sys', nil, 'scratchalgorithm',"assign player #{elig_hash[key].first.full_name} to #{key}")
        
        plyr = scratch_players[key].pop
        plyr.assign_pos = BENCH_POSITION
        plyr.assign_slot = ESPN_BENCH_SLOT
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