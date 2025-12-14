namespace :import do
  desc 'Import customers from a QuickBooks CSV (requires COMPANY_ID and CSV env vars)'
  task customers: :environment do
    csv_path = ENV['CSV']
    abort 'Usage: bundle exec rake import:customers CSV=path/to/file.csv [COMPANY_ID=<uuid>] [DRY_RUN=true]' unless csv_path.present?

    company = if ENV['COMPANY_ID'].present?
      Company.find(ENV['COMPANY_ID'])
    else
      count = Company.count
      abort 'Multiple companies exist. Specify COMPANY_ID.' if count != 1
      Company.first!
    end
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV['DRY_RUN'])

    importer = Importers::CustomersCsvImporter.new(
      company: company,
      path: csv_path,
      dry_run: dry_run
    )

    summary = importer.call

    puts "Import complete for #{company.name} (dry_run=#{dry_run})."
    puts "Created: #{summary[:created]}"
    puts "Updated: #{summary[:updated]}"
    puts "Skipped: #{summary[:skipped]}"
    puts "Failed:  #{summary[:failed]}"

    if summary[:errors].present?
      puts 'Errors:'
      summary[:errors].first(20).each { |error| puts "  - #{error}" }
      puts '  ... (truncated)' if summary[:errors].size > 20
    end
  rescue ActiveRecord::RecordNotFound => e
    abort e.message
  end
end
