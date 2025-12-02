# frozen_string_literal: true

require 'simplecov'
require 'notifier'
require 'colorize'
require 'fileutils'

RUN_SPECS = ARGV.include?('spec')
PERCENT_LINES = 80
PERCENT_BRANCHES = 50

SimpleCov.start 'rails' do
  add_filter '/channels/'
  add_filter '/config/'
  add_filter '/spec/'

  add_group 'Controllers', 'app/controllers'
  add_group 'Models', 'app/models'
  add_group 'Jobs', 'app/jobs'
  add_group 'Mailers', 'app/mailers'
  add_group 'Services', 'app/services'

  enable_coverage :branch
  minimum_coverage line: PERCENT_LINES, branch: PERCENT_BRANCHES
end

SimpleCov.at_exit do
  next if RSpec.world.non_example_failure

  if RSpec.world.all_examples.map(&:exception).compact.empty?
    Dir['app/**/*.rb'].each { |f| require File.expand_path(f) }

    load 'line_coverage.rb'
    LineCoverage.compare ARGV
    LineCoverage.local_coverage

    covered_percent = SimpleCov.result.covered_percent
    branch_covered_percent = SimpleCov.result.source_files.branch_covered_percent

    covered_percent_down = covered_percent < PERCENT_LINES
    branch_covered_percent_down = branch_covered_percent < PERCENT_BRANCHES

    cover_down = covered_percent_down || branch_covered_percent_down

    puts "Cobertura total por linhas: #{format('%#.2f', covered_percent)} %".colorize(:white)
    puts "Cobertura total por  ramos: #{format('%#.2f', branch_covered_percent)} %".colorize(:white)

    Notifier.notify(
      image: 'image.png',
      title: 'Bateria de testes',
      message: 'Os testes termiram de rodar!',
      color: '#764FA5',
    )

    SimpleCov.result.format!
    begin
      FileUtils.chmod_R(0o755, SimpleCov.coverage_path)
    rescue StandardError
      # ignore permission errors
    end

    if cover_down
      puts 'COVERAGE TESTE DOWN'.colorize(:red)
      exit(1)
    else
      puts 'COVERAGE TOTAL OK'.colorize(:green)
    end
  end
end

def require_covered_files
  Dir['app/**/*.rb'].each { |f| require File.expand_path(f) }
end
