require "zip"
require "csv"
require "set"

module TraitBank
  class DataDownload
    BATCH_SIZE = 50_000

    attr_reader :count

    class << self
      # options:
      #   - force_new: true -- always create and background_build a UserDownload
      def term_search(term_query, user_id, url, options={})
        count = TraitBank::Search.term_search(
          term_query,
          { count: true },
        ).primary_for_query(term_query)

        UserDownload.create_and_run_if_needed!({
          :user_id => user_id,
          :count => count,
          :search_url => url
        }, term_query, options)
      end

      def path
        return @path if @path
        @path = Rails.public_path.join('data', 'downloads')
        FileUtils.mkdir_p(@path) unless Dir.exist?(path)
        @path
      end
    end

    def initialize(term_query, count, url)
      raise TypeError.new("count cannot be nil") if count.nil?
      @query = term_query
      @options = { per: BATCH_SIZE, meta: true, cache: false }
      @base_filename = "#{Digest::MD5.hexdigest(@query.as_json.to_s)}_#{Time.now.to_i}"
      @url = url
      @count = count
    end

    def background_build
      writer = if @query.taxa?
                 TraitBank::PageDownloadWriter.new(@base_filename, @url)
               elsif @query.record?
                 TraitBank::RecordDownloadWriter.new(@base_filename, @url)
               else
                 raise TypeError.new("unsupported result type: #{@query.result_type}")
               end

      Delayed::Worker.logger.info("beginning data download query for #{@query.to_s}")

      TraitBank::Search.batch_term_search(@query, @options, @count) do |batch|
        writer.write_batch(batch)
      end

      Delayed::Worker.logger.info("finished queries, finalizing")
      filename = writer.finalize
      Delayed::Worker.logger.info("finished data download")

      filename
    end
  end
end
