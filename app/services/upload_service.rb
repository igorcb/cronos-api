require 'roo'

class UploadService
  def initialize(file_path, upload_id)
    @file_path = file_path
    @upload_id = upload_id
  end

  def call
    begin
      find_update.update(status: :processing, success_count: 0, error_count: 0, total_lines: 0)
    rescue StandardError => e
      Rails.logger.error "Falha ao iniciar upload ##{@upload_id}: #{e.message}"
    end

    excel = Roo::Excelx.new(@file_path)
    count_lines = 0
    excel.each_row_streaming(offset: 1) do |row|
      preferred = safe_cell(row, 10)
      preferred_has_code_name =
        preferred.present? &&
        (preferred.include?(':') || preferred.include?('-')) &&
        !preferred.match?(/^\d{1,2}:\d{2}$/)
      code_name = preferred_has_code_name ? preferred : find_code_name(row)
      next if code_name.blank?

      @day_week = safe_cell(row, 0)

      m = code_name.match(/^\s*(\d+)\s*[:\-–—]\s*(.+)$/)
      if m
        @code = m[1].to_s.strip
        @name = m[2].to_s.strip
      else
        parts = code_name.split(':', 2)
        @code = parts[0].to_s.strip
        @name = parts[1].to_s.strip
      end

      ensure_company
      @company_id = Company.where('name ilike ?', 'nobesistemas').first&.id
      raw_software = safe_cell(row, 7)
      @software_id = find_software_id(raw_software) || find_software_id(find_software_cell(row))
      ensure_software(raw_software.presence || find_software_cell(row)) if @software_id.nil? && @company_id.present?

      parsed_date = parse_date(safe_cell(row, 1)) || parse_date(find_date_cell(row))
      @date_opened = parsed_date
      @date_start = parsed_date

      @hour_start = normalize_hour(safe_cell(row, 2))
      @hour_end = normalize_hour(safe_cell(row, 3))
      if @hour_start.blank? || @hour_end.blank?
        hs, he = find_hours(row)
        @hour_start = @hour_start.presence || hs.to_s.strip
        @hour_end = @hour_end.presence || he.to_s.strip
      end
      @date_end = parsed_date
      @status = status_parse(safe_cell(row, 8)) || status_parse(find_status_cell(row))

      @task = Task.where(company_id: @company_id, software_id: @software_id, code: @code).first
      processed_ok = false
      begin
        processed_ok =
          if @task.present?
            task_item_create
          else
            create_task_and_task_item
          end
      rescue StandardError => e
        Rails.logger.error "Erro ao processar linha (code=#{@code}): #{e.message}"
        increment_error(e.message)
        update_total_lines(count_lines)
        next
      end

      if processed_ok
        increment_success
        count_lines += 1
      end
      update_total_lines(count_lines)
    end

    find_update.update(status: :completed, total_lines: count_lines)
  rescue StandardError => e
    find_update.update(status: :failed, error_messages: e.message)
  end

  private

  def task_item_create
    if @task && @task.persisted?
      # continue
    else
      return false
    end

    if @status.to_s.strip.empty?
      return false
    else
      # continue
    end

    if @hour_start.to_s.strip.empty?
      return false
    else
      # continue
    end

    begin
      exists = TaskItem.exists?(
        task_id: @task.id,
        date_start: @date_start,
        hour_start: @hour_start,
        hour_end: @hour_end,
        status: @status,
      )
      if exists
        @task.update_status
        return true
      end
    rescue StandardError => e
      Rails.logger.error "Erro ao verificar TaskItem existente: #{e.message}"
    end

    created = @task.task_items.create(
      date_start: @date_start,
      hour_start: @hour_start,
      date_end: @date_end,
      hour_end: @hour_end,
      status: @status,
    )
    created.persisted?
  end

  def create_task_and_task_item
    if @company_id.nil? || @software_id.nil? || @code.to_s.strip.empty?
      Rails.logger.error "Linha ignorada: empresa/software ausente ou code vazio (code=#{@code})"
      increment_error('Linha ignorada por dados inválidos')
      return false
    end

    status_task =
      case @status
      when 'finalized' then :finalized
      when 'pending' then :opened
      when 'reopened' then :reopened
      when 'delivered' then :delivered
      else :opened
      end

    @task = Task.create(
      company_id: @company_id,
      software_id: @software_id,
      code: @code,
      name: @name,
      date_opened: @date_opened,
      status: status_task,
    )

    return false unless @task.persisted?

    unless task_item_create
      increment_error('Linha ignorada por horas/status ausentes')
      return false
    end
    true
  end

  def find_update
    @find_update ||= Upload.find(@upload_id)
  end

  # removed duplicate create_task_and_task_item

  def increment_success
    u = find_update
    u.update(success_count: u.success_count.to_i + 1)
  end

  def increment_error(message)
    u = find_update
    u.update(error_count: u.error_count.to_i + 1, error_messages: append_error_message(u.error_messages, message))
  end

  def update_total_lines(count)
    find_update.update(total_lines: count)
  end

  def append_error_message(existing, message)
    msgs = existing.present? ? existing.to_s.split("\n") : []
    msgs << message.to_s
    msgs.uniq.join("\n")
  end

  def status_parse(value)
    v = ActiveSupport::Inflector.transliterate(value.to_s).downcase.strip
    map = {
      'finalizado' => 'finalized',
      'finalizada' => 'finalized',
      'final' => 'finalized',
      'concluido' => 'finalized',
      'concluida' => 'finalized',
      'pendente' => 'pending',
      'pendencia' => 'pending',
      'pending' => 'pending',
      'entregue' => 'delivered',
      'reaberto' => 'reopened',
      'reaberta' => 'reopened',
    }
    map[v]
  end

  def safe_cell(row, idx)
    c = row[idx]
    return '' if c.nil?

    begin
      v =
        if c.respond_to?(:formatted_value) && !c.formatted_value.nil?
          c.formatted_value
        else
          c.respond_to?(:value) ? c.value : c
        end
    rescue StandardError
      v = c.respond_to?(:value) ? c.value : c.to_s
    end
    v.to_s
  end

  def find_code_name(row)
    (row.length - 1).downto(0) do |idx|
      v = safe_cell(row, idx)
      next if v.blank?
      return v if v.match?(/^\s*\d+\s*[:\-–—]\s+.+$/)
    end
    ''
  end

  def find_software_cell(row)
    names = Software.all.map { |s| normalize(s.name) }
    row.each_with_index do |_, idx|
      v = normalize(safe_cell(row, idx))
      next if v.blank?
      return v if names.include?(v)
    end
    ''
  end

  def find_date_cell(row)
    row.each_with_index do |_, idx|
      v = safe_cell(row, idx)
      d = parse_date(v)
      return v if d.is_a?(Date)
    end
    ''
  end

  def find_hours(row)
    times = []
    row.each_with_index do |_, idx|
      v = safe_cell(row, idx)
      h = scan_hour(v)
      times << h if h.present?
    end
    s = times[0]
    e = times[1]
    if s.present? && e.present?
      begin
        ss = Time.zone.parse(s)
        ee = Time.zone.parse(e)
        return [s, e] if ee && ss && ee >= ss
      rescue StandardError
        return [s, nil]
      end
    end
    [s, nil]
  end

  def find_status_cell(row)
    row.each_with_index do |_, idx|
      v = safe_cell(row, idx)
      s = status_parse(v)
      return v if s.present?
    end
    ''
  end

  def parse_date(raw)
    s = raw.to_s.strip
    return Date.strptime(s, '%d/%m/%Y') if %r{^\d{2}/\d{2}/\d{4}$}.match?(s)
    return raw.to_date if raw.is_a?(Time) || raw.is_a?(DateTime)
    return raw if raw.is_a?(Date)
    return Date.parse(s) if s.match?(/^\d{4}-\d{2}-\d{2}$/)

    begin
      Date.parse(s)
    rescue ArgumentError
      nil
    end
  end

  def normalize_hour(text)
    s = text.to_s
    s = s.tr("\u00A0", ' ').strip
    if (m = s.match(/(\d{1,2})\s*[:hH\.\-–—\s]\s*(\d{2})/))
      h = m[1].to_i
      m2 = m[2].to_i
      return format('%<h>02d:%<m>02d', h:, m: m2)
    end
    ''
  end

  def scan_hour(text)
    s = text.to_s
    s = s.tr("\u00A0", ' ').strip
    if (m = s.match(/(\d{1,2})\s*[:hH\.\-–—\s]\s*(\d{2})/))
      h = m[1].to_i
      m2 = m[2].to_i
      return format('%<h>02d:%<m>02d', h:, m: m2)
    end
    ''
  end

  def find_software_id(name_cell)
    s = normalize(name_cell)
    return if s.empty?

    Software.all.find { |soft| normalize(soft.name) == s }&.id
  end

  def normalize(text)
    ActiveSupport::Inflector.transliterate(text.to_s).downcase.strip
  end

  def ensure_company
    return if Company.exists?(['name ilike ?', 'nobesistemas'])

    default_value = Company.first&.value || 10
    Company.find_or_create_by(name: 'NobeSistemas', value: default_value)
  end

  def ensure_software(raw_name)
    n = normalize(raw_name)
    return if n.empty?

    company = Company.where('name ilike ?', 'nobesistemas').first
    return if company.nil?

    existing = Software.where(company_id: company.id).find { |s| normalize(s.name) == n }
    existing ||= Software.create(company:, name: raw_name.to_s.strip)
    @software_id = existing.id
  end
end
