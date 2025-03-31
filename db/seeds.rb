# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

company = Company.create(name: 'NobeSistemas', value: 50)

softwares = %w[
  Almoxarifado
  Compras
  Contabilidade
  Dockers
  Educação
  Folha
  Frotas
  Patrimonio
  Pregao-eletronico
  Protocolo
  Saude
  Tributario
  NotaFiscal
]

softwares.each do |software|
  company.softwares.create(name: software)
end
