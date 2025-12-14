require "rails_helper"

RSpec.describe Importers::CustomersCsvImporter do
  let(:company) { create(:company) }
  let(:dry_run) { false }
  let(:csv_file) { Tempfile.new([ "customers", ".csv" ]) }
  let(:importer) { described_class.new(company: company, path: csv_file.path, dry_run: dry_run) }

  after do
    csv_file.close
    csv_file.unlink
  end

  describe "#call" do
    it "creates customers from the CSV data" do
      write_csv([
        [ "", "Customer", "Phone Numbers", "Email", "Full Name", "Billing Address", "Shipping Address" ],
        [ "", "Acres USA", "Phone: (608) 606-5632", "support@acresusa.com", "", "", "" ]
      ])

      summary = importer.call

      expect(summary[:created]).to eq(1)
      expect(company.customers.pluck(:billing_email)).to include("support@acresusa.com")
    end

    it "updates existing customers by filling blank fields" do
      customer = create(:customer, company: company, billing_email: "bob@example.com", phone: nil, business_name: "Bob Co")
      write_csv([
        [ "", "Customer", "Phone Numbers", "Email", "Full Name", "Billing Address", "Shipping Address" ],
        [ "", "Bob Co", "Phone: (111) 222-3333", "bob@example.com", "Bob Builder", "", "" ]
      ])

      summary = importer.call
      customer.reload

      expect(summary[:updated]).to eq(1)
      expect(customer.phone).to eq("(111) 222-3333")
    end

    it "skips rows that would not change anything" do
      create(:customer, company: company, billing_email: "bob@example.com", phone: "555-2222", business_name: "Bob Co")
      write_csv([
        [ "", "Customer", "Phone Numbers", "Email", "Full Name", "Billing Address", "Shipping Address" ],
        [ "", "Bob Co", "Phone: 555-2222", "bob@example.com", "Bob Builder", "", "" ]
      ])

      summary = importer.call

      expect(summary[:skipped]).to eq(1)
    end

    it "supports dry-run imports without persisting data" do
      write_csv([
        [ "", "Customer", "Phone Numbers", "Email", "Full Name", "Billing Address", "Shipping Address" ],
        [ "", "Dry Run Co", "Phone: 555-3333", "dry@example.com", "Dana Doe", "", "" ]
      ])

      dry_summary = described_class.new(company: company, path: csv_file.path, dry_run: true).call

      expect(dry_summary[:created]).to eq(1)
      expect(company.customers.where(billing_email: "dry@example.com")).to be_empty
    end

    it "records failures for invalid rows" do
      write_csv([
        [ "", "Customer", "Phone Numbers", "Email", "Full Name", "Billing Address", "Shipping Address" ],
        [ "", "", "Phone: 555-4444", "", "", "", "" ]
      ])

      summary = importer.call

      expect(summary[:failed]).to eq(1)
      expect(summary[:errors].first).to match(/display name/i)
    end
  end

  def write_csv(rows)
    preface = [
      [ '"Sit & Git Portables, LLC"', "", "", "", "", "", "" ],
      [ "Customer Contact List", "", "", "", "", "", "" ],
      Array.new(7, ""),
      Array.new(7, "")
    ].map { |r| r.join(",") }

    content = preface + rows.map { |row| row.join(",") }
    csv_file.write(content.join("\n"))
    csv_file.rewind
  end
end
