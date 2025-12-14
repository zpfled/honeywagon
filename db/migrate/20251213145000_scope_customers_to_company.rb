class ScopeCustomersToCompany < ActiveRecord::Migration[8.1]
  def up
    rename_column :customers, :company_name, :business_name
    add_reference :customers, :company, type: :uuid, foreign_key: true

    Customer.reset_column_information

    say_with_time "Associating customers to companies" do
      Order.includes(:customer).where.not(customer_id: nil).find_each do |order|
        next unless order.customer && order.customer.company_id.nil?
        order.customer.update!(company_id: order.company_id)
      end

      default_company = Company.first
      Customer.where(company_id: nil).find_each do |customer|
        customer.update!(company_id: default_company.id) if default_company
      end
    end

    change_column_null :customers, :company_id, false
  end

  def down
    remove_index :customers, :business_name
    remove_reference :customers, :company
    rename_column :customers, :business_name, :company_name
  end
end
