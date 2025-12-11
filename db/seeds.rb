# Helper Methods
def banner(title)
  puts "\n=== #{title} #{'=' * (60 - title.length)}\n\n"
end

def label(record)
  [
    record.try(:label),
    record.try(:company_name),
    record.try(:serial),
    record.try(:name)
  ].find(&:present?) || "(no label)"
end


def created(record)
  puts "✓ Created: #{record.class.name} — #{label(record)}"
end

def reused(record)
  puts "• Reused:  #{record.class.name} — #{label(record)}"
end

# Begin Seeding
banner "Seeding Unit Types"

UnitType::TYPES.each do |attrs|
  ut = UnitType.find_or_initialize_by(slug: attrs[:slug])
  if ut.new_record?
    ut.name = attrs[:name]
    ut.prefix = attrs[:prefix]
    ut.save!
    created(ut)
  else
    reused(ut)
  end
end



banner "Seeding Units"

def seed_unit(unit_type:, serial:, manufacturer:, status: "available")
  unit = Unit.find_or_initialize_by(serial: serial)

  if unit.new_record?
    unit.unit_type    = unit_type
    unit.manufacturer = manufacturer
    unit.status       = status
    unit.save!
    created(unit)
  else
    reused(unit)
  end
end

standard = UnitType.find_by!(slug: "standard")
ada      = UnitType.find_by!(slug: "ada")
handwash = UnitType.find_by!(slug: "handwash")

# Standard units (1–30)
10.times do |n|
  seed_unit(
    unit_type: standard,
    serial: "#{standard.prefix}-#{n+1}",
    manufacturer: (n <= 20 ? "OldCo" : "NiceCo")
  )
end

# ADA units (101–104)
4.times do |n|
  seed_unit(
    unit_type: ada,
    serial: "#{ada.prefix}-#{n+1}",
    manufacturer: "NiceCo"
  )
end

# Handwash stations (201–205)
4.times do |n|
  seed_unit(
    unit_type: handwash,
    serial: "#{handwash.prefix}-#{n+1}",
    manufacturer: "NiceCo"
  )
end



banner "Seeding Customers"

customer = Customer.find_or_initialize_by(company_name: "ACME Events")
if customer.new_record?
  customer.first_name    = "Alice"
  customer.last_name     = "Manager"
  customer.billing_email = "billing@acme.com"
  customer.phone         = "555-1111"
  customer.save!
  created(customer)
else
  reused(customer)
end



banner "Seeding Locations"

location = Location.find_or_initialize_by(label: "ACME Wedding Site")
if location.new_record?
  location.street = "123 Field Rd"
  location.city   = "Viroqua"
  location.state  = "WI"
  location.zip    = "54665"
  location.save!
  created(location)
else
  reused(location)
end
