class RouteGenerationRun < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: 'User', optional: true

  has_many :routes, dependent: :nullify, inverse_of: :generation_run

  enum :state, {
    draft: 0,
    active: 1,
    superseded: 2,
    archived: 3
  }, prefix: true

  validates :scope_key, presence: true
  validates :window_start, :window_end, :strategy, presence: true

  STATE_DRAFT = 0
  STATE_ACTIVE = 1
  STATE_SUPERSEDED = 2
  STATE_ARCHIVED = 3

  # Compatibility with legacy callers/tests that still use unprefixed predicate names.
  def draft?
    state_draft?
  end

  def active?
    state_active?
  end

  def superseded?
    state_superseded?
  end

  def archived?
    state_archived?
  end

  scope :for_scope, ->(company:, scope_key:) { where(company: company, scope_key: scope_key) }
  scope :active_for, ->(company:, scope_key:) { where(company: company, scope_key: scope_key, state: :active) }

  def route_date_range
    window_start..window_end
  end

  def mark_active!
    RouteGenerationRun.transaction do
      self.class.where(company: company, scope_key: scope_key)
                .where(state: :active)
                .where.not(id: id)
                .update_all(state: STATE_SUPERSEDED)
      update!(state: :active)
    end
  end
end
