class Publishing
  class Fast
    require 'net/http'
    attr_accessor :data_file, :log

    def self.by_resource(resource)
      publr = new(resource)
      # Because I do this manually and the class name is needed for that:
      # publr = Publishing::Fast.new(res)
      publr.by_resource
    end

    def self.traits_by_resource(resource)
      publr = new(resource)
      publr.traits_by_resource
    end

    # e.g.: nohup rails r "Publishing::Fast.update_attributes_by_resource(Resource.find(724), ScientificName, [:dataset_name])" > dwh_datasets.log 2>&1 &
    def self.update_attributes_by_resource(resource, klass, fields)
      publr = new(resource)
      publr.update_attributes(klass, fields)
    end

    # e.g.: Publishing::Fast.load_local_file(Resource.find(123), NodeAncestor, '/some/path/to/tmp/DWH_node_ancestors.tsv')
    def self.load_local_file(resource, klass, file)
      publr = new(resource)
      publr.load_local_file(klass, file)
    end

    def load_local_file(klass, file)
      new_log
      set_relationships
      @klass = klass
      @data_file = file
      @log.start("One-shot manual import of #{@klass} starting...")
      @log.start("#import #{@klass}")
      import
      @log.start("#propagate_ids #{@klass}")
      propagate_ids
      @log.start("One-shot manual import of #{@klass} COMPLETED.")
    end

    def initialize(resource, log = nil)
      @start_at = Time.now
      @resource = resource
      # NOTE: this is likely to get overridden once we create a new log, but nice to have in case we need it:
      @log = log # Okay if it's nil.
      @repo = create_server_connection
      @files = []
      @can_clean_up = true
    end

    def create_server_connection
      ContentServerConnection.new(@resource, @log)
    end

    # NOTE: this does NOT work for traits. Don't try. You'll need to make a different method for that.
    def update_attributes(klass, fields)
      require 'csv'
      abort_if_already_running
      @klass = klass
      fields = Array(fields)
      positions = []
      fields.each do |field|
        # NOTE: Minus one for the id, which is NEVER in the file but is ALWAYS the first column in the table:
        positions << @klass.column_names.index(field.to_s) - 1
      end
      new_log
      begin
        plural = @klass.table_name
        unless @repo.exists?("#{plural}.tsv")
          raise("#{@repo.file_url("#{plural}.tsv")} does not exist! "\
                "Are you sure the resource has successfully finished harvesting?")
        end
        @log.start("Updating attributes: #{fields.join(', ')} (#{positions.join(', ')}) for #{plural}")
        @data_file = Rails.root.join('tmp', "#{@resource.path}_#{plural}.tsv")
        if grab_file("#{plural}.tsv")
          all_data = CSV.read(@data_file, col_sep: "\t")
          possible_pks = %w(harv_db_id resource_pk node_resource_pk)
          pk = possible_pks.find { |pk| @klass.column_names.include?(pk.to_s) }
          pk_pos = @klass.column_names.index(pk) - 1 # fix the 0-index
          all_data.in_groups_of(2000, false) do |lines|
            pks = lines.map { |l| l[pk_pos] }
            pks.map! { |k| k.to_i } if pk == 'harv_db_id' # Integer!
            instances = @klass.where(:resource_id => @resource.id, pk => pks).load
            @log.warn("#{instances.size} instances by #{pk}")
            keyed_instances = instances.group_by(&pk.to_sym)
            @log.warn("#{keyed_instances.keys.size} groups of keyed_instances")
            changes = []
            lines.each do |line|
              line_pk = line[pk_pos]
              line_pk = line_pk.to_i if pk == 'harv_db_id'
              values = {}
              positions.each_with_index { |pos, i| values[fields[i]] = line[pos] }
              keyed_instances[line_pk].each do |instance|
                values.each { |field, val| instance[field] = val unless instance[field] == val }
                changes << instance if instance.changed?
              end
            end
            @log.warn("#{changes.size} changes...")
            @klass.import(changes, on_duplicate_key_update: fields)
          end
          @files << @data_file
        else
          @log.warn("COULDN'T FIND #{plural}.tsv !")
        end
      rescue => e
        @log.fail_on_error(e)
        raise e
      ensure
        @log.end("TOTAL TIME: #{Time.delta_str(@start_at)}")
        @log.close
        ImportLog.all_clear!
      end
    end

    def set_relationships
      @relationships = {
        Referent => {},
        Node => { parent_id: Node },
        BibliographicCitation => { },
        Identifier => { node_id: Node },
        ScientificName => { node_id: Node },
        NodeAncestor => { node_id: Node, ancestor_id: Node },
        Vernacular => { node_id: Node },
        # Yes, really, there is no link to nodes or pages on Article or Medium; these are managed with PageContent.
        Article => { bibliographic_citation_id: BibliographicCitation },
        Medium => { bibliographic_citation_id: BibliographicCitation },
        Attribution => { content_id: [Medium, Article] }, # Polymorphic implied with array.
        ImageInfo => { medium_id: Medium },
        Reference => { referent_id: Referent }, # The polymorphic relationship is handled specially.
        ContentSection => { content_id: [Article] } # NOTE: at the moment, only articles have sections...
      }
    end

    def by_resource
      set_relationships
      abort_if_already_running
      new_log
      unless @resource.nodes.count.zero?
        begin
          @resource.remove_content
          # Re-grabbing the log shouldn't really be needed, but apparently it's a thing ...after removing traits?!
          @log = Publishing::PubLog.new(@resource, use_existing_log: true)
        rescue => e
          @log = Publishing::PubLog.new(@resource, use_existing_log: true)
          @log.fail_on_error(e)
          raise e
        end
        @log.warn('All existing content has been destroyed for the resource.')
      end
      begin
        unless @repo.exists?('nodes.tsv')
          raise("#{@repo.file_url('nodes.tsv')} does not exist! Are you sure the resource has successfully finished harvesting?")
        end
        @relationships.each_key { |klass| import_and_prop_ids(klass) }
        @log.start('restoring vernacular preferences...')
        VernacularPreference.restore_for_resource(@resource.id, @log)
        # You have to create pages BEFORE you slurp traits, because now it needs the scientific names from the page
        # objects.
        @log.start('PageCreator')
        PageCreator.by_node_pks(node_pks, @log, skip_reindex: true)
        if page_contents_required?
          @log.start('MediaContentCreator')
          MediaContentCreator.by_resource(@resource, log: @log)
        end
        publish_traits_with_cleanup
        @log.start('Resource#fix_native_nodes')
        @resource.fix_native_nodes
        @log.start('TraitBank::Denormalizer.update_resource_vernaculars')
        TraitBank::Denormalizer.update_resource_vernaculars(@resource)
        propagate_reference_ids
        clean_up
        if page_contents_required?
          @log.start('#fix_missing_icons (just to be safe)')
          Page.fix_missing_icons
        end
        Publishing::DynamicWorkingHierarchy.update(@resource, @log) if @resource.dwh?
      rescue => e
        clean_up
        @log.fail_on_error(e)
      ensure
        @log.end("TOTAL TIME: #{Time.delta_str(@start_at)}")
        @log.close
        ImportLog.all_clear!
      end
    end

    def traits_by_resource
      abort_if_already_running
      @log = @resource.import_logs.last
      @repo = create_server_connection
      @can_clean_up = true
      begin
        publish_traits_with_cleanup
      rescue => e
        clean_up
        @log.fail_on_error(e)
      ensure
        @log.end("TOTAL TIME: #{Time.delta_str(@start_at)}")
        @log.close
        ImportLog.all_clear!
      end
    end

    def publish_traits_with_cleanup
      @log.start('Remove traits')
      TraitBank::Admin.remove_for_resource(@resource)
      @log.start('#publish_traits = TraitBank::Slurp.load_resource_from_repo')
      begin
        publish_traits
      rescue => e
        backtrace = [e.backtrace[0]] + e.backtrace.grep(/\bapp\b/)[1..5]
        @log.warn("Trait Publishing failed: #{e.message} FROM #{backtrace.join(' << ')}")
        @can_clean_up = false
      end
      clean_up
    end

    def abort_if_already_running
      if (info = ImportLog.already_running?)
        @resource.log("ABORTED: #{info}")
        raise(info)
      end
    end

    def new_log
      @log ||= Publishing::PubLog.new(@resource) # you MIGHT want @resource.import_logs.last
      @repo = create_server_connection
      @log
    end

    def import_and_prop_ids(klass)
      @log.start(@klass = klass)
      @data_file = Rails.root.join('tmp', "#{@resource.path}_#{@klass.table_name}.tsv")
      if grab_file("#{@klass.table_name}.tsv")
        import
        propagate_ids
        @files << @data_file
      end
    end

    def clean_up
      return(nil) unless @can_clean_up
      @files.each do |file|
        if File.exist?(file)
          @log.info("Removing #{file}")
          File.unlink(file)
        else
          @log.info("Skipping removal of #{file} ... file does not exist")
        end
      end
      @can_clean_up = false
    end

    def grab_file(name)
      open(@data_file, 'wb') { |file| file.write(@repo.file(name)) }
    end

    def import
      @log.start("#import #{@klass}")
      cols = @klass.column_names
      cols.delete('id') # We never load the PK, since it's auto_inc.

      q = ['LOAD DATA']
      q << %{LOCAL INFILE '#{@data_file}' INTO TABLE `#{@klass.table_name}` }
      q << %{CHARACTER SET utf8mb4 FIELDS OPTIONALLY ENCLOSED BY '"' }
      q << "(#{cols.join(',')})"

      begin
        before_db_count = @klass.where(resource_id: @resource.id).count
        file_count = `wc #{@data_file}`.split.first.to_i
        @klass.connection.execute(q.join(' '))
        after_db_count = @klass.where(resource_id: @resource.id).count - before_db_count
        if file_count != after_db_count
          @log.warn("INCORRECT NUMBER OF ROWS DURING IMPORT OF #{@klass.name.pluralize.downcase}: "\
            "got #{after_db_count}, expected #{file_count} (from #{@data_file})")
        end
      rescue => e
        puts 'FAILED TO LOAD DATA. NOTE that it\'s possible you need to A) In Mysql,'
        puts 'GRANT FILE ON *.* TO your_user@localhost IDENTIFIED BY "your_password";'
        puts '...and B) add "local_infile=true" to your database.yml config for this to work.'
        raise e
      end
    end

    def propagate_ids
      @log.start("#propagate_ids #{@klass}")
      @relationships[@klass].each do |field, sources|
        next unless sources
        Array(sources).each do |source| # Array implies polymorphic relationship
          # This is a little weird, so I'll explain. CURRENTLY, "field" is populated with the IDs FROM THE HARVEST DB.
          # So this code is joining the two tables via that harv_db_id, then re-setting the field with the REAL id (from
          # THIS DB).
          @klass.propagate_id(fk: field, other: "#{source.table_name}.harv_db_id",
                              set: field, with: 'id', resource_id: @resource.id)
        end
      end
    end

    def propagate_reference_ids
      return nil if Reference.where(resource_id: @resource.id).count.zero?
      @log.start('#propagate_reference_ids')
      [Node, ScientificName, Medium, Article].each do |klass|
        next if Reference.where(resource_id: @resource.id, parent_type: klass.to_s).count.zero?
        min = Reference.where(resource_id: @resource.id, parent_type: klass.to_s).minimum(:id)
        max = Reference.where(resource_id: @resource.id, parent_type: klass.to_s).maximum(:id)
        page_size = 100_000
        clauses = []
        clauses << "UPDATE `references` t JOIN `#{klass.table_name}` o ON (t.parent_id = o.harv_db_id"
        clauses << "AND t.resource_id = #{@resource.id} AND t.parent_type = '#{klass}')"
        clauses << "SET t.parent_id = o.id"
        # TODO: this logic was pulled from config/initializers/propagate_ids.rb ; extract!
        if max - min > page_size
          while max > min
            inner_clauses = clauses.dup
            upper = min + page_size - 1
            inner_clauses << "WHERE t.id >= #{min} AND t.id <= #{upper}"
            ActiveRecord::Base.connection.execute(inner_clauses.join(' '))
            also_propagate_referents(klass, min: min, upper: upper)
            min += page_size
          end
        else
          ActiveRecord::Base.connection.execute(clauses.join(' '))
          also_propagate_referents(klass)
        end
      end
    end

    def also_propagate_referents(klass, options = {})
      clauses = []
      clauses << "UPDATE `references` t JOIN referents o ON (t.referent_id = o.harv_db_id"
      clauses << "AND t.resource_id = #{@resource.id} AND t.parent_type = '#{klass}')"
      clauses << "SET t.referent_id = o.id"
      clauses << "WHERE t.id >= #{options[:min]} AND t.id <= #{options[:upper]}" if options[:min]
      ActiveRecord::Base.connection.execute(clauses.join(' '))
    end

    def publish_traits
      TraitBank::Slurp.new(@resource, @log).load_resource_from_repo
    end

    def page_contents_required?
      Medium.where(resource_id: @resource.id).any? || Article.where(resource_id: @resource.id).any?
    end

    def node_pks
      Node.where(resource_id: @resource.id).pluck(:resource_pk)
    end
  end
end
