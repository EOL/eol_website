# Reindex the pages in a batchable, resumable, update-mistakes-only way.
class Page::Reindexer
  def initialize(start_page_id = nil, options = {})
    @start_page_id = start_page_id || 1
    @log = Logger.new(Rails.root.join('public', 'data', 'page_reindex.log'))
    @throttle = options.has_key?(:throttle) ? options[:throttle] : true
    @batch_size = options.has_key?(:batch_size) ? options[:batch_size] : 10
    Searchkick.client_options = {
      retry_on_failure: true,
      transport_options: { request: { timeout: 500 } }
    }
    Searchkick.timeout = 500
  end

  def start
    log('START')
    log("Skipping to page #{@start_page_id}") unless @start_page_id == 1
    current_page_id = @start_page_id
    begin
      Page.search_import.where(['id >= ?', @start_page_id]).find_in_batches(batch_size: 10) do |pages|
        current_page_id = pages.first.id
        begin
          Page.search_index.bulk_update(pages, :search_data)
        rescue Searchkick::ImportError
          log('An update failed, trying index')
          Page.search_index.bulk_index(pages)
        rescue Faraday::ConnectionFailed
          log('Connection failed. You may want to check any other scripts that were running. Retrying...')
          sleep(6) if @throttle
          pages.each do |page|
            begin
              current_page_id = page.id
              page.reindex
              sleep(2) if @throttle # Ouch. Sleeping per page is ugly!
            rescue => e
              log("Indexing page #{page.id} FAILED. Skipping. Error: #{e.message}")
            end
          end
        end
      end
      sleep(2) if @throttle
      log(pages.last.id)
    rescue => e
      log("DIED: restart with ID #{current_page_id}")
      raise(e)
    end
  end

  def log(msg)
    @log.warn("[#{Time.now.strftime('%F %T')}] #{msg}")
  end
end
