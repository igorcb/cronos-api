FactoryBot.define do
  factory :task_item do
    task
    date_start { '2023-10-04' }
    hour_start { '2023-10-04 19:43:37' }
    date_end { '2023-10-04' }
    hour_end { '2023-10-04 19:43:37' }
    status { 1 }
    observation { 'MyText' }
  end
end
