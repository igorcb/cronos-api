FactoryBot.define do
  factory :company do
    name { |n| "Mystring_#{n}" }
  end
end
