class CalculateHours
  def initialize
    @total_minutes = 0
  end

  def execute(hours = [])
    return '00:00' if hours.empty?

    hours.each do |k_hours_start, k_hours_end|
      next unless k_hours_start.present? && k_hours_end.present?

      hours_start, start_minute = k_hours_start.split(':').map(&:to_i)
      hours_end, end_minute = k_hours_end.split(':').map(&:to_i)

      difference_minutes = (hours_end * 60 + end_minute) - (hours_start * 60 + start_minute)

      @total_minutes += difference_minutes
    end

    total_hours = @total_minutes / 60
    rest_minutes = @total_minutes % 60

    format('%<hours>02d:%<minutes>02d', hours: total_hours, minutes: rest_minutes)
  end
end