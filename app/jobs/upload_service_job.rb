class UploadServiceJob < ApplicationJob
  def perform(file_path, upload_id)
    service = UploadService.new(file_path, upload_id)
    service.call
  end
end
