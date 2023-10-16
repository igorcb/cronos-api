class TasksController < ApplicationController
  before_action :set_task, only: [:show]

  def index
    @tasks = Task.order(date_opened: :desc)
    render json: @tasks, status: :ok
  end

  def show
    render json: @task, status: :ok
  end

  def create
    @task = Task.new(task_params)

    if @task.save
      render json: @task, status: :created
    else
      render json: @task.errors.messages, status: :unprocessable_entity
    end
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(
      :company_id,
      :software_id,
      :code,
      :name,
      :description,
      :date_opened,
      :status,
      :date_delivered,
      :observation,
    )
  end
end
