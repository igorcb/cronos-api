class UploadJsonServiceJob < ApplicationJob
  queue_as :default

  def perform(rows, upload_id)
    UploadJsonService.new(rows, upload_id).call
  end
end
