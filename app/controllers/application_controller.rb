# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Desativa a verificação de CSRF para todas as requisições
  # Útil quando um frontend externo (React/Vite) consome a API via CORS
  # Atenção: isso remove a proteção contra requisições forjadas (CSRF) baseadas em cookies
  skip_before_action :verify_authenticity_token, raise: false
end
