# User represents an internal Honeywagon account with a specific role.
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable


  ROLES = %w[admin dispatcher driver accountant].freeze

  # Returns true when the user should see accounting-specific UI.
  def accountant? = role == 'accountant'
  # Returns true for full admin access.
  def admin?      = role == 'admin'
  # Returns true for dispatch/operations tooling.
  def dispatcher? = role == 'dispatcher'
  # Returns true for the driver/mobile workflow.
  def driver?     = role == 'driver'
end
