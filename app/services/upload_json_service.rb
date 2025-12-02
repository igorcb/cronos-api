class UploadJsonService
  def initialize(rows, upload_id)
    @rows = rows || []
    @upload_id = upload_id
  end

  def call
    begin
      find_update.update(status: :processing, success_count: 0, error_count: 0, total_lines: 0)
    rescue StandardError => e
      Rails.logger.error "Falha ao iniciar upload ##{@upload_id}: #{e.message}"
    end

    count_lines = 0
    @rows.each do |row|
      code_name = pick(row, %w[codeName code code_name card])
      next if code_name.to_s.strip.empty?

      parts = code_name.split(':', 2)
      @code = parts[0].to_s.strip
      @name = parts[1].to_s.strip

      @company_id = Company.where('name ilike ?', 'nobesistemas').first&.id
      @software_id = find_software_id(pick(row, %w[software Software software_name]))

      parsed_date = parse_date(pick(row, %w[date date_opened data]))
      @date_opened = parsed_date
      @date_start = parsed_date
      @date_end = parsed_date

      @hour_start = pick(row, %w[hourStart start startTime hour_start]).to_s.strip
      @hour_end = pick(row, %w[hourEnd end endTime hour_end]).to_s.strip
      @status = status_parse(pick(row, %w[status Status]))

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

    if @hour_start.to_s.strip.empty? || @hour_end.to_s.strip.empty?
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

    @task = Task.create(
      company_id: @company_id,
      software_id: @software_id,
      code: @code,
      name: @name,
      date_opened: @date_opened,
      status: :opened,
    )

    return false unless @task.persisted?

    task_item_create
  end

  def find_update
    @find_update ||= Upload.find(@upload_id)
  end

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
    v = value.to_s.downcase.strip
    map = {
      'finalizado' => 'finalized',
      'finalizada' => 'finalized',
      'final' => 'finalized',
      'concluido' => 'finalized',
      'concluida' => 'finalized',
      'pendente' => 'pending',
      'pendencia' => 'pending',
      'pendência' => 'pending',
      'pending' => 'pending',
    }
    map[v]
  end

  def parse_date(raw)
    s = raw.to_s.strip
    return Date.strptime(s, '%d/%m/%Y') if %r{^\d{2}/\d{2}/\d{4}$}.match?(s)
    return raw if raw.is_a?(Date)
    return raw.to_date if raw.is_a?(Time) || raw.is_a?(DateTime)

    nil
  end

  def find_software_id(name_cell)
    s = normalize(name_cell)
    return if s.empty?

    Software.all.find { |soft| normalize(soft.name) == s }&.id
  end

  def normalize(text)
    ActiveSupport::Inflector.transliterate(text.to_s).downcase.strip
  end

  def pick(hash, keys)
    keys.each do |k|
      v = hash[k] || hash[k.to_sym]
      return v unless v.nil?
    end
    nil
  end
end
