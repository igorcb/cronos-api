class TasksController < ApplicationController
  # Se estiver sem cookies no front, evite bloquear por CSRF:
  # protect_from_forgery with: :null_session

  def index
    # Evita cache para que a lista de tarefas sempre reflita o estado atual
    response.headers['Cache-Control'] = 'no-store'
    tasks = Task.includes(:company, :software).order(created_at: :desc)
    render json: tasks.map { |t|
      {
        id: t.id,
        companyName: t.company&.name,
        softwareName: t.software&.name,
        code: t.code,
        name: t.name,
        dateOpened: t.date_opened,
        status: t.status,
        dateDelivered: t.date_delivered,
        observation: t.observation,
        totalHours: t.total_hours.to_s,
      }
    }
  end

  def mark_delivered
    task = Task.find_by(id: params[:id])
    return render json: { error: 'Task not found' }, status: :not_found unless task

    task.update!(status: 'delivered', date_delivered: Time.zone.today)
    render json: {
      id: task.id,
      companyName: task.company&.name,
      softwareName: task.software&.name,
      code: task.code,
      name: task.name,
      dateOpened: task.date_opened,
      status: task.status,
      dateDelivered: task.date_delivered,
      observation: task.observation,
      totalHours: task.total_hours.to_s,
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end

