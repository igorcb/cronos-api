require 'roo'

class UploadService
  def initialize(file_path, upload_id)
    # byebug
    @file_path = file_path
    @upload_id = upload_id
  end

  def call
    # marca início do processamento e zera contadores
    begin
      find_update.update(status: :processing, success_count: 0, error_count: 0, total_lines: 0)
    rescue StandardError => e
      Rails.logger.error "Falha ao iniciar upload ##{@upload_id}: #{e.message}"
    end

    excel = Roo::Excelx.new(@file_path)
    count_lines = 0
    # byebug
    excel.each_row_streaming(offset: 1) do |row|
      # byebug if @date_opened == '28/04/2025'
      next if row[10].blank?

      count_lines += 1
      # byebug
      @day_week_temp = row[0].value.to_s.strip
      @day_week = row[0].value.to_s.strip

      @code, @name_temp = row[10].value.split(':')
      @code = @code.strip
      @name = @name_temp.strip

      @company_id = Company.where('name ilike ?', 'nobesistemas').first&.id
      @software_id = Software.where('name ilike ?', row[7].value.downcase).first&.id

      @date_opened = row[1].formatted_value.to_s
      @date_start = @date_opened

      @hour_start = row[2].formatted_value.to_s
      @date_end = @date_opened
      @hour_end = row[3].formatted_value.to_s
      @status = status_parse(row[8].value.downcase.strip)

      @task = Task.where(company_id: @company_id, software_id: @software_id, code: @code).first
      #puts ">>>>>>>>>>>>> Data Abertura: #{@date_opened} - ID: #{@code} - Status: #{@status}"
      # byebug if @date_opened == '28/04/2025' && @code == '11334'
      processed_ok = false
      begin
        if @task.present?
          processed_ok = task_item_create
        else
          processed_ok = create_task_and_task_item
        end
      rescue StandardError => e
        Rails.logger.error "Erro ao processar linha (code=#{@code}): #{e.message}"
        increment_error(e.message)
        # atualiza total_lines e segue
        update_total_lines(count_lines)
        next
      end

      # incrementa progresso e atualiza total_lines
      increment_success if processed_ok
      update_total_lines(count_lines)
    end

    find_update.update(status: :completed, total_lines: count_lines)
  rescue StandardError => e
    find_update.update(status: :failed, error_messages: e.message)
  end

  private

  def task_item_create
    # byebug if @day_week == 'Sexta'
    begin
      @item = TaskItem.where(task_id: @task.id, date_start: @date_start, hour_start: @hour_start, status: @status)
      return true if @item.present? # já existe, considera como processado
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
    @task = Task.create(
      company_id: @company_id,
      software_id: @software_id,
      code: @code,
      name: @name,
      date_opened: @date_opened,
      status: :opened,
    )
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
    status = { finalizado: 'finalized', pendente: 'pending' }
    status[value.to_sym]
  end
end

