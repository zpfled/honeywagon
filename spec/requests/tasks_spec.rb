require "rails_helper"

RSpec.describe "/tasks", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /tasks" do
    it "renders the task list for the date" do
      date = Date.current
      task = create(:task, company: user.company, due_on: date)

      get tasks_path(date: date.to_s)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(task.title)
    end
  end

  describe "POST /tasks" do
    it "creates a company task" do
      date = Date.current

      expect do
        post tasks_path, params: {
          task: {
            title: "Call school",
            due_on: date.to_s
          }
        }
      end.to change { Task.count }.by(1)

      expect(response).to redirect_to(tasks_path(date: date.to_s))
    end
  end

  describe "PATCH /tasks/:id" do
    it "updates a task status" do
      task = create(:task, company: user.company, due_on: Date.current, status: "todo")

      patch task_path(task), params: { task: { status: "done" } }

      expect(response).to redirect_to(tasks_path(date: task.due_on.to_s))
      expect(task.reload.status).to eq("done")
    end

    it "rejects updates for another company" do
      other_task = create(:task)

      patch task_path(other_task), params: { task: { status: "done" } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /tasks/:id/postpone" do
    it "postpones a task to a new date" do
      task = create(:task, company: user.company, due_on: Date.current)
      new_date = Date.current + 1.day

      patch postpone_task_path(task), params: { task: { due_on: new_date.to_s } }

      expect(response).to redirect_to(tasks_path(date: new_date.to_s))
      expect(task.reload.due_on).to eq(new_date)
    end
  end
end
