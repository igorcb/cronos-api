# frozen_string_literal: true

Rails.application.routes.draw do
  # Defines the root path route ("/")
  get '/companies', to: 'welcome#companies'

  root 'welcome#index'
end
