# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://eol.org"
SitemapGenerator::Sitemap.sitemaps_path = "data/sitemap"

SitemapGenerator::Sitemap.create do
  ::I18n.locale = ::I18n.default_locale
  ALT_LOCALES = ::I18n.available_locales.reject { |l| l == ::I18n.default_locale }

  def add_custom(path, alternates = [])
    add(path, lastmod: nil, priority: nil, changefreq: nil, alternates: alternates)
  end

  def add_page_paths(page, path_helper_name)
    path_helper = method(path_helper_name)
    main_path = path_helper.call(page, locale: nil)

    alternates = ALT_LOCALES.collect do |locale|
      {
        href: "#{SitemapGenerator::Sitemap.default_host}/#{path_helper.call(page, locale: locale)}", # Yes, really. See https://github.com/kjvarga/sitemap_generator/issues/343
        lang: locale.to_s
      }
    end

    add_custom(main_path, alternates)
  end


  # /terms/search
  add_custom term_search_path
  
  # CMS Pages

  EditorPage.find_each do |page|
    if page.published_for_locale(::I18n.default_locale).present?
      alternates = ALT_LOCALES.collect do |locale|
        if page.published_for_locale(locale).present?
          { 
            href: "#{SitemapGenerator::Sitemap.default_host}/#{editor_page_path(id: page.name, directory_id: page&.editor_page_directory&.name, locale: locale)}",
            lang: locale
          }
        else
          nil
        end
      end.compact

      add_custom(editor_page_path(id: page.name, directory_id: page&.editor_page_directory&.name, locale: nil), alternates)
    end
  end


  # Pages
  Page.find_each do |page|
    if page.has_data?
      add_page_paths page, :page_path
      add_page_paths page, :page_data_path
      add_page_paths page, :page_maps_path if page.map?
      add_page_paths page, :page_media_path if page.media_count > 0
      add_page_paths page, :page_articles_path if page.articles_count > 0
      #add_page_paths page, :page_names_path
    end
  end
  
  ####################################
  # Instructions from generated file #
  ####################################
  #
  # Put links creation logic here.
  #
  # The root path '/' and sitemap index file are added automatically for you.
  # Links are added to the Sitemap in the order they are specified.
  #
  # Usage: add(path, options={})
  #        (default options are used if you don't specify)
  #
  # Defaults: :priority => 0.5, :changefreq => 'weekly',
  #           :lastmod => Time.now, :host => default_host
  #
  # Examples:
  #
  # Add '/articles'
  #
  #   add articles_path, :priority => 0.7, :changefreq => 'daily'
  #
  # Add all articles:
  #
  #   Article.find_each do |article|
  #     add article_path(article), :lastmod => article.updated_at
  #   end
end
