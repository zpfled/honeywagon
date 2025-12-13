class SeedDefaultReportFields < ActiveRecord::Migration[8.1]
  class ServiceEventType < ApplicationRecord
    self.table_name = "service_event_types"
  end

  def up
    ServiceEventType.find_each do |type|
      next unless %w[service pickup].include?(type.key)
      type.update!(
        report_fields: [
          { "key" => "customer_name", "label" => "Customer Name" },
          { "key" => "customer_address", "label" => "Customer Address" },
          { "key" => "units_pumped", "label" => "Units Serviced" },
          { "key" => "estimated_gallons_pumped", "label" => "Estimated Gallons Pumped" }
        ]
      )
    end
  end

  def down; end
end
