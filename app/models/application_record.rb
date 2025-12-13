# ApplicationRecord is the base class for all Active Record models so common
# behavior can be configured in one place.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
