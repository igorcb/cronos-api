# frozen_string_literal: true

Rails.application.routes.draw do
  # get '/tasks', to: 'tasks#index'
  resources :tasks

  get '/softwares', to: 'welcome#softwares'
  get '/companies', to: 'welcome#companies'

  root 'welcome#index'
end
