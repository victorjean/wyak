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

YAHOO_URL = "http://127.0.0.1:3000/yahoo.htm"

YAHOO_BASEBALL_PAGE_URL = "http://baseball.fantasysports.yahoo.com/b1/"
ESPN_BASEBALL_PAGE_URL = "http://games.espn.go.com/flb/tools/editmyteams"

ESPN_BASEBALL_LEAGUE_URL = "http://games.espn.go.com/flb/clubhouse?pnc=on&seasonId=#{Date.today.year}&leagueId="

YAHOO_LOGIN_URL = "https://login.yahoo.com/config/login"
ESPN_LOGIN_URL = "http://games.espn.go.com/flb/signin"

YAHOO_AUTH_TYPE = 'Y'
ESPN_AUTH_TYPE = 'E'
CBS_AUTH_TYPE = 'C'

ALWAYS_START_OPTION = 'A'
DEFAULT_START_OPTION = 'D'
BENCH_START_OPTION = 'B'
NEVER_START_OPTION = 'N'

BENCH_BATTER_TYPE = 'B'
BENCH_PITCHER_TYPE = 'P'

BENCH_POSITION = 'BN'
ESPN_BENCH_POSITION = 'Bench'

def parse_yahoo_team(team, first_time)
  @rosterHash = {}
  @rosterPlayerHash = {}
  @playerHash = {}
  @dbplayerHash = {}
  @total_players = 0
  
  puts "Parsing yahoo league id - #{team.league_id} for team id - #{team.team_id} team name - #{team.team_name}"
  if (team.team_type != YAHOO_AUTH_TYPE)
    puts 'YAHOO Parser - Incorrect Team Type Passed Into Method'
    return
  end
  
  agent = authenticate_yahoo(team.auth_info)
  puts 'Finished Authentication'
  
  page = agent.get(YAHOO_BASEBALL_PAGE_URL+team.league_id+"/"+team.team_id)
  #page = agent.get(YAHOO_URL)
  
  document = Hpricot(page.parser.to_s)
  
  puts 'Getting Player Position Information'
  #Get Positions from Drop Down
  count = 0
  positionHash = {}
  document.search("td[@class=edit]").each do |item|
    
    count += 1
    posArray = Array.new
    posdropdown = item.search("option")
    
    if (posdropdown.length != 0)
      @total_players+=1
    end
    
    posdropdown.each do |pos|
    #  puts pos.inner_html.strip
      posArray.push(pos.inner_html.strip)
    end
    positionHash[count] = posArray
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
      @roster.slot_number = "0"
      @roster.save
      
      @rosterHash[count] = @roster
    end
    #Create Extra Roster Bench Slots as Place Holders
    extra_bench_number = @total_players - bench_count
    puts "Total Players - #{@total_players}"
    puts "Bench Count - #{bench_count}"
    puts "Create Extra - #{extra_bench_number}"
    begin
      count += 1
      @roster = Roster.new
      @roster.team_type = team.team_type
      @roster.league_id = team.league_id
      @roster.team_id = team.team_id
      @roster.order = count
      @roster.pos_text = BENCH_POSITION
      @roster.pos_type = BENCH_PITCHER_TYPE
      @roster.slot_number = "0"
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
      @player.eligible_pos = positionHash[count]
      @player.position_text = position_elig
      @player.team_name = team_name
      @player.save
      
      @playerHash[yahoo_id] = @player
      @rosterPlayerHash[count] = @player
    end
    
  end  # End Loop through players
  
  #First Time Assign Players to Roster Positions
  if (first_time)
    puts 'First Time Assigning Players to Roster Positions'
    @rosterHash.keys.each do |counter|
      @rosterHash[counter].player = @rosterPlayerHash[counter]
      @rosterHash[counter].save
    end
  else
  
    puts 'Remove Players No Longer on Team From DB'
    @dbplayerHash.keys.each do |yid|
      if (@playerHash[yid].nil?)
        puts 'Deleting - ' + @dbplayerHash[yid].inspect 
        @dbplayerHash[yid].destroy
      end
    end
    
    
    assign_players_bench(team)
    
  
  end #End Else Statement
  
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
    puts 'Assign New Player to Empty Bench Slot'
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
  puts 'Starting Yahoo Authentication...'
  agent = Mechanize.new
  agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
  page = agent.get(YAHOO_LOGIN_URL)
  form = page.form_with(:id => "login_form")
  form['login'] = auth.login
  form['passwd'] = auth.pass
  agent.submit form
  
  agent
end

def authenticate_espn(auth)
  puts 'Starting ESPN Authentication...'
  agent = Mechanize.new
  agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
  page = agent.get(ESPN_LOGIN_URL)
  form = page.form_with(:name => "loginForm")
  form['username'] = auth.login
  form['password'] = auth.pass
  agent.submit form
  
  agent
end

