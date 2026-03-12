class AddCompletedServiceEventRouteStopMutationGuard < ActiveRecord::Migration[8.1]
  TRIGGER_FUNCTION = "guard_route_stops_for_completed_service_events"
  TRIGGER_NAME = "trg_guard_route_stops_for_completed_service_events"

  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION #{TRIGGER_FUNCTION}()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        guarded_service_event_id uuid;
      BEGIN
        guarded_service_event_id :=
          CASE
            WHEN TG_OP = 'DELETE' THEN OLD.service_event_id
            ELSE NEW.service_event_id
          END;

        IF EXISTS (
          SELECT 1
          FROM service_events se
          WHERE se.id = guarded_service_event_id
            AND se.status = 1
        ) THEN
          RAISE EXCEPTION 'Cannot % route_stop for completed service_event %', TG_OP, guarded_service_event_id
            USING ERRCODE = '23514';
        END IF;

        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;

        RETURN NEW;
      END;
      $$;
    SQL

    execute <<~SQL
      DROP TRIGGER IF EXISTS #{TRIGGER_NAME} ON route_stops;
      CREATE TRIGGER #{TRIGGER_NAME}
      BEFORE INSERT OR UPDATE OR DELETE ON route_stops
      FOR EACH ROW
      EXECUTE FUNCTION #{TRIGGER_FUNCTION}();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS #{TRIGGER_NAME} ON route_stops;
      DROP FUNCTION IF EXISTS #{TRIGGER_FUNCTION}();
    SQL
  end
end
