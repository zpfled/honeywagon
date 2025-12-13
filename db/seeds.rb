# Helper Methods & Globals
start_time = Time.current
SEED_SUMMARY = {
  created: Hash.new(0),
  reused: Hash.new(0)
}

def banner(title)
  width = 70
  padding = [ width - title.length - 5, 0 ].max
  puts "\n=== #{title} #{'=' * padding}\n\n"
end

def label(record)
  [
    record.try(:label),
    record.try(:company_name),
    record.try(:external_reference),
    record.try(:serial),
    record.try(:name)
  ].find(&:present?) || "(no label)"
end

def created(record)
  SEED_SUMMARY[:created][record.class.name] += 1
  puts "✓ Created: #{record.class.name} — #{label(record)}"
end

def reused(record)
  SEED_SUMMARY[:reused][record.class.name] += 1
  puts "• Reused:  #{record.class.name} — #{label(record)}"
end

def next_weekday(date, target_wday)
  delta = (target_wday - date.wday) % 7
  delta = 7 if delta.zero?
  date + delta
end

def seed_unit(unit_type:, serial:, manufacturer:, status: "available")
  unit = Unit.find_or_initialize_by(serial: serial)
  unit.unit_type    = unit_type
  unit.manufacturer = manufacturer
  unit.status       = status

  if unit.new_record? || unit.changed?
    unit.save!
    created(unit)
  else
    reused(unit)
  end
end

def build_unit_type_requests(requests, unit_types)
  Array(requests).each_with_object({}) do |req, memo|
    unit_type = unit_types.fetch(req[:unit_type_slug].to_s)
    memo[unit_type.id.to_s] = {
      quantity: req[:quantity],
      service_schedule: RatePlan::SERVICE_SCHEDULES.fetch(req[:schedule])
    }
  end
end

def apply_final_status(order, final_status)
  case final_status.to_s
  when 'draft'
    # no-op
  when 'scheduled'
    order.schedule!
  when 'active'
    order.schedule!
    order.activate!
  when 'completed'
    order.schedule!
    order.activate!
    order.complete!
  when 'cancelled', 'canceled'
    order.schedule!
    order.cancel!
  else
    Rails.logger.warn("Unknown final status #{final_status.inspect} for order #{order.external_reference}")
  end
end

