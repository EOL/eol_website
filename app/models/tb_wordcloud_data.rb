require "fileutils"

class TbWordcloudData
  URI_FILE_PATH = Rails.root.join('config', 'tb_wordcloud', 'uris.txt')
  DATA_FILE_PATH = Rails.root.join('data', 'top_pred_counts.json')
  PRED_LIMIT = 50

  class << self
    def generate_file
      validate_uris
      pred_count_json = uris_for_query.map do |uri|
        q = <<~CYPHER
          MATCH (pred:Term{uri: $uri })
          OPTIONAL MATCH (page:Page)-[:trait|:inferred_trait]->(trait:Trait)-[:predicate]->(pred)
          WITH pred.uri AS uri, pred.name AS name, count(DISTINCT page) as page_count
          RETURN name, uri, page_count
        CYPHER

        puts "Running query for uri #{uri}"
        result = ActiveGraph::Base.query(q, uri: uri)
        raise "Failed to get a result for uri #{uri}" unless result.any?
        first = result.first

        {
          uri: first[:uri],
          name: first[:name],
          count:  first[:page_count]
        }
      end.reject { |a| a[:count] == 0 }.sort { |a, b| b[:count] <=> a[:count] }.to_json

      puts "Finished queries"

      file_path = DATA_FILE_PATH
      backup_path = "#{DATA_FILE_PATH}.bak"

      puts "Checking for existing data file at #{file_path}"

      if File.exist?(file_path)
        puts "Copying existing data file to #{backup_path}"
        FileUtils.copy_file(file_path, backup_path)
      else
        puts "No existing file found"
      end

      puts "Writing data to #{file_path}"
      File.open(file_path, "w") do |f|
        f.write(pred_count_json)
      end

      puts "Done!"
    end

    def data
      if !@data
        if File.exist?(DATA_FILE_PATH)
          @data = JSON.parse(File.read(DATA_FILE_PATH))
        else
          raise TypeError.new("TraitBank wordcloud file doesn't exist: #{DATA_FILE_PATH}. Run TbWordCloudData.generate_file to generate.")
        end
      end

      return @data
    end

    def validate_uris
      puts "Validating uris against EolTerms"

      uris_for_query.each do |uri|
        raise "Invalid uri: #{uri}" unless EolTerms.includes_uri?(uri)
      end

      puts "All uris are valid"
    end

    private

    def uris_for_query
      @uris_for_query ||= IO.readlines(URI_FILE_PATH, chomp: true)
    end
  end 
end

