class WelcomeController < ApplicationController
  def index
    render json: { message: 'Server is running!!!' }, status: :ok
  end
end
