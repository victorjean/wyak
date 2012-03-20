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

def parse_yahoo_team(team, first_time)
  @rosterHash = {}
  @rosterPlayerHash = {}
  @playerHash = {}
  @dbplayerHash = {}
  @emptyBenchHash = {}
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
    
     puts 'Get Empty Bench Slot List'
    count = 0
    Roster.all(:pos_text=>BENCH_POSITION).each do |bench|
      if (bench.player.nil?)
        count += 1
        @emptyBenchHash[count] = bench
      end
    end
    puts 'Assign New Player to Empty Bench Slot'
    count = 0
    @rosterPlayerHash.keys.each do |counter|
      if (@rosterPlayerHash[counter].roster_id.nil?)
        count += 1
        @emptyBenchHash[count].player = @rosterPlayerHash[counter]
        @emptyBenchHash[count].save
      end
    end
  
  end #End Else Statement
  
  
  
end

def authenticate_yahoo(auth)
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

