class TaskItemsController < ApplicationController
  before_action :set_task

  def index
    @task_item = @task.task_items
    render json: @task_item, status: :ok
  end

  def create
    @task_items = @task.task_items.build(task_item_params)

    if @task_items.save
      render json: @task_items, status: :created
    else
      render json: @task_items.errors.messages, status: :unprocessable_entity
    end
  end

  private

  def set_task
    @task = Task.find(params[:task_id])
  end

  def task_item_params
    params.require(:task_item).permit(
      :task_id,
      :date_start,
      :hour_start,
      :hour_end,
      :status,
      :observation,
    )
  end
end
