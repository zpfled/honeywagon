class BackfillUserOwnership < ActiveRecord::Migration[8.1]
  def up
    say_with_time "Backfilling user ownership" do
      user = User.first || User.create!(
        email: "owner@example.com",
        password: "password123",
        password_confirmation: "password123",
        role: "dispatcher"
      )

      Order.where(user_id: nil).update_all(user_id: user.id)
      ServiceEvent.where(user_id: nil).update_all(user_id: user.id)
      ServiceEventReport.where(user_id: nil).update_all(user_id: user.id)
    end
  end

  def down
    # no-op
  end
end
