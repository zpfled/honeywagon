class BackfillAndDeduplicateRouteStopsForSingleAssignment < ActiveRecord::Migration[8.1]
  def up
    deduplicate_route_stops_per_service_event!
    backfill_missing_route_stops_from_legacy_assignments!
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Data backfill and deduplication cannot be reversed safely."
  end

  private

  def deduplicate_route_stops_per_service_event!
    say_with_time "Deduplicating route_stops to one row per service_event" do
      # Keep exactly one route_stop per service_event, preferring the most recent
      # route date, then newest route_stop row.
      ranked_duplicates = connection.select_all(<<~SQL.squish)
        SELECT ranked.service_event_id, ranked.id
        FROM (
          SELECT
            rs.service_event_id,
            rs.id,
            ROW_NUMBER() OVER (
              PARTITION BY rs.service_event_id
              ORDER BY r.route_date DESC NULLS LAST, rs.created_at DESC, rs.id DESC
            ) AS rn
          FROM route_stops rs
          INNER JOIN routes r ON r.id = rs.route_id
        ) ranked
        WHERE ranked.rn > 1
      SQL

      duplicate_groups = ranked_duplicates.to_a.group_by { |row| row["service_event_id"] }
      removed_count = 0

      duplicate_groups.each do |service_event_id, rows|
        ids = rows.map { |row| row["id"] }
        quoted_ids = ids.map { |id| connection.quote(id) }.join(", ")
        execute("DELETE FROM route_stops WHERE id IN (#{quoted_ids})")
        removed_count += ids.size
        say("Resolved conflict for service_event #{service_event_id}: removed #{ids.size} duplicate route_stops", true)
      end

      removed_count
    end
  end

  def backfill_missing_route_stops_from_legacy_assignments!
    say_with_time "Backfilling route_stops from legacy service_events.route_id" do
      missing_rows = connection.select_all(<<~SQL.squish)
        SELECT
          se.id AS service_event_id,
          se.route_id AS route_id,
          se.route_sequence AS route_sequence,
          se.status AS service_event_status,
          COALESCE(se.route_date, r.route_date) AS route_date
        FROM service_events se
        INNER JOIN routes r ON r.id = se.route_id
        LEFT JOIN route_stops rs ON rs.service_event_id = se.id
        WHERE se.route_id IS NOT NULL
          AND rs.id IS NULL
      SQL

      inserted = 0
      missing_rows.each do |row|
        route_id = row["route_id"]
        service_event_id = row["service_event_id"]
        desired_position = row["route_sequence"]&.to_i
        position = safe_position_for_route(route_id: route_id, desired_position: desired_position)
        route_date = row["route_date"]
        status = status_text_for(row["service_event_status"])

        insert_sql = <<~SQL.squish
          INSERT INTO route_stops
            (id, route_id, service_event_id, position, route_date, status, created_at, updated_at)
          VALUES
            (gen_random_uuid(), #{connection.quote(route_id)}, #{connection.quote(service_event_id)},
             #{position}, #{connection.quote(route_date)}, #{connection.quote(status)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
        execute(insert_sql)
        inserted += 1
      end

      inserted
    end
  end

  def safe_position_for_route(route_id:, desired_position:)
    max_position = connection.select_value(<<~SQL.squish)&.to_i || -1
      SELECT MAX(position)
      FROM route_stops
      WHERE route_id = #{connection.quote(route_id)}
    SQL

    candidate = desired_position.nil? ? (max_position + 1) : desired_position
    taken = connection.select_value(<<~SQL.squish)
      SELECT 1
      FROM route_stops
      WHERE route_id = #{connection.quote(route_id)}
        AND position = #{candidate}
      LIMIT 1
    SQL

    taken ? (max_position + 1) : candidate
  end

  def status_text_for(raw_status)
    case raw_status.to_i
    when 1 then "completed"
    when 2 then "skipped"
    else "scheduled"
    end
  end
end
