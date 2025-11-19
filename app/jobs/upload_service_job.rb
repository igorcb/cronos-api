class UploadServiceJob < ApplicationJob
  queue_as :default

  def perform(file_path, upload_id)
    UploadService.new(file_path, upload_id).call
  end
end
