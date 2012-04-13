require "fantasy_team_helper"

class ProcessController < ApplicationController
  def players
    @success = true
    
    render(:partial => 'loading')
    
  end
  
  def yahoostart
    @success = true
    
    render(:partial => 'loading')
  end
  
  def espnstart
    @success = true
        
    render(:partial => 'loading')
  end

end
