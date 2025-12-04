namespace :uploads do
  desc 'Process Excel file and update tasks'
  task :process, [:file_path] => :environment do |_, args|
    file_path = args[:file_path]
    abort 'file_path required' unless file_path

    upload = Upload.create(
      file_name: File.basename(file_path),
      total_lines: 0,
      status: :processing,
      success_count: 0,
      error_count: 0,
      error_messages: '',
    )

    UploadService.new(file_path, upload.id).call
    upload.reload
    puts "upload_id=#{upload.id} status=#{upload.status} total_lines=#{upload.total_lines}"
  end
end
