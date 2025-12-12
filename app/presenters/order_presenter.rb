class OrderPresenter
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::DateHelper

  attr_reader :order, :view

  # Delegate unknown stuff to the underlying order
  delegate_missing_to :order

  # `view` lets you call things like `l(...)` safely (I18n localization) from the presenter.
  def initialize(order, view_context:)
    @order = order
    @view = view_context
  end

  #
  # ---- Dates / labels ----
  #
  def id
    order.id
  end

  def external_reference
    order.external_reference.presence
  end

  def created_at_long
    view.l(order.created_at, format: :long)
  rescue StandardError
    order.created_at.to_s
  end

  def start_date
    view.l(order.start_date)
  rescue StandardError
    order.start_date.to_s
  end

  def end_date
    view.l(order.end_date)
  rescue StandardError
    order.end_date.to_s
  end

  def date_range_days
    return nil if order.start_date.blank? || order.end_date.blank?
    (order.end_date - order.start_date).to_i + 1
  rescue StandardError
    nil
  end

  #
  # ---- Associations / display ----
  #
  def customer_name
    order.customer&.company_name.presence || order.customer&.display_name.presence || '—'
  end

  def line_item_unit_type_name(line_item)
    line_item.unit_type&.name ||
      line_item.try(:unit_type_name) ||
      '—'
  end

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

   def line_item_quantity(line_item)
    return '—' unless line_item.respond_to?(:quantity)
    line_item.quantity.presence || '—'
  end

  def line_item_unit_price(line_item)
    if line_item.respond_to?(:unit_price_cents) && line_item.unit_price_cents.present?
      number_to_currency(line_item.unit_price_cents / 100.0)
    elsif line_item.respond_to?(:unit_price) && line_item.unit_price.present?
      number_to_currency(line_item.unit_price)
    else
      '—'
    end
  end

  def line_item_subtotal(line_item)
    if line_item.respond_to?(:subtotal_cents) && line_item.subtotal_cents.present?
      number_to_currency(line_item.subtotal_cents / 100.0)
    elsif line_item.respond_to?(:subtotal) && line_item.subtotal.present?
      number_to_currency(line_item.subtotal)
    else
      '—'
    end
  end

  def location_name
    order.location&.label.presence || order.location&.name.presence || '—'
  end

  def location_address_line
    loc = order.location
    return nil if loc.blank?
    return nil unless loc.respond_to?(:address_line1)
    return nil if loc.address_line1.blank?

    city =
      if loc.respond_to?(:city) && loc.city.present?
        ", #{loc.city}"
      else
        ''
      end

    "#{loc.address_line1}#{city}"
  end

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

  def unit_secondary_line(unit)
    if unit.respond_to?(:serial) && unit.serial.present?
      "Serial: #{unit.serial}"
    elsif unit.respond_to?(:status) && unit.status.present?
      "Status: #{unit.status.to_s.humanize}"
    else
      '—'
    end
  end



  #
  # ---- Status badge ----
  #
  def status
    (order.status.presence || 'unknown').to_s
  end

  def status_badge
    status = (order.status || 'unknown').to_s

    classes =
      case status
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

    content_tag(
      :span,
      status.humanize,
      class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 ring-inset #{classes}"
    )
  end

  #
  # ---- Money ----
  #
  def rental_subtotal_cents
    order.respond_to?(:rental_subtotal_cents) ? order.rental_subtotal_cents : nil
  end

  def rental_subtotal_amount
    return nil if rental_subtotal_cents.blank?
    rental_subtotal_cents / 100.0
  end

  def rental_subtotal_currency
    return '—' if rental_subtotal_amount.nil?
    number_to_currency(rental_subtotal_amount)
  end

  # For your “Line items” footer row subtotal (presentation only)
  def line_items_subtotal_cents
    return nil unless order.respond_to?(:order_line_items)

    if order.order_line_items.first&.respond_to?(:subtotal_cents)
      order.order_line_items.sum { |li| li.subtotal_cents.to_i }
    else
      nil
    end
  end

  def line_items_subtotal_currency
    cents = line_items_subtotal_cents
    return '—' if cents.blank?
    number_to_currency(cents / 100.0)
  end

  #
  # ---- Counts ----
  #
  def line_items_count
    order.respond_to?(:order_line_items) ? order.order_line_items.size : 0
  end

  def units_count
    order.respond_to?(:units) ? order.units.size : 0
  end
end
