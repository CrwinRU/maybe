class Cash < ApplicationRecord
  include Accountable

  class << self
    def display_name
      "Cash"
    end

    def color
      "#16B364"
    end

    def icon
      "wallet"
    end

    def classification
      "asset"
    end
  end
end