ActiveRecord::Base.transaction do
  banner "Ensuring Default User"
  primary_user = User.find_or_initialize_by(email: "demo@honeywagon.test")
  primary_user.role ||= "dispatcher"
  if primary_user.new_record?
    primary_user.password = "password123"
    primary_user.password_confirmation = "password123"
  end

  if primary_user.new_record? || primary_user.changed?
    primary_user.save!
    created(primary_user)
  else
    reused(primary_user)
  end

  banner "Seeding Unit Types"
  UnitType::TYPES.each do |attrs|
    ut = UnitType.find_or_initialize_by(slug: attrs[:slug])
    ut.name = attrs[:name]
    ut.prefix = attrs[:prefix]

    if ut.new_record? || ut.changed?
      ut.save!
      created(ut)
    else
      reused(ut)
    end
  end

  standard = UnitType.find_by!(slug: "standard")
  ada      = UnitType.find_by!(slug: "ada")
  handwash = UnitType.find_by!(slug: "handwash")
  unit_types_by_slug = {
    "standard" => standard,
    "ada" => ada,
    "handwash" => handwash
  }

  banner "Seeding Service Event Types"
  service_event_type_configs = [
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
  ]

  service_event_type_configs.each do |attrs|
    type = ServiceEventType.find_or_initialize_by(key: attrs[:key])
    type.assign_attributes(attrs)

    if type.new_record? || type.changed?
      type.save!
      created(type)
    else
      reused(type)
    end
  end

  banner "Seeding Units"
  unit_batches = [
    { unit_type: standard, count: 60, manufacturer: ->(idx) { idx < 30 ? "OldCo" : "NiceCo" } },
    { unit_type: ada,      count: 12, manufacturer: ->(_) { "NiceCo" } },
    { unit_type: handwash, count: 12, manufacturer: ->(_) { "SplashWorks" } }
  ]

  unit_batches.each do |batch|
    batch[:count].times do |index|
      serial = "#{batch[:unit_type].prefix}-#{index + 1}"
      seed_unit(
        unit_type: batch[:unit_type],
        serial: serial,
        manufacturer: batch[:manufacturer].call(index)
      )
    end
  end

  banner "Seeding Customers"
  customers_data = [
    {
      key: :acme,
      company_name: "ACME Events",
      first_name: "Alice",
      last_name: "Manager",
      billing_email: "billing@acme.com",
      phone: "555-1111"
    },
    {
      key: :buildit,
      company_name: "BuildIt Contractors",
      first_name: "Ben",
      last_name: "Foreman",
      billing_email: "ap@buildit.example",
      phone: "555-2222"
    },
    {
      key: :skyline,
      company_name: "Skyline Productions",
      first_name: "Sasha",
      last_name: "Lopez",
      billing_email: "accounting@skyline.example",
      phone: "555-3333"
    }
  ]

  customers = {}
  customers_data.each do |attrs|
    customer = Customer.find_or_initialize_by(company_name: attrs[:company_name])
    customer.assign_attributes(attrs.except(:key))

    if customer.new_record? || customer.changed?
      customer.save!
      created(customer)
    else
      reused(customer)
    end

    customers[attrs[:key]] = customer
  end

  banner "Seeding Locations"
  locations_data = [
    {
      key: :acme_wedding,
      customer_key: :acme,
      label: "ACME Wedding Site",
      street: "123 Field Rd",
      city: "Viroqua",
      state: "WI",
      zip: "54665"
    },
    {
      key: :acme_hq,
      customer_key: :acme,
      label: "ACME Corporate Campus",
      street: "400 Main St",
      city: "Madison",
      state: "WI",
      zip: "53703"
    },
    {
      key: :buildit_highrise,
      customer_key: :buildit,
      label: "Downtown Highrise Project",
      street: "77 Market St",
      city: "Milwaukee",
      state: "WI",
      zip: "53202"
    },
    {
      key: :buildit_subdivision,
      customer_key: :buildit,
      label: "Sunny Subdivision",
      street: "500 Sunshine Ave",
      city: "Sun Prairie",
      state: "WI",
      zip: "53590"
    },
    {
      key: :skyline_amphitheater,
      customer_key: :skyline,
      label: "Northwoods Amphitheater",
      street: "900 Lake Rd",
      city: "Hayward",
      state: "WI",
      zip: "54843"
    },
    {
      key: :skyline_festival,
      customer_key: :skyline,
      label: "Driftless Music Grounds",
      street: "1500 Hillside Ln",
      city: "Decorah",
      state: "IA",
      zip: "52101"
    }
  ]

  locations = {}
  locations_data.each do |attrs|
    location = Location.find_or_initialize_by(label: attrs[:label])
    location.assign_attributes(attrs.except(:key, :customer_key))
    location.customer = customers.fetch(attrs[:customer_key])

    if location.new_record? || location.changed?
      location.save!
      created(location)
    else
      reused(location)
    end

    locations[attrs[:key]] = location
  end

  banner "Seeding Rate Plans"
  rate_plan_configs = [
    { unit_type: standard, prices: { weekly: 14_000, biweekly: 12_000, event: 11_000 } },
    { unit_type: ada,      prices: { weekly: 18_000, biweekly: 16_000, event: 15_000 } },
    { unit_type: handwash, prices: { weekly: 8_000, event: 6_000 } }
  ]

  rate_plan_configs.each do |config|
    config[:prices].each do |schedule_key, price|
      service_schedule = RatePlan::SERVICE_SCHEDULES.fetch(schedule_key)
      billing_period = schedule_key == :event ? "per_event" : "monthly"

      rate_plan = RatePlan.find_or_initialize_by(
        unit_type: config[:unit_type],
        service_schedule: service_schedule,
        billing_period: billing_period
      )
      rate_plan.price_cents = price
      rate_plan.active = true

      if rate_plan.new_record? || rate_plan.changed?
        rate_plan.save!
        created(rate_plan)
      else
        reused(rate_plan)
      end
    end
  end

  banner "Seeding Orders"
  Unit.update_all(status: "available")

  today = Date.current
  weekend_start = next_weekday(today, 5) # Friday
  orders_data = [
    {
      external_reference: "ACME-001",
      customer_key: :acme,
      location_key: :acme_wedding,
      start_date: today + 14.days,
      end_date: today + 28.days,
      notes: "Summer wedding rentals and hygiene support.",
      final_status: :scheduled,
      unit_requests: [
        { unit_type_slug: :standard, quantity: 8, schedule: :weekly },
        { unit_type_slug: :handwash, quantity: 2, schedule: :event }
      ]
    },
    {
      external_reference: "DEMO-WEEK",
      customer_key: :acme,
      location_key: :acme_wedding,
      start_date: today + 1.day,
      end_date: today + 9.days,
      notes: "Demo order to guarantee upcoming-week events.",
      final_status: :scheduled,
      unit_requests: [
        { unit_type_slug: :standard, quantity: 4, schedule: :weekly },
        { unit_type_slug: :handwash, quantity: 1, schedule: :event }
      ]
    },
    {
      external_reference: "ACME-002",
      customer_key: :acme,
      location_key: :acme_hq,
      start_date: today - 90.days,
      end_date: today - 10.days,
      notes: "Corporate remodel, now completed.",
      final_status: :completed,
      unit_requests: [
        { unit_type_slug: :standard, quantity: 5, schedule: :biweekly },
        { unit_type_slug: :handwash, quantity: 1, schedule: :event }
      ]
    },
    {
      external_reference: "BUILD-100",
      customer_key: :buildit,
      location_key: :buildit_highrise,
      start_date: today - 5.days,
      end_date: today + 60.days,
      notes: "Downtown tower build-out in progress.",
      final_status: :active,
      unit_requests: [
        { unit_type_slug: :standard, quantity: 12, schedule: :weekly },
        { unit_type_slug: :ada, quantity: 2, schedule: :weekly },
        { unit_type_slug: :handwash, quantity: 2, schedule: :weekly }
      ]
    },
    {
      external_reference: "BUILD-105",
      customer_key: :buildit,
      location_key: :buildit_subdivision,
      start_date: today - 60.days,
      end_date: today + 90.days,
      notes: "Large subdivision needing long-term service (biweekly).",
      final_status: :active,
      unit_requests: [
        { unit_type_slug: :standard, quantity: 15, schedule: :biweekly },
        { unit_type_slug: :ada, quantity: 1, schedule: :weekly }
      ]
    },
    {
      external_reference: "BUILD-200",
      customer_key: :buildit,
      location_key: :buildit_subdivision,
      start_date: today + 20.days,
      end_date: today + 35.days,
      notes: "Cancelled site prep order.",
      final_status: :cancelled,
      unit_requests: [
        { unit_type_slug: :standard, quantity: 6, schedule: :weekly }
      ]
    },
    {
      external_reference: "SKY-500",
      customer_key: :skyline,
      location_key: :skyline_amphitheater,
      start_date: weekend_start,
      end_date: weekend_start + 2.days,
      notes: "Weekend festival (delivery + pickup only).",
      final_status: :scheduled,
      unit_requests: [
        { unit_type_slug: :standard, quantity: 5, schedule: :event },
        { unit_type_slug: :handwash, quantity: 1, schedule: :event }
      ]
    },
    {
      external_reference: "SKY-550",
      customer_key: :skyline,
      location_key: :skyline_festival,
      start_date: today + 45.days,
      end_date: today + 55.days,
      notes: "Future draft order awaiting confirmation.",
      final_status: :draft,
      unit_requests: [
        { unit_type_slug: :standard, quantity: 3, schedule: :weekly }
      ]
    }
  ]

  orders_data.each do |config|
    customer = customers.fetch(config[:customer_key])
    location = locations.fetch(config[:location_key])
    order = Order.find_or_initialize_by(external_reference: config[:external_reference])
    order.user ||= primary_user

    if order.persisted?
      order.units.update_all(status: "available") if order.units.any?
      order.service_events.auto_generated.delete_all
    end

    base_params = {
      customer_id: customer.id,
      location_id: location.id,
      start_date: config[:start_date],
      end_date: config[:end_date],
      status: 'draft',
      notes: config[:notes],
      external_reference: config[:external_reference]
    }

    unit_type_requests = build_unit_type_requests(config[:unit_requests], unit_types_by_slug)
    builder = Orders::Builder.new(order)
    builder.assign(params: base_params, unit_type_requests: unit_type_requests)

    if order.errors.any?
      raise ActiveRecord::RecordInvalid, "Order #{config[:external_reference]} invalid: #{order.errors.full_messages.to_sentence}"
    end

    was_new = order.new_record?
    order.save!
    order.reload

    apply_final_status(order, config[:final_status])

    was_new ? created(order) : reused(order)
  end
end

banner "Seed Summary"
all_models = (SEED_SUMMARY[:created].keys + SEED_SUMMARY[:reused].keys).uniq.sort
all_models.each do |model_name|
  created_count = SEED_SUMMARY[:created][model_name]
  reused_count  = SEED_SUMMARY[:reused][model_name]
  puts format("%-20s created: %3d | reused: %3d", model_name, created_count, reused_count)
end

puts "\nFinished seeding database in #{(Time.current - start_time).round(2)}s."
