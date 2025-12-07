# Unit Types
UnitType::TYPES.each do |attrs|
  UnitType.find_or_create_by!(slug: attrs[:slug]) do |ut|
    ut.name = attrs[:name]
  end
end

puts "Unit types:"
UnitType.all.each do |ut|
  puts " - #{ut.name} (#{ut.slug})"
end

# Units
standard  = UnitType.find_by!(slug: "standard")
ada       = UnitType.find_by!(slug: "ada")
handwash  = UnitType.find_by!(slug: "handwash")

def seed_unit(unit_type:, serial:, manufacturer:, status: "available")
  Unit.find_or_create_by!(serial: serial) do |u|
    u.unit_type    = unit_type
    u.manufacturer = manufacturer
    u.status       = status
  end
end

# Standard units (1–30)
1.upto(30) do |n|
  seed_unit(
    unit_type: standard,
    serial: n,
    manufacturer: (n <= 20 ? "OldCo" : "NiceCo")
  )
end

# ADA units (101–104)
101.upto(104) do |n|
  seed_unit(
    unit_type: ada,
    serial: n,
    manufacturer: "NiceCo"
  )
end

# Handwash stations (201–205)
201.upto(205) do |n|
  seed_unit(
    unit_type: handwash,
    serial: n,
    manufacturer: "NiceCo"
  )
end
