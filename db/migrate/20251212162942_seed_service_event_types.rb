class SeedServiceEventTypes < ActiveRecord::Migration[8.1]
  class ServiceEventType < ApplicationRecord
    self.table_name = "service_event_types"
  end

  class ServiceEvent < ApplicationRecord
    self.table_name = "service_events"
  end

  DEFAULT_TYPES = [
    {
      key: "delivery",
      name: "Delivery",
      requires_report: false,
      report_fields: []
    },
    {
      key: "service",
      name: "Service",
      requires_report: true,
      report_fields: [
        { key: "customer_name", label: "Customer Name" },
        { key: "customer_address", label: "Customer Address" },
        { key: "estimated_gallons_pumped", label: "Estimated Gallons Pumped" },
        { key: "units_pumped", label: "Units Pumped" }
      ]
    },
    {
      key: "pickup",
      name: "Pickup",
      requires_report: true,
      report_fields: [
        { key: "customer_name", label: "Customer Name" },
        { key: "customer_address", label: "Customer Address" },
        { key: "estimated_gallons_pumped", label: "Estimated Gallons Pumped" },
        { key: "units_pumped", label: "Units Picked Up" }
      ]
    }
  ].freeze

  def up
    DEFAULT_TYPES.each do |attrs|
      ServiceEventType.find_or_create_by!(key: attrs[:key]) do |type|
        type.name = attrs[:name]
        type.requires_report = attrs[:requires_report]
        type.report_fields = attrs[:report_fields]
      end
    end

    ServiceEvent.reset_column_information
    ServiceEventType.reset_column_information

    ServiceEvent.find_each do |event|
      type = ServiceEventType.find_by(key: event.event_type)
      next unless type
      event.update_columns(service_event_type_id: type.id)
    end
  end

  def down
    ServiceEvent.update_all(service_event_type_id: nil)
    ServiceEventType.where(key: DEFAULT_TYPES.map { |t| t[:key] }).delete_all
  end
end
