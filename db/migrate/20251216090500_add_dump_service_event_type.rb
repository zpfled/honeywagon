class AddDumpServiceEventType < ActiveRecord::Migration[8.1]
  def up
    ServiceEventType.reset_column_information
    ServiceEventType.find_or_create_by!(key: 'dump') do |type|
      type.name = 'Dump'
      type.requires_report = true
      type.report_fields = [
        { key: 'estimated_gallons_dumped', label: 'Estimated gallons dumped' }
      ]
    end
  end

  def down
    type = ServiceEventType.find_by(key: 'dump')
    type&.destroy!
  end
end
