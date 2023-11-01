FactoryBot.define do
  factory :upload do
    file_name { "MyString" }
    total_lines { 1 }
    status { 1 }
    success_count { 1 }
    error_count { 1 }
    error_messages { "MyText" }
  end
end
