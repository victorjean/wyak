class UserController < ApplicationController
    
  before_filter :login_required, :only=>['change_password', 'hidden']
  layout :user_layout
  def show
    
  end
  

  def index
    if session[:user]
      redirect_to :controller => "teams", :action => "index"
    else
      @user = UserInfo.new 

      render :action => 'home'
    end
  end
  
  
  def signup
    flash[:message] = ""

    if request.post?
      @user = UserInfo.new  
      @user.email = params[:email].downcase
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
    flash[:message] = ""
    if request.post?
      if session[:user] = UserInfo.authenticate(params[:email].downcase, params[:pass])

        #flash[:message]  = "Login successful"

        redirect_to_stored
      else
        flash[:message] = "Login unsuccessful for #{params[:email]}"
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
      flash[:message] = nil
      if(UserInfo.authenticate(session[:user], params[:oldpass]).nil?)
        flash[:message] = "Original password incorrect"
      elsif(params[:pass]!=params[:repass])
        flash[:message] = "Passwords do not match"
      else
        @user.update_attributes(:password=>params[:pass])
        if @user.save
          flash[:message]="Password Successfully Changed"
        end
      end
    end
  end
  
  def forgot_password
    flash[:message] = nil
    @show = true
    if request.post?
      
      @show = false
      if (params[:email] == '')
      @show = true
          flash[:message]="Please enter a email address"
      else
        u= UserInfo.find_by_email(params[:email].downcase)
        if (!u.nil?) 
          u.send_new_password
        else
          @show = true
          flash[:message]  = "Couldn't send password.  Email not found."
        end
        
      end
    end
  end


private
  def user_layout
    session[:user] ? "application" : "home"
  end

end
