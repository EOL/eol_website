module Import
  class Repository
    def self.sync
      # TODO.
    end

    # rake db:reset ; rails runner "Import::Repository.start(Resource.first)"
    def self.start(resource)
      instance = self.new(resource)
      instance.start
    end

    def initialize(resource)
      @resource = resource
      @nodes = []
      @names = []
      @node_id_by_page = {}
      @traits = []
      @traitbank_pages = {}
      @traitbank_suppliers = {}
      @traitbank_terms = {}
    end

    def start
      # TODO: sync the resource (and content partner) itself.
      # TEMP:

      import_nodes
      create_new_pages
      import_scientific_names
      import_traits

      Node.where(resource_id: @resource.id).rebuild!(false)
      # Note: this is quite slow, but searches won't work without it. :S
      Reindexer.score_richness_for_pages(Page.where(id: @node_id_by_page.keys))
      Page.reindex
    end

    def import_nodes
      Node.where(resource_id: @resource.id).delete_all # TEMP!!!

      @nodes = get_new_instances_from_repo(Node) do |node|
        rank = node.delete(:rank)
        unless rank.nil?
          rank = Rank.where(name: rank).first_or_create do |r|
            r.name = rank
            r.treat_as = Rank.guess_treat_as(rank)
          end
          node[:rank_id] = rank.id
        end
        # TODO: we should have the repository calculate the depth...
        # So, until we parse the WHOLE thing (at the source), we have to deal with this. Probably fair enough to include
        # it here anyway:
        node[:scientific_name] ||= "Unamed clade #{node[:resource_pk]}"
        node[:canonical_form] ||= "Unamed clade #{node[:resource_pk]}"
      end
      Node.import(@nodes)
      # TODO: calculate lft and rgt... Ick.
      propagate_id(Node, resource: @resource, fk: 'parent_resource_pk',  other: 'nodes.resource_pk',
                         set: 'parent_id', with: 'id')
      Node.counter_culture_fix_counts
    end

    def create_new_pages
      # CREATE NEW PAGES: TODO: we need to recognize DWH and allow it to have its pages assign the native_node_id to it,
      # regardless of other nodes.
      begin
        Node.where(resource_pk: @nodes.map { |n| n.resource_pk }).select("id, page_id").find_each do |node|
          @node_id_by_page[node.page_id] = node.id
        end
        have_pages = Page.where(id: @node_id_by_page.keys).pluck(:id)
        missing = @node_id_by_page.keys - have_pages
        pages = missing.map { |id| { id: id, native_node_id: @node_id_by_page[id], nodes_count: 1 } }
        Page.import!(pages)
      rescue => e
        debugger
        puts "normal?"
      end
    end

    def import_scientific_names
      ScientificName.where(resource_id: @resource.id).delete_all # TEMP!!!

      @names = get_new_instances_from_repo(ScientificName) do |name|
        status = name.delete(:taxonomic_status)
        status = "accepted" if status.blank?
        unless status.nil?
          name[:taxonomic_status_id] = TaxonomicStatus.find_or_create_by(name: status).id
        end
        name[:node_id] = 0 # This will be replaced, but it cannot be nil. :(
      end
      begin
        ScientificName.import(@names)
        propagate_id(ScientificName, resource: @resource, fk: 'node_resource_pk',  other: 'nodes.resource_pk',
                           set: 'node_id', with: 'id')
        # TODO: This doesn't ensure we're getting *preferred* scientific_name.
        propagate_id(Node, resource: @resource, fk: 'id',  other: 'scientific_names.node_id',
                           set: 'scientific_name', with: 'italicized')
      rescue => e
        debugger
        puts "hi"
      end

      ScientificName.counter_culture_fix_counts
    end

    def import_traits
      TraitBank::Admin.remove_for_resource(@resource) # TEMP!!!

      page = 1
      total_pages = 2 # Dones't matter YET... will be populated in a bit...
      while page <= total_pages
        url = "http://localhost:3000/resources/#{@resource.repository_id}/traits.json?page=#{page}"
        puts "<< #{url}"
        html_response = Net::HTTP.get(URI.parse(url))
        response = JSON.parse(html_response)
        total_pages = response["totalPages"]
        response["traits"].each do |trait_data|
          trait_data.each { |k, v| trait[k.underscore.to_sym] = v }
          import_trait(trait_data)
        end
        page += 1
      end
    end

    def import_trait(trait)
      page_id = trait.delete("page_id")
      trait[:page] = @traitbank_pages[page_id] || add_page(page_id)
      trait[:object_page_id] = trait.delete("association")
      trait.delete(:object_page_id) if trait[:object_page_id] == 0
      res_id = @resource.id
      trait[:supplier] = @traitbank_suppliers[res_id] || add_supplier(res_id, @traitbank_suppliers)
      pred = trait.delete("predicate")
      unit = trait.delete("units")
      val_uri = trait.delete("value_uri")
      val_num = trait.delete("value_num")
      trait[:measurement] = val_num if val_num
      trait[:predicate] = @traitbank_terms[pred] || add_term(pred)
      trait[:units] = @traitbank_terms[unit] || add_term(unit)
      trait[:object_term] = @traitbank_terms[val_uri] || add_term(val_uri)
      trait[:metadata] = trait.delete("metadata").map do |md|
        md_pred = md.delete("predicate")
        md_val = md.delete("value_uri")
        md_unit = md.delete("units")
        md[:predicate] = @traitbank_terms[md_pred] || add_term(md_pred)
        md[:object_term] = @traitbank_terms[md_val] || add_term(md_val)
        md[:units] = @traitbank_terms[md_unit] || add_term(md_unit)
        md[:literal] = md.delete("value_literal")
        # TODO: I would feel better if we did more to check the measurement;
        # if there are units, we should have a measurement!
        md[:measurement] = md.delete("value_num")
        # TODO: add those back as links...
        md.symbolize_keys
      end
      trait[:statistical_method] = trait.delete("statistical_method")
      trait[:literal] = trait.delete("value_literal")
      trait[:source] = trait.delete("source_url")
      # The rest of the keys are "just right" and will work as-is:
      begin
        TraitBank.create_trait(trait.symbolize_keys)
      rescue Excon::Error::Socket => e
        begin
          TraitBank.create_trait(trait.symbolize_keys)
        rescue
          puts "** ERROR: could not add trait:"
          puts "** ID: #{trait["resource_pk"]}"
          puts "** Page: #{trait[:page]["data"]["page_id"]}"
          puts "** Predicate: #{trait[:predicate]["data"]["uri"]}"
        end
      rescue => e
        require "byebug"
        puts "NEOGRAPHY ERROR?"
        debugger
        1
      end
    end

    def add_page(page_id)
      tb_page = TraitBank.create_page(page_id)
      tb_page = tb_page.first if tb_page.is_a?(Array)
      if Page.exists?(page_id)
        page = Page.find(page_id)
        parent_id = page.try(:native_node).try(:parent).try(:page_id)
        if parent_id
          parent = @traitbank_pages[page_id] || add_page(parent_id)
          parent = parent.first if parent.is_a?(Array)
          if parent_id == page_id
            puts "** OOPS: we just tried to add #{parent_id} as a parent to itself!"
          else
            puts "Adding parent #{parent_id} to page #{page_id}..."
            TraitBank.add_parent_to_page(parent, tb_page)
          end
        end
      else
        puts "Trait attempts to use missing page: #{page_id}, ignoring links"
      end
      @traitbank_pages[page_id] = tb_page
      tb_page
    end

    def add_supplier(res_id)
      resource = TraitBank.create_resource(res_id)
      resource = resource.first if resource.is_a?(Array)
      @traitbank_suppliers[res_id] = resource
      resource
    end

    def add_term(uri)
      return(nil) if uri.blank?
      term =
        begin
          TraitBank.create_term(
            uri: uri,
            is_hidden_from_overview: true,
            is_hidden_from_glossary: true,
            name: uri,
            section_ids: [],
            definition: "auto-created, was empty",
            comment: "",
            attribution: ""
          )
        rescue Neography::PropertyValueException => e
          puts "** WARNING: Failed to set property on term... #{e.message}"
          puts "** This seems to occur with some bad trait data (passing in hashes instead of strings)"
          debugger
          1
        end
      @traitbank_terms[uri] = term
    end

    def get_new_instances_from_repo(klass)
      type = klass.class_name.underscore.pluralize.downcase
      things = []
      page = 1
      total_pages = 2 # Dones't matter YET... will be populated in a bit...
      while page <= total_pages
        url = "http://localhost:3000/resources/#{@resource.repository_id}/#{type}.json?page=#{page}"
        puts "<< #{url}"
        html_response = Net::HTTP.get(URI.parse(url))
        response = JSON.parse(html_response)
        total_pages = response["totalPages"]
        response[type.camelize(:lower)].each do |thing_data|
          thing = {}
          thing_data.each { |k, v| thing[k.underscore.to_sym] = v }
          yield(thing)
          things << klass.new(thing.merge(resource_id: @resource.id))
        end
        page += 1
      end
      things
    end

    # I AM NOT A FAN OF SQL... but this is **way** more efficient than alternatives:
    def propagate_id(klass, options = {})
      fk = options[:fk]
      set = options[:set]
      resource = options[:resource]
      with_field = options[:with]
      (o_table, o_field) = options[:other].split(".")
      sql = "UPDATE `#{klass.table_name}` t JOIN `#{o_table}` o ON (t.`#{fk}` = o.`#{o_field}` AND t.resource_id = ?) "\
            "SET t.`#{set}` = o.`#{with_field}`"
      clean_execute(klass, [sql, @resource.id])
    end

    def clean_execute(klass, args)
      clean_sql = klass.send(:sanitize_sql, args)
      klass.connection.execute(clean_sql)
    end
  end
end
