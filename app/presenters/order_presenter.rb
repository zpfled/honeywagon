# OrderPresenter wraps an Order and exposes view-friendly helpers and labels.
class OrderPresenter
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::DateHelper

  attr_reader :order, :view

  delegate :rental_line_items, :units, to: :order, allow_nil: true

  def order_line_items
    order.respond_to?(:rental_line_items) ? order.rental_line_items : []
  end

  # Builds the presenter with the order and a view context for helpers.
  # `view` lets you call things like `l(...)` safely (I18n localization) from the presenter.
  def initialize(order, view_context:)
    @order = order
    @view = view_context
  end

  #
  # ---- Dates / labels ----
  #
  # Returns the primary key so the view can link to the order.
  def id
    order.id
  end

  # Exposes the freeform notes for display.
  def notes
    order.notes
  end

  # Returns the optional external reference/PO code if present.
  def external_reference
    order.external_reference.presence
  end

  # Formats the creation timestamp using the view's localization helpers.
  def created_at_long
    return order.created_at.to_s if order.created_at.blank?
    view.l(order.created_at, format: :long)
  rescue I18n::ArgumentError
    order.created_at.to_s
  end

  # Formats the order start date for display, falling back to ISO text.
  def start_date
    return order.start_date.to_s if order.start_date.blank?
    view.l(order.start_date)
  rescue I18n::ArgumentError
    order.start_date.to_s
  end

  # Formats the order end date for display, falling back to ISO text.
  def end_date
    return order.end_date.to_s if order.end_date.blank?
    view.l(order.end_date)
  rescue I18n::ArgumentError
    order.end_date.to_s
  end

  # Returns the inclusive number of days between start/end dates.
  def date_range_days
    return nil if order.start_date.blank? || order.end_date.blank?
    (order.end_date - order.start_date).to_i + 1
  rescue StandardError
    nil
  end

  #
  # ---- Associations / display ----
  #
  # Returns a friendly label for the customer to display in tables/cards.
  def customer_name
    order.customer&.display_name.presence || '—'
  end

  # Returns the name of the unit type associated with a line item.
  def line_item_unit_type_name(line_item)
    line_item.unit_type&.name ||
      line_item.try(:unit_type_name) ||
      '—'
  end

  # Builds a descriptive text label for a line item's service cadence.
  def line_item_schedule_label(line_item)
    parts = []

    if line_item.respond_to?(:service_schedule) && line_item.service_schedule.present?
      parts << line_item.service_schedule.to_s.humanize
    end

    if line_item.respond_to?(:billing_period) && line_item.billing_period.present?
      parts << line_item.billing_period.to_s.humanize
    end

    parts.any? ? parts.join(' • ') : '—'
  end

  # Returns the rendered quantity for a line item (or placeholder if missing).
  def line_item_quantity(line_item)
    return '—' unless line_item.respond_to?(:quantity)
    line_item.quantity.presence || '—'
  end

  # Formats the unit price for a line item, checking cents and decimal attrs.
  def line_item_unit_price(line_item)
    format_money_from(line_item, :unit_price_cents, :unit_price)
  end

  # Formats the subtotal for a line item, checking cents and decimal attrs.
  def line_item_subtotal(line_item)
    format_money_from(line_item, :subtotal_cents, :subtotal)
  end

  # Returns the best available label for the order's location.
  def location_name
    order.location&.label.presence || order.location&.name.presence || '—'
  end

  # Returns a single-line location address for quick reference.
  def location_address_line
    loc = order.location
    return nil if loc.blank? || loc.street.blank?

    city_state = [ loc.city, loc.state ].compact.join(', ').presence
    [ loc.street, city_state ].compact.join(' ')
  end

  # Renders a short title for a unit card, combining type and id.
  def unit_title(unit)
    type_name =
      if unit.respond_to?(:unit_type) && unit.unit_type&.name.present?
        unit.unit_type.name
      else
        'Unit'
      end

    id_part =
      if unit.respond_to?(:id) && unit.id.present?
        "##{unit.id}"
      else
        nil
      end

    [ type_name, id_part ].compact.join(' ')
  end

  # Renders supplemental information for a unit card (serial/status).
  def unit_secondary_line(unit)
    if unit.respond_to?(:serial) && unit.serial.present?
      "Serial: #{unit.serial}"
    elsif unit.respond_to?(:status) && unit.status.present?
      "Status: #{unit.status.to_s.humanize}"
    else
      '—'
    end
  end

  def service_events
    @service_events ||= order.service_events
                              .includes(:service_event_type, :route)
                              .order(:scheduled_on, :event_type)
  end

  def service_events_count
    service_events.size
  end



  #
  # ---- Status badge ----
  #
  # Returns the normalized status string for the order.
  def status
    (order.status.presence || 'unknown').to_s
  end

  # Builds the Tailwind status badge for the order's current state.
  def status_badge
    current_status = status

    classes =
      case current_status
      when 'draft'
        'bg-gray-100 text-gray-800 ring-gray-300'
      when 'scheduled'
        'bg-blue-100 text-blue-800 ring-blue-300'
      when 'active'
        'bg-green-100 text-green-800 ring-green-300'
      when 'completed'
        'bg-purple-100 text-purple-800 ring-purple-300'
      when 'canceled', 'cancelled'
        'bg-red-100 text-red-800 ring-red-300'
      else
        'bg-gray-100 text-gray-800 ring-gray-300'
      end

    view.content_tag(
      :span,
      current_status.humanize,
      class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 ring-inset #{classes}"
    )
  end

  #
  # ---- Money ----
  #
  # Returns the raw rental_subtotal_cents field (or nil for unsupported orders).
  def rental_subtotal_cents
    order.respond_to?(:rental_subtotal_cents) ? order.rental_subtotal_cents : nil
  end

  # Converts the rental subtotal in cents to dollars.
  def rental_subtotal_amount
    dollars_from_cents(rental_subtotal_cents)
  end

  # Returns a currency-formatted rental subtotal string.
  def rental_subtotal_currency
    format_currency(rental_subtotal_cents, from_cents: true)
  end

  # For your “Line items” footer row subtotal (presentation only)
  # Returns the total of all line item subtotals in cents when available.
  def line_items_subtotal_cents
    return nil unless order.respond_to?(:rental_line_items)
    line_items = order.rental_line_items
    return nil if line_items.blank?

    if subtotal_cents_supported?(line_items)
      calculate_subtotal(line_items, :subtotal_cents)
    elsif subtotal_amount_supported?(line_items)
      (calculate_subtotal(line_items, :subtotal) * 100).to_i
    end
  end

  # Formats the aggregate line-item subtotal for display.
  def line_items_subtotal_currency
    cents = line_items_subtotal_cents
    format_currency(cents, from_cents: true)
  end

  #
  # ---- Counts ----
  #
  # Returns how many line items are associated with the order.
  def line_items_count
    order.respond_to?(:rental_line_items) ? order.rental_line_items.size : 0
  end

  # Returns how many units are assigned to the order.
  def units_count
    order.respond_to?(:units) ? order.units.size : 0
  end

  private

  # Formats an amount either in cents or dollars using ActionView helpers.
  def format_currency(value, from_cents: false)
    return '—' if value.blank?

    amount =
      if from_cents
        value.to_f / 100
      else
        value.to_f
      end

    number_to_currency(amount)
  end

  # Converts integer cents into a float dollar amount for calculations.
  def dollars_from_cents(cents)
    return nil if cents.blank?
    cents.to_f / 100
  end

  # Reads cents- or float-based money columns from a record and formats them.
  def format_money_from(record, cents_attr, amount_attr)
    cents_value = record.respond_to?(cents_attr) ? record.public_send(cents_attr) : nil
    amount_value = record.respond_to?(amount_attr) ? record.public_send(amount_attr) : nil

    if cents_value.present?
      format_currency(cents_value, from_cents: true)
    elsif amount_value.present?
      format_currency(amount_value)
    else
      '—'
    end
  end

  # True when the relation or objects expose a subtotal_cents column/method.
  def subtotal_cents_supported?(line_items)
    column_present?(line_items, :subtotal_cents) || first_item_responds?(line_items, :subtotal_cents)
  end

  # True when the relation or objects expose a subtotal amount column/method.
  def subtotal_amount_supported?(line_items)
    column_present?(line_items, :subtotal) || first_item_responds?(line_items, :subtotal)
  end

  # Detects whether the relation's table includes a given column.
  def column_present?(collection, column_name)
    collection.respond_to?(:klass) && collection.klass.column_names.include?(column_name.to_s)
  end

  # Checks the first item in a collection for a responder method.
  def first_item_responds?(collection, method_name)
    item = collection.respond_to?(:first) ? collection.first : nil
    item.respond_to?(method_name)
  end

  # Calculates a subtotal for the provided line items using the given attribute.
  def calculate_subtotal(line_items, attribute)
    if line_items.respond_to?(:loaded?) && !line_items.loaded? && column_present?(line_items, attribute)
      line_items.sum(attribute).to_f
    else
      Array(line_items).sum { |li| li.public_send(attribute).to_f }
    end
  end
end
