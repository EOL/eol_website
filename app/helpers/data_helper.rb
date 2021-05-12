require "util/term_i18n"

# NOTE that you use the show_* methods with a - not a = because it's writing
# to the stream directly, NOT building an output for you to show...
module DataHelper
  EXTRA_METADATA_KEYS = %i(
    citation
    measurement_method
    remarks
    sample_size
    scientific_name
    source
  )

  def metadata_container(data)
    haml_tag(:div, id: data[:id], class: "ui segments meta_data", style: "display: none;")
  end

  def trait_property_metadata(trait)
    EXTRA_METADATA_KEYS.collect do |key|
      if (value = trait.send(key)).present?
        { label: t("traits.properties.#{key}"), value: value }
      else
        nil
      end
    end.compact
  end

  def show_meta_data(datum)
    # Hard-coded exception for source, since it's duplicated:
    return if datum[:predicate][:uri] == 'http://purl.org/dc/terms/source'
    haml_tag(:div, class: "ui secondary segment") do
      haml_concat datum[:predicate][:name]
      if datum[:predicate][:uri]
        haml_tag(:br)
        haml_tag(:div, datum[:predicate][:uri], class: "data_type uk-text-muted eol-text-tiny")
      end
    end
    haml_tag(:div, class: "ui tertiary segment") do
      show_data_value(datum)
    end
  end

  def data_value(data, options={})
    parts = []
    value = t(:data_missing, keys: data.keys.join(", "))

    if @associations && data[:object_page_id]
      target_id = options[:page_is_assoc_obj] ? data[:page_id] : data[:object_page_id]
      page = @associations[target_id]
      unless page
        Rails.logger.warn("**** INEFFICIENT! Loading association for trait #{data[:eol_pk]}")
        if Page.exists?(target_id)
          page = Page.find(target_id)
        else
          return "[MISSING PAGE #{target_id}]"
        end
      end
      parts << link_to(name_for_page(page), page_path(page))
    elsif data[:object_term] && data[:object_term][:name]
      value = i18n_term_name(data[:object_term])
      parts << value
    elsif data[:combined_measurements]
      parts << data[:combined_measurements].join(", ")
    elsif val = data[:measurement] || data[:value_measurement]
      parts << val.to_s
      parts << data[:units][:name] if data[:units] && data[:units][:name]
    elsif val = data[:literal]
      parts << unlink(val).html_safe
    else
      parts << "CORRUPTED VALUE:"
      parts <<  value
    end

    parts.join(" ")
  end

  def trait_display_value(trait, options={})
    parts = []

    if trait.object_page
      page = options[:page_is_assoc_obj] ? trait.page : trait.object_page

      unless page
        return "[MISSING PAGE]"
      end

      parts << link_to(name_for_page(page), page_path(page))
    elsif trait.object_term
      value = trait.object_term.i18n_name
      parts << value
    elsif trait.measurement.present?
      parts << trait.measurement.to_s
      parts << trait.units_term.i18n_name if trait.units_term
    elsif trait.literal.present?
      parts << unlink(trait.literal).html_safe
    else
      parts << "CORRUPTED VALUE for trait #{trait.id}"
    end

    parts.join(" ")
  end

  def i18n_term_name(term)
    TraitBank::Record.i18n_name(term)
  end

  def i18n_term_defn(term)
    TraitBank::Record.i18n_defn(term)
  end

  def i18n_term_name_for_uri(uri)
    record = if uri.present?
               TraitBank::Term.term_record(uri)
             else
               nil
             end

    if record
      i18n_term_name(record)
    else
      uri
    end
  end

  def show_data_value(data, options={})
    value = data_value(data, options)

    haml_tag_if(data[:object_term], "div.a.js-data-val") do
      haml_concat value.html_safe # Traits allow HTML.
    end
  end

  def show_trait_value(trait, options={})
    value = trait_display_value(trait, options)

    haml_tag_if(trait.object_term, "div.a.js-data-val") do
      haml_concat value.html_safe # Traits allow HTML.
    end
  end

  def modifier_txt(trait)
    modifiers = [
      trait.sex_term&.i18n_name,
      trait.lifestage_term&.i18n_name,
      trait.statistical_method_term&.i18n_name
    ].compact

    if modifiers.any?
      separated_list(modifiers)
    else
      nil
    end
  end

  def show_modifier(type, value)
    haml_tag(:div, I18n.t("data.modifier.#{type}"), class: "ui secondary segment")
    if value =~ URI::ABS_URI
      term = TraitBank.term(value)
      value = term[:name] if term && term.key?(:name)
    end
    haml_tag(:div, value, class: "ui tertiary segment")
  end

  def show_source_segment(resource)
    if resource
      link_txt = resource.name.blank? ? resource_path(resource) : resource.name
      link_to(link_txt, resource)
    else
      logger.warn("resource missing for trait")
      I18n.t(:resource_missing)
    end
  end

  def show_data_page_icon(page)
    if image = safe_medium(page) # rubocop:disable Lint/AssignmentInCondition
      begin
        haml_concat(link_to(image_tag(image.small_icon_url,
          # TODO: restore this or find some placeholder images:
          # alt: page.scientific_name.html_safe, size: "44x44"), page))
          alt: '', size: "44x44"), page))
      rescue => e # rubocop:disable Style/RescueStandardError
        logger.error("error in show_data_page_icon", e)
        nil
      end
    end
  end

  def safe_medium(page)
    image = page.medium
    return image if image && (image.image? || image.map_image?)
    nil
  end

  def show_data_page_name(page)
    haml_tag(:div, class: "names d-inline") do
      if page.name && page.name != page.scientific_name
        haml_concat(link_to(page.name.titlecase, page, class: "primary-name"))
        haml_tag(:br)
        haml_concat(link_to(page.scientific_name.html_safe, page, class: "secondary-name"))
      else
        haml_concat(link_to(page.scientific_name.html_safe, page, class: "primary-name"))
      end
    end
  end

  def show_data_modifiers(data)
    [data[:statistical_method_term], data[:sex_term], data[:lifestage_term]].compact.each do |type|
      haml_tag(:div, type[:name], class: "data_type uk-text-muted uk-text-small uk-text-left")
    end
  end
end
