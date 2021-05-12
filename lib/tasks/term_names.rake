namespace :term_names do
  task refresh_i18n: :environment do
    adapter_name = ENV['PROVIDER'] ? ENV['PROVIDER'] : nil

    if adapter_name.nil?
      puts "No PROVIDER specified. Do you want to run this task for all providers? 'y' to confirm."
      confirm = STDIN.gets.chomp
      raise "Rerun this task with PROVIDER=<provider_name> to specify a provider. Run `rake term_names:list_providers` to view a list of all available providers" unless confirm == "y"
    end
    
    data_file = ENV['DATA_FILE'] ? ENV['DATA_FILE'] : nil

    TermTranslations.refresh(adapter_name, data_file: data_file)
  end

  task list_providers: :environment do
    puts "Available providers:"
    TermTranslations::ADAPTERS.each do |a|
      puts a.name
    end
  end
end

