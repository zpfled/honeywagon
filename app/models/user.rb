class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable


  ROLES = %w[admin dispatcher driver accountant].freeze

  def accountant? = role == "accountant"
  def admin?      = role == "admin"
  def dispatcher? = role == "dispatcher"
  def driver?     = role == "driver"
end
