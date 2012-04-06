class UserController < ApplicationController
    
  before_filter :login_required, :only=>['change_password', 'hidden']
  
  def show
    
  end
  
  def index
    if session[:user]
      redirect_to :controller => "teams", :action => "index"
    else
      @user = UserInfo.new 
      render :action => 'signup'
    end
  end
  
  
  def signup
    if request.post?
      @user = UserInfo.new  
      @user.email = params[:email]
      @user.password = params[:pass]
      if(params[:pass]!=params[:repass])
        flash[:message] = "Passwords do not match"
      elsif @user.save
        flash[:message] = "Signup successful"
        session[:user] = @user.email
        redirect_to :controller => "teams", :action => "index"          
      else
        #flash[:message] = "Signup unsuccessful"
      end
    end
  end

  def login
    if request.post?
      if session[:user] = UserInfo.authenticate(params[:email], params[:pass])

        #flash[:message]  = "Login successful"

        redirect_to_stored
      else
        flash[:warning] = "Login unsuccessful for #{params[:email]}"
      end
    end
  end

  def logout
    session[:user] = nil
    flash[:message] = 'Logged out'
    redirect_to :action => 'login'
  end

  
  def change_password
    @user=UserInfo.find_by_email(session[:user])
    if request.post?
      if(params[:pass]!=params[:repass])
        flash[:message] = "Passwords do not match"
      else
        @user.update_attributes(:password=>params[:pass])
        if @user.save
          flash[:message]="Password Changed"
        end
      end
    end
  end



end
