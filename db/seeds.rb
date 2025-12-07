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
