module SmartAnswer::Calculators
  class ArrestedAbroad
    # created for the help-if-you-are-arrested-abroad calculator
    attr_accessor :country

    PRISONER_PACKS = YAML.load_file(Rails.root.join("config/smart_answers/prisoner_packs.yml")).freeze

    def generate_url_for_download(country, field, text)
      country_data = PRISONER_PACKS.find { |c| c["slug"] == country }
      return "" unless country_data

      url = country_data[field]
      output = []
      if url
        urls = url.split(" ")
        urls.each do |u|
          new_link = "- [#{text}](#{u})"
          new_link += '{:rel="external"}' if u.include? "http"
          output.push(new_link)
        end
        output.join("\n")
      else
        ""
      end
    end

    def countries_with_regions
      %w[cyprus]
    end

    def get_country_regions(slug)
      PRISONER_PACKS.find { |c| c["slug"] == slug }["regions"]
    end

    def location
      @location ||= WorldLocation.find(country)
      raise InvalidResponse unless @location

      @location
    end

    def organisation
      location.fco_organisation
    end

    def country_name
      location.name
    end

    def pdf
      generate_url_for_download(country, "pdf", "Prisoner pack for #{country_name}")
    end

    def doc
      generate_url_for_download(country, "doc", "Prisoner pack for #{country_name}")
    end

    def benefits
      generate_url_for_download(country, "benefits", "Benefits or legal aid in #{country_name}")
    end

    def prison
      generate_url_for_download(country, "prison", "Information on prisons and prison procedures in #{country_name}")
    end

    def judicial
      generate_url_for_download(country, "judicial", "Information on the judicial system and procedures in #{country_name}")
    end

    def police
      generate_url_for_download(country, "police", "Information on the police and police procedures in #{country_name}")
    end

    def consul
      generate_url_for_download(country, "consul", "Consul help available in #{country_name}")
    end

    def lawyer
      generate_url_for_download(country, "lawyer", "English speaking lawyers and translators/interpreters in #{country_name}")
    end

    def has_extra_downloads
      [police, judicial, consul, prison, lawyer, benefits, doc, pdf].count { |x|
        x != ""
      }.positive? || countries_with_regions.include?(country)
    end

    def region_downloads
      links = []
      if countries_with_regions.include?(country)
        regions = get_country_regions(country)
        regions.each_value do |val|
          links << "- [#{val['url_text']}](#{val['link']})"
        end
      end
      links.join("\n")
    end

    def transfer_back
      %w[austria belgium croatia denmark finland hungary italy latvia luxembourg malta netherlands slovakia].exclude?(country)
    end
  end
end
