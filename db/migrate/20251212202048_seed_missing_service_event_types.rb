class SeedMissingServiceEventTypes < ActiveRecord::Migration[8.1]
  class GenericServiceEventType < ApplicationRecord
    self.table_name = "service_event_types"
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
        { "key" => "customer_name", "label" => "Customer Name" }
      ]
    },
    {
      key: "pickup",
      name: "Pickup",
      requires_report: true,
      report_fields: [
        { "key" => "customer_name", "label" => "Customer Name" }
      ]
    }
  ].freeze

  def change
    DEFAULT_TYPES.each do |attrs|
      GenericServiceEventType.find_or_create_by!(key: attrs[:key]) do |type|
        type.name = attrs[:name]
        type.requires_report = attrs[:requires_report]
        type.report_fields = attrs[:report_fields]
      end
    end
  end
end
