module Companies
  class DumpSiteForm
    def initialize(company:, params:)
      @company = company
      @params = params
    end

    def call
      return if params.blank?

      attrs = params.dup
      location_attrs = attrs.delete(:location_attributes) || {}
      location = Location.new(location_attrs)
      location.dump_site = true
      location.save!

      company.dump_sites.create!(attrs.merge(location: location))
    end

    private

    attr_reader :company, :params
  end
end
