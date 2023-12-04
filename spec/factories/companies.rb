FactoryBot.define do
  factory :company do
    name { |n| "Mystring_#{n}" }
    value { 10 }
  end
end
