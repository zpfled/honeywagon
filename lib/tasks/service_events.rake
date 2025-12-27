namespace :service_events do
  desc 'Backfill completed_on for completed events missing a completion date'
  task backfill_completed_on: :environment do
    scope = ServiceEvent.where(completed_on: nil, status: ServiceEvent.statuses[:completed])
    total = scope.count
    puts "Backfilling completed_on for #{total} service events..."

    scope.find_in_batches(batch_size: 1000) do |batch|
      ids = batch.map(&:id)
      ServiceEvent.where(id: ids).update_all('completed_on = updated_at')
    end

    puts 'Backfill complete.'
  end
end
