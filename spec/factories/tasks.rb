FactoryBot.define do
  factory :task do
    company { nil }
    software { nil }
    code { "MyString" }
    name { "MyString" }
    description { "MyText" }
    date_opened { "2023-09-29" }
    status { 1 }
    date_delivered { "2023-09-29" }
    observation { "MyText" }
  end
end
