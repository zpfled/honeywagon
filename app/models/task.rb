# Company-level operational task with a due date.
class Task < ApplicationRecord
  belongs_to :company

  enum :status, { todo: 'todo', in_progress: 'in_progress', done: 'done' }, prefix: true

  validates :title, presence: true
  validates :due_on, presence: true
  validates :status, inclusion: { in: statuses.keys }

  before_save :sync_completed_at

  private

  def sync_completed_at
    if status_done?
      self.completed_at ||= Time.current
    else
      self.completed_at = nil if completed_at.present?
    end
  end
end
