# User represents an internal Honeywagon account with a specific role.
class User < ApplicationRecord
  attr_accessor :company_name

  belongs_to :company
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :created_orders, class_name: 'Order', foreign_key: :created_by_id, dependent: :nullify
  has_many :service_events, dependent: :destroy
  has_many :service_event_reports, dependent: :destroy

  ROLES = %w[admin dispatcher driver accountant].freeze

  # Returns true when the user should see accounting-specific UI.
  def accountant? = role == 'accountant'
  # Returns true for full admin access.
  def admin?      = role == 'admin'
  # Returns true for dispatch/operations tooling.
  def dispatcher? = role == 'dispatcher'
  # Returns true for the driver/mobile workflow.
  def driver?     = role == 'driver'

  # Allow Devise test helpers (e.g., sign_in user) to infer the proper scope.
  def devise_scope
    :user
  end
end
