# Company-level task management.
class TasksController < ApplicationController
  before_action :set_company
  before_action :set_task, only: %i[update postpone]

  def index
    @date = parse_date(params[:date]) || Date.current
    @task = @company.tasks.new(due_on: @date)
    @tasks = tasks_for_date(@date)
  end

  def create
    @task = @company.tasks.new(task_params)

    if @task.save
      redirect_to tasks_path(date: @task.due_on), notice: 'Task added.'
    else
      @date = @task.due_on || Date.current
      @tasks = tasks_for_date(@date)
      render :index, status: :unprocessable_content
    end
  end

  def update
    if @task.update(task_params)
      redirect_to tasks_path(date: @task.due_on), notice: 'Task updated.'
    else
      @date = @task.due_on || Date.current
      @tasks = tasks_for_date(@date)
      render :index, status: :unprocessable_content
    end
  end

  def postpone
    if @task.update(postpone_params)
      redirect_to tasks_path(date: @task.due_on), notice: 'Task postponed.'
    else
      @date = @task.due_on || Date.current
      @tasks = tasks_for_date(@date)
      render :index, status: :unprocessable_content
    end
  end

  private

  def set_company
    @company = current_user.company
  end

  def set_task
    @task = @company.tasks.find(params[:id])
  end

  def task_params
    params.fetch(:task, {}).permit(:title, :description, :due_on, :status, :notes)
  end

  def postpone_params
    params.fetch(:task, {}).permit(:due_on)
  end

  def tasks_for_date(date)
    @company.tasks
            .where(due_on: date)
            .order(Arel.sql("CASE status WHEN 'done' THEN 2 WHEN 'in_progress' THEN 1 ELSE 0 END"), :created_at)
  end

  def parse_date(value)
    return if value.blank?

    Date.parse(value)
  rescue ArgumentError
    nil
  end
end
