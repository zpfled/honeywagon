# frozen_string_literal: true

require 'csv'

module Importers
  # CustomersCsvImporter ingests a QuickBooks-exported CSV and upserts
  # tenant-scoped customers. QuickBooks prepends several metadata rows before
  # the header row, so we dynamically locate the row whose header includes
  # "Customer" and treat it as the start of the dataset.
  class CustomersCsvImporter
    COLUMN_MAPPING = {
      'customer' => :business_name,
      'email' => :billing_email,
      'email address' => :billing_email,
      'phone numbers' => :phone,
      'phone' => :phone,
      'mobile' => :phone,
      'mobile phone' => :phone,
      'telephone' => :phone
    }.freeze

    SUMMARY_KEYS = %i[created updated skipped failed].freeze

    attr_reader :company, :path, :dry_run, :logger

    def initialize(company:, path:, dry_run: false, logger: Rails.logger)
      @company = company
      @path = path
      @dry_run = dry_run
      @logger = logger
      @allowed_attributes = Customer.column_names.map(&:to_sym)
    end

    def call
      summary = SUMMARY_KEYS.index_with { 0 }
      summary[:errors] = []

      each_row do |row, row_number|
        attrs = extract_attributes(row)

        if attrs.blank?
          summary[:skipped] += 1
          next
        end

        begin
          process_row(attrs, row_number, summary)
        rescue StandardError => e
          summary[:failed] += 1
          summary[:errors] << "Row #{row_number}: #{e.message}"
        end
      end

      summary
    end

    private

    def each_row
      csv = build_csv
      return enum_for(:each_row) unless block_given?

      csv.each_with_index do |row, idx|
        row_number = (@header_index || 0) + idx + 2
        yield row, row_number
      end
    end

    def build_csv
      raw = File.read(path, encoding: 'bom|utf-8')
      table = CSV.parse(raw, headers: false)
      header_index = table.find_index { |row| header_row?(row) }
      raise ArgumentError, "Unable to locate header row in #{path}" unless header_index

      @header_index = header_index
      trimmed = table[header_index..]

      CSV.new(
        trimmed.map(&:to_csv).join,
        headers: true,
        header_converters: [ header_converter ],
        return_headers: false
      )
    end

    def header_row?(row)
      row.any? { |value| normalize_header(value) == 'customer' }
    end

    def normalize_header(header)
      header.to_s.strip.downcase
    end

    def header_converter
      @header_converter ||= ->(header) { normalize_header(header) }
    end

    def extract_attributes(row)
      attrs = {}

      COLUMN_MAPPING.each do |header, attribute|
        next unless @allowed_attributes.include?(attribute)

        value = row[header]
        next if value.blank?

        attrs[attribute] ||= normalize_value(attribute, value)
      end

      assign_from_full_name(row, attrs)

      attrs.symbolize_keys!
    end

    def normalize_value(attribute, value)
      cleaned = value.to_s.strip
      return cleaned unless attribute == :phone

      cleaned.gsub(/(phone|mobile)\s*:\s*/i, '').gsub(/\s+/, ' ').strip
    end

    def assign_from_full_name(row, attrs)
      return unless @allowed_attributes.include?(:first_name)

      full_name = row['full name']
      return if full_name.blank?

      parts = full_name.to_s.strip.split(/\s+/)
      return if parts.empty?

      attrs[:first_name] ||= parts.first
      attrs[:last_name] ||= parts[1..].join(' ') if parts.size > 1
      attrs[:business_name] ||= full_name.to_s.strip
    end

    # Deduplication strategy:
    # 1. If an email exists, match on billing_email.
    # 2. Otherwise fall back to business_name (QuickBooks company/display name).
    def find_existing_customer(attrs)
      finder =
        if attrs[:billing_email].present?
          { billing_email: attrs[:billing_email] }
        elsif attrs[:business_name].present?
          { business_name: attrs[:business_name] }
        end

      return unless finder

      company.customers.find_by(finder)
    end

    def process_row(attrs, row_number, summary)
      customer = find_existing_customer(attrs)

      if customer
        assignment = build_assignment_hash(customer, attrs)
        if assignment.blank?
          summary[:skipped] += 1
          return
        end

        persist(customer, assignment, row_number, summary, :updated)
      else
        new_customer = company.customers.new(attrs)
        persist(new_customer, {}, row_number, summary, :created)
      end
    end

    def build_assignment_hash(customer, attrs)
      attrs.each_with_object({}) do |(attr, value), buffer|
        next if value.blank?
        next if customer.public_send(attr).present?

        buffer[attr] = value
      end
    end

    def persist(customer, assignment, row_number, summary, success_key)
      record = dry_run ? customer.dup : customer
      record.assign_attributes(assignment) if assignment.present?

      if dry_run
        validate_record(record, row_number, summary, success_key)
      else
        save_record(record, row_number, summary, success_key)
      end
    end

    def validate_record(record, row_number, summary, success_key)
      if record.valid?
        summary[success_key] += 1
        logger.debug("[customers_csv_importer] Row #{row_number}: #{success_key} (dry-run)")
      else
        summary[:failed] += 1
        summary[:errors] << "Row #{row_number}: #{record.errors.full_messages.to_sentence}"
      end
    end

    def save_record(record, row_number, summary, success_key)
      if record.save
        summary[success_key] += 1
      else
        summary[:failed] += 1
        summary[:errors] << "Row #{row_number}: #{record.errors.full_messages.to_sentence}"
      end
    end
  end
end
