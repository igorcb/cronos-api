class CalculateTotalHours
  def initialize
    @total_hours = 0
    @total_minutes = 0
  end

  def execute(time_strings = [])
    return '00:00' if time_strings.empty?

    time_strings.each do |time_str|
      hours, minutes = time_str.split(':').map(&:to_i)

      @total_hours += hours
      @total_minutes += minutes
    end

    if @total_minutes >= 60
      additional_hours, @total_minutes = @total_minutes.divmod(60)
      @total_hours += additional_hours
    end

    format('%<hours>02d:%<minutes>02d', hours: @total_hours, minutes: @total_minutes)
  end
end