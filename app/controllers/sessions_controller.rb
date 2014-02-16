class SessionsController < ApplicationController

  skip_before_filter :redirect_to_login, only: [:new, :create]

  def new
    redirect_to '/welcome' if current_user
  end

  def create
    user = User.find_by_email(params[:email])
    if user && user.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to welcome_path, notice: 'Logged in'
    else
      flash.now[:alert] = 'Invalid email or password.'
      render :new
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: 'Logged out'
  end
end
