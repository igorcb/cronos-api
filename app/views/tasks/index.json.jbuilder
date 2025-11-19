json.array! @tasks do |t|
  json.id t.id
  json.companyName t.company&.name
  json.softwareName t.software&.name
  json.code t.code
  json.name t.name
  json.dateOpened t.date_opened
  json.status t.status
  json.dateDelivered t.date_delivered
  json.observation t.observation
  json.totalHours t.total_hours.to_s
end