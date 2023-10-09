FactoryBot.define do
  factory :software do
    company
    name { |n| "Mystring_#{n}" }
  end
end
