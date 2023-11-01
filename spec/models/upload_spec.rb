require 'rails_helper'

RSpec.describe Upload, type: :model do
  subject(:upload) {
    described_class.new(
      file_name: 'File name',
      total_lines: 5,
      status: 0,
      success_count: 5,
      error_count: 0,
      error_messages: 'lorem ipsum',
    )
  }

  it { is_expected.to respond_to(:file_name) }
  it { is_expected.to respond_to(:total_lines) }
  it { is_expected.to respond_to(:status) }
  it { is_expected.to respond_to(:success_count) }
  it { is_expected.to respond_to(:error_count) }
  it { is_expected.to respond_to(:error_messages) }
end
