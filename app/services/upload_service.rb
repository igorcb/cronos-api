require 'roo'

class UploadService
  def initialize(file_path, upload_id)
    @file_path = file_path
    @upload_id = upload_id
  end

  def call
    excel = Roo::Excelx.new(@file_path)
    count_lines = 0

    excel.each_row_streaming(offset: 1) do |row|
      # next if index.zero? || row[0].blank?

      next if row[0].blank?

      count_lines += 1

      @code, @name_temp = row[9].value.split(':')
      @code = @code.strip
      @name = @name_temp.strip

      @company_id = Company.where('lower(name) = ?', 'nobesistemas').first&.id
      @software_id = Software.where('lower(name) = ?', row[6].value.downcase).first&.id

      @date_opened = row[1].formatted_value.to_s
      @date_start = @date_opened

      @hour_start = row[2].formatted_value.to_s
      @date_end = @date_opened
      @hour_end = row[3].formatted_value.to_s
      @status = status_parse(row[7].value.downcase.strip)

      @task = Task.where(company_id: @company_id, software_id: @software_id, code: @code).first

      if @task.present?
        task_item_create
      else
        create_task_and_task_item
      end
    end

    find_update.update(status: :completed, total_lines: count_lines)
  rescue StandardError => e
    find_update.update(status: :failed, error_messages: e.message)
  end

  private

  def task_item_create
    @item = TaskItem.where(task_id: @task.id, date_start: @date_start, hour_start: @hour_start, status: @status)
    return if @item.present?

    @task.task_items.create(
      date_start: @date_start,
      hour_start: @hour_start,
      date_end: @date_end,
      hour_end: @hour_end,
      status: @status,
    )
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

  def status_parse(value)
    status = { finalizado: 'finalized', pendente: 'pending' }
    status[value.to_sym]
  end
end

