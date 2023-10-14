# frozen_string_literal: true

class WelcomeController < ApplicationController
  def index
    render json: { message: 'Server is running!!!' }, status: :ok
  end

  def companies
    @compaines = Company.order(:name)
    render json: @compaines.to_json, status: :ok
  end

  def softwares
    @softwares = Software.includes(:company).order('companies.name, softwares.name')
    render json: @softwares.to_json, status: :ok
  end

  def softwares_by_company_id
    @company = Company.find_by(id: params[:company_id])
    @softwares = @company.softwares.includes(:company).order('companies.name, softwares.name')
    render json: @softwares.to_json, status: :ok
  end
end
