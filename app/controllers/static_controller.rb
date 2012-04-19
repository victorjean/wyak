class StaticController < ApplicationController
  
  def privacy
    
  end

  def terms
    
  end
  
  def contact
    
  end
  
  def howitworks
    @logged = false
    if session[:user]
      
      @logged = true
    end
      @user = UserInfo.new
  end

 end
