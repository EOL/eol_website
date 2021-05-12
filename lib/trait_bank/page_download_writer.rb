class TraitBank::PageDownloadWriter
  COLS = {
    "Taxon URL" => -> (page) { TraitBank::DownloadUtils.resource_path(:page, page.id) },
    "Ancestry" => -> (page) { TraitBank::DownloadUtils.ancestry(page) },
    "Scientific Name" => -> (page) { page.scientific_name },
    "Common Name" => -> (page) { page.name === page.scientific_name ? nil : page.name },
    "Author Name" => -> (page) { page.native_node&.preferred_scientific_name&.authorship }
  }

  def initialize(base_filename, url)
    @file_name = "pages_#{base_filename}.tsv"
    @file_path = TraitBank::DataDownload.path.join(@file_name)
    @url = url
  end

  def write_batch(hashes)
    CSV.open(@file_path, "ab", col_sep: "\t") do |csv|
      if !@header_written   
        csv << (COLS.keys << @url)
        @header_written = true
      end
      
      TraitBank::DownloadUtils.page_ids(hashes).in_groups_of(10_000, false) do |page_ids|
        Page.with_hierarchy_no_media.where(:id => page_ids).each do |page|
          row = COLS.collect do |_, lamb|
            lamb[page]
          end
          csv << row
        end
      end
    end
  end

  def finalize
    @file_name
  end
end
