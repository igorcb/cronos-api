class LineCoverage
  def self.local_coverage
    SimpleCov.result.files.map.to_h do |file|
      [
        file.filename.gsub(SimpleCov.root, '.'),
        {
          covered_lines: covered_lines = file.covered_percent,
          covered_branches: covered_branchs = file.branches_coverage_percent,
          covered: [covered_lines, covered_branchs].min,
          lines_without_coverage: file.missed_lines.map(&:line_number),
          no_coverage: (
            file.missed_lines.map { |line| { tipo: :linha, linha: line.line_number } } +
            file.missed_branches.map { |branch| { tipo: branch.type, linha: branch.start_line } }
          ).sort_by { |no| no[:linha] },
        },
      ]
    end.to_h
  end

  def self.compare(argv)
    files_filter =
      local_coverage.select do |file, _|
        file_meets_filter(argv, file)
      end

    if files_filter.none?
      warn
      <<~MSG.strip.light_yellow
        Cobertura não pode ser exibida.
        Nenhum arquivo de produção compativel com o filtro dos testes:
          #{argv.join('\n  ')}
      MSG
      return
    end

    down_filtereds =
      files_filter.select do |_, info|
        info[:covered] < 100
      end

    runing_all_test = ARGV.empty?
    local_coverage_ok = down_filtereds.all? { |_file, info| info[:covered_lines] == 100 }

    return if runing_all_test && local_coverage_ok

    warn 'Falta fazer cobertura nos seguintes arquivos:' if down_filtereds.any?
    down_filtereds.each do |file, info|
      per_lines_less_than_hundred = info[:covered_lines] < 100
      per_branches_less_than_hundred = info[:covered_branches] < 100
      # puts 'Cobertura Branches: #{per_branches_less_than_hundred}'
      per_lines_ok = !per_lines_less_than_hundred

      next if runing_all_test && per_lines_ok

      color = per_lines_less_than_hundred ? :red : :cyan
      coverage_line = per_lines_less_than_hundred ? info[:covered_lines] : 0.0
      coverage_branch = per_branches_less_than_hundred ? info[:covered_branches] : 0.0

      warn [
        file.ljust(40, ' '),
        'per_line:',
        format('%#.2f', coverage_line),
        '< 100',
        ' | ',
        'per_branch:',
        format('%#.2f', coverage_branch),
        '< 100',
      ].join(' ').colorize(color)

      last_line_reported = 0
      info[:no_coverage].each do |info_line|
        next if info_line[:linha] == last_line_reported

        if info_line[:tipo] == :linha
          warn "#{file}:#{info_line[:linha]}".red
        else
          warn "#{file}:#{info_line[:linha]} #{info_line[:tipo]}".cyan
        end
        last_line_reported = info_line[:linha]
      end
    end
  end

  def self.file_meets_filter(argv, file)
    argv.empty? || file_matches_filter(argv, file)
  end

  def self.file_matches_filter(filters, file)
    modify_filters =
      filters.map do |filter|
        filter.gsub(%r{(.*spec/)}, '').gsub(/_spec.rb/, '')
      end

    modify_filters.any? do |modify_filter|
      file.include?(modify_filter)
    end
  end
end
