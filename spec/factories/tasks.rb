FactoryBot.define do
  factory :task do
    company
    software
    code { Faker::Number.number }
    name { Faker::Lorem.sentence }
    description { Faker::Lorem.paragraphs }
    date_opened { '2023-09-29' }
    status { 1 }
    date_delivered { '2023-09-29' }
    observation { Faker::Lorem.paragraphs }
  end
end
