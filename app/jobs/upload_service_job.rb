class UploadServiceJob < ApplicationJob
  def perform(file_path, upload_id)
    upload = Upload.find(upload_id)
    service = UploadService.new(file_path, upload)
    service.call
  end
end
