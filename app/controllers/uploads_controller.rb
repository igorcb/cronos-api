class UploadsController < ApplicationController
  # CSRF já desativado globalmente; garantir robustez caso callback não exista
  skip_before_action :verify_authenticity_token, raise: false
  def index
    response.headers['Cache-Control'] = 'no-store'
    uploads = Upload.order(created_at: :desc)
    render json: uploads.map { |u|
      {
        id: u.id,
        fileName: u.file_name,
        status: u.status,
        totalLines: u.total_lines,
        successCount: u.success_count,
        errorCount: u.error_count,
        errorMessages: u.error_messages,
        processedCount: (u.success_count.to_i + u.error_count.to_i),
        createdAt: u.created_at,
        updatedAt: u.updated_at,
      }
    }
  end

  def show
    response.headers['Cache-Control'] = 'no-store'
    u = Upload.find(params[:id])
    render json: {
             id: u.id,
             fileName: u.file_name,
             status: u.status,
             totalLines: u.total_lines,
             successCount: u.success_count,
             errorCount: u.error_count,
             errorMessages: u.error_messages,
             processedCount: (u.success_count.to_i + u.error_count.to_i),
             createdAt: u.created_at,
             updatedAt: u.updated_at,
           },
           status: :ok
  end

  def new
    render json: { message: 'new' }, status: :ok
  end

  def create
    if params[:file].present?
      file = params[:file]
      dir = Rails.root.join('tmp', 'uploads')
      FileUtils.mkdir_p(dir)
      temp_file_path = dir.join("#{SecureRandom.uuid}.xlsx")
      File.open(temp_file_path, 'wb') { |f| f.write(file.read) }

      upload = Upload.new(
        file_name: file.original_filename,
        total_lines: 0,
        status: :processing,
        success_count: 0,
        error_count: 0,
        error_messages: '',
      )

      if upload.save
        if ENV['UPLOAD_SYNC'] == '1' || params[:sync].to_s == '1'
          UploadService.new(temp_file_path.to_s, upload.id).call
        else
          UploadServiceJob.perform_later(temp_file_path.to_s, upload.id)
        end
        response.set_header('X-Upload-Id', upload.id)
        render json: { message: 'File processing started successfully.' }
      else
        render json: { error: 'Failed to save upload record.' }, status: :unprocessable_entity
      end
      return
    end

    rows = params[:rows] || params[:data] || params[:items] || params[:_json]
    unless rows.is_a?(Array)
      render json: { error: 'Invalid JSON payload. Expected array in rows.' }, status: :unprocessable_entity
      return
    end

    normalized_rows = rows.map { |r| r.respond_to?(:to_unsafe_h) ? r.to_unsafe_h : r }

    upload = Upload.new(
      file_name: 'payload.json',
      total_lines: 0,
      status: :processing,
      success_count: 0,
      error_count: 0,
      error_messages: '',
    )

    if upload.save
      if ENV['UPLOAD_SYNC'] == '1' || params[:sync].to_s == '1'
        UploadJsonService.new(normalized_rows, upload.id).call
      else
        UploadJsonServiceJob.perform_later(normalized_rows, upload.id)
      end
      response.set_header('X-Upload-Id', upload.id)
      render json: { message: 'File processing started successfully.' }
    else
      render json: { error: 'Failed to save upload record.' }, status: :unprocessable_entity
    end
  end
end
