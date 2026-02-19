namespace :tasks do
  desc 'Seed the 90-day plan tasks for a specific company id (UUID). Usage: bin/rails tasks:seed_90_day[COMPANY_ID]'
  task seed_90_day: :environment do |_t, args|
    company_id = args.extras.first
    if company_id.blank?
      puts 'Company id is required. Example: bin/rails tasks:seed_90_day[51ac7f07-e732-406c-87e8-35e48ded2cf5]'
      next
    end

    company = Company.find_by(id: company_id)
    unless company
      puts "Company not found: #{company_id}"
      next
    end

    seeder = Tasks::NinetyDayPlanSeeder.new(company: company)
    if seeder.send(:already_seeded?)
      puts "90-day plan already seeded for company #{company_id}"
      next
    end

    seeder.call
    puts "Seeded 90-day plan tasks for company #{company_id}"
  end
end
