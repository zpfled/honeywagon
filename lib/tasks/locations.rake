namespace :locations do
  desc 'Backfill latitude/longitude for locations via Google Places/Geocode API'
  task backfill_coordinates: :environment do
    client = Geocoding::GoogleClient.new
    if GoogleMaps.api_key.blank?
      puts 'Google Maps API key not configured. Aborting.'
      next
    end

    scope = Location.where(lat: nil).or(Location.where(lng: nil))
    total = scope.count

    puts "Found #{total} locations missing coordinates."

    scope.find_each.with_index(1) do |location, index|
      address = location.full_address
      if address.blank?
        puts "[#{index}/#{total}] Skipping #{location.id} (no address)."
        next
      end

      result = client.geocode(address)

      if result.present?
        location.update_columns(lat: result[:lat], lng: result[:lng])
        puts "[#{index}/#{total}] Updated #{location.id} -> (#{result[:lat]}, #{result[:lng]})"
      else
        puts "[#{index}/#{total}] No geocode result for #{location.id} (#{address})."
      end

      sleep 0.2
    end

    puts 'Done.'
  end
end
