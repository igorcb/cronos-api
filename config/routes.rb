# frozen_string_literal: true

Rails.application.routes.draw do
  # Defines the root path route ("/")
  get '/softwares', to: 'welcome#softwares'
  get '/companies', to: 'welcome#companies'

  root 'welcome#index'
end
