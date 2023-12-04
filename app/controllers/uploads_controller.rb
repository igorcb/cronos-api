class UploadsController < ApplicationController
  skip_before_action :verify_authenticity_token
  def new
    render json: { message: 'new' }, status: :ok
  end

  def create
    file = params[:file]
    # Salva o arquivo no sistema de arquivos temporário
    temp_file_path = Rails.root.join('tmp', file.original_filename)
    File.open(temp_file_path, 'wb') { |f| f.write(file.read) }

    upload = Upload.new(
      file_name: file.original_filename,
      total_lines: 0, # Substitua pela lógica real para calcular as linhas
      status: :processing, # Ou outro status desejado
      success_count: 0,
      error_count: 0,
      error_messages: '',
    )

    if upload.save
      # Inicia o processamento em segundo plano usando Sidekiq
      UploadServiceJob.perform_later(temp_file_path.to_s, upload.id)
      render json: { message: 'File processing started successfully.' }
    else
      render json: { error: 'Failed to save upload record.' }, status: :unprocessable_entity
    end
  end
end
