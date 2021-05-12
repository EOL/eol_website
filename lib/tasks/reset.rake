namespace :reset do
  namespace :full do
    desc 'rebuild the database, re-running migrations. Your gun, your foot: use caution. No imports are performed.'
    task empty: :environment do
      Rake::Task['log:clear'].invoke
      Rake::Task['db:drop'].invoke
      Rake::Task['db:create'].invoke
      Rake::Task['db:migrate'].invoke
      Rake::Task['db:seed'].invoke
      Rake::Task['searchkick:reindex:all'].invoke
      Rails.cache.clear
    end
  end
end