def load_yahoo_first_time(user_info)
  #First Load Yahoo Teams into Database
  load_yahoo_teams(user_info)
  #parse through each team page and store data
  Team.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE).each do |team|
    parse_yahoo_team(team,true)
  end
end

def load_espn_first_time(user_info)
  #First Load ESPN Teams into Database
  load_espn_teams(user_info)
  #parse through each team page and store data
  Team.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE).each do |team|
    parse_espn_team(team,true)
  end
end

def load_yahoo_teams(user_info)
  puts 'Loading all Yahoo Teams into Database for User - '+user_info.email
  puts 'Deleting Teams from DB...'
  team_list = Team.find_all_by_user_info_id_and_team_type(user_info._id, YAHOO_AUTH_TYPE)
  
  team_list.each do |item|
    item.destroy
    puts item.league_id + ' Deleted'
  end

  
  auth_user = AuthInfo.find_by_email_and_auth_type(user_info.email,YAHOO_AUTH_TYPE)
  agent = authenticate_yahoo(auth_user)
  puts 'Finished Authentication'
  
  page = agent.get(YAHOO_BASEBALL_PAGE_URL)
  doc = Hpricot(page.parser.to_s)
  team_list_tag = doc.search("ul[@class=ysf-teamlist]").first
  #If Properly Logged In, User Should have a Team Tag Check for Nil
  if (!team_list_tag.nil?)
    team_list_tag.search("li") do |teamlink|
      #Get Tag Containing Team URL
      team_href_tag = teamlink.search("a[@class=yuimenuitemlabel name]").first
      #Get Tag Containing League ID
      league_href_tag = teamlink.search("a[@class=yuimenuitemlabel]").first
      #Get League and Team ID String
      league_team_ids = team_href_tag.get_attribute("href").strip.gsub(YAHOO_BASEBALL_PAGE_URL,'')
       
      team = Team.new
      team.team_type = YAHOO_AUTH_TYPE
      team.auth_info = auth_user
      team.user_info = user_info
      team.team_name = team_href_tag.inner_html.strip
      team.league_id =  league_team_ids.split('/').first.strip
      team.team_id = league_team_ids.split('/').last.strip
      team.league_name = league_href_tag.inner_html.strip
      team.save
      
      puts 'Team Saved - '+team.inspect
    end
  else
    puts 'No Teams found for the Yahoo User Info Provided'
  end
end

def load_espn_teams(user_info)
  puts 'Loading all ESPN Teams into Database for User - '+user_info.email
  puts 'Deleting Teams from DB...'
  team_list = Team.find_all_by_user_info_id_and_team_type(user_info._id, ESPN_AUTH_TYPE)
  
  team_list.each do |item|
    item.destroy
    puts item.league_id + ' Deleted'
  end

  
  auth_user = AuthInfo.find_by_email_and_auth_type(user_info.email,ESPN_AUTH_TYPE)
  agent = authenticate_espn(auth_user)
  puts 'Finished Authentication'
  
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
      
      team = Team.new
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

def parse_espn_team(team, first_time)
  @slotToPosHash = {}
  @posToSlotHash = {}  
  @rosterHash = {}
  @rosterPlayerHash = {}
  @playerHash = {}
  @dbplayerHash = {}
  
  
  puts "Parsing espn league id - #{team.league_id} for team id - #{team.team_id} team name - #{team.team_name}"
  if (team.team_type != ESPN_AUTH_TYPE)
    puts 'ESPN Parser - Incorrect Team Type Passed Into Method'
    return
  end
  
  agent = authenticate_espn(team.auth_info)
  puts 'Finished Authentication'
  
  page = agent.get(ESPN_BASEBALL_LEAGUE_URL+team.league_id)
  #page = agent.get('http://127.0.0.1:3000/espnempty.htm')
  #page = agent.get('http://127.0.0.1:3000/espn.htm')
  
  document = Hpricot(page.parser.to_s)
  
  #Get Team Hash
  @teamHash = {}
  puts = 'Get Team Hash Table for Player'
  document.search("td[@class=playertablePlayerName]").each do |item|
    player_name = item.search("a").first.inner_html.strip
    @teamHash[player_name] = item.inner_html.split(',')[1].strip[0..2].upcase
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
    extra_bench_number = @total_players - bench_count
    puts "Total Players - #{@total_players}"
    puts "Bench Count - #{bench_count}"
    puts "Create Extra - #{extra_bench_number}"
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
      #puts @rosterHash[counter].slot_number
      @rosterHash[counter].player = get_player_by_roster_slot(@rosterHash[counter].slot_number)
      @rosterHash[counter].save
    end
  else
  
    puts 'Remove Players No Longer on Team From DB'
    @dbplayerHash.keys.each do |yid|
      if (@playerHash[yid].nil?)
        puts 'Deleting - ' + @dbplayerHash[yid].inspect 
        @dbplayerHash[yid].destroy
      end
    end
    
    
    assign_players_bench(team)
    
  
  end #End Else Statement
  
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
