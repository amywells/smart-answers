module SmartAnswer::Calculators
  class LandlordImmigrationCheckCalculator
    VALID_COUNTRIES = %w( England )

    attr_reader :postcode

    def initialize(postcode)
      @postcode = postcode
    end

    def rules_apply?
      postcode_within?(VALID_COUNTRIES, 'country_name')
    end

    def postcode_within?(included_areas, key_name)
      areas_for_postcode.select { |a| included_areas.include?(a[key_name]) }.any?
    end

    def areas_for_postcode
      Services.imminence_api.areas_for_postcode(postcode).results
    end
  end
end
