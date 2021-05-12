# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_04_15_190402) do

  create_table "active_storage_attachments", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "articles", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin", force: :cascade do |t|
    t.string "guid", null: false
    t.string "resource_pk"
    t.integer "license_id", null: false
    t.integer "language_id"
    t.integer "location_id"
    t.integer "stylesheet_id"
    t.integer "javascript_id"
    t.integer "bibliographic_citation_id"
    t.text "owner"
    t.string "name"
    t.string "source_url", limit: 4096
    t.text "body", limit: 4294967295
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "resource_id"
    t.string "rights_statement", limit: 1024
    t.integer "page_id"
    t.integer "harv_db_id"
    t.index ["guid"], name: "index_articles_on_guid"
    t.index ["harv_db_id"], name: "index_articles_on_harv_db_id"
    t.index ["resource_id"], name: "index_articles_on_resource_id"
  end

  create_table "articles_collected_pages", primary_key: ["collected_page_id", "article_id"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "collected_page_id", null: false
    t.integer "article_id", null: false
    t.integer "position"
    t.index ["collected_page_id"], name: "index_articles_collected_pages_on_collected_page_id"
  end

  create_table "attributions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "content_id"
    t.string "content_type", null: false
    t.integer "role_id", null: false
    t.text "value", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "url", limit: 512
    t.integer "resource_id", null: false
    t.string "resource_pk"
    t.string "content_resource_fk", null: false
    t.index ["content_type", "content_id"], name: "index_attributions_on_content_type_and_content_id"
    t.index ["resource_id"], name: "index_attributions_on_resource_id"
  end

  create_table "bibliographic_citations", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "resource_id", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "harv_db_id"
    t.index ["harv_db_id"], name: "index_bibliographic_citations_on_harv_db_id"
  end

  create_table "changes", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "user_id"
    t.integer "page_id"
    t.integer "activity_id"
    t.string "activity_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["page_id"], name: "index_changes_on_page_id"
    t.index ["user_id"], name: "index_changes_on_user_id"
  end

  create_table "collected_pages", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "collection_id", null: false
    t.integer "page_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "annotation"
    t.index ["collection_id", "page_id"], name: "enforce_unique_pairs", unique: true
    t.index ["collection_id"], name: "index_collected_pages_on_collection_id"
    t.index ["page_id"], name: "index_collected_pages_on_page_id"
  end

  create_table "collected_pages_links", primary_key: ["collected_page_id", "link_id"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "collected_page_id", null: false
    t.integer "link_id", null: false
    t.integer "position"
    t.index ["collected_page_id"], name: "index_collected_pages_links_on_collected_page_id"
  end

  create_table "collected_pages_media", primary_key: ["collected_page_id", "medium_id"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "collected_page_id", null: false
    t.integer "medium_id", null: false
    t.integer "position"
    t.index ["collected_page_id"], name: "index_collected_pages_media_on_collected_page_id"
  end

  create_table "collectings", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "user_id"
    t.integer "collection_id"
    t.integer "action"
    t.integer "content_id"
    t.string "content_type"
    t.integer "page_id"
    t.integer "associated_collection_id"
    t.string "changed_field"
    t.text "changed_from"
    t.text "changed_to"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["collection_id"], name: "index_collectings_on_collection_id"
    t.index ["content_type", "content_id"], name: "index_collectings_on_content_type_and_content_id"
    t.index ["page_id"], name: "index_collectings_on_page_id"
    t.index ["user_id"], name: "index_collectings_on_user_id"
  end

  create_table "collection_associations", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "collection_id", null: false
    t.integer "position"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "associated_id"
    t.text "annotation"
    t.index ["collection_id"], name: "index_collection_associations_on_collection_id"
  end

  create_table "collections", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "collected_pages_count", default: 0
    t.integer "collection_associations_count", default: 0
    t.integer "collection_type", default: 0
    t.integer "default_sort", default: 0
    t.integer "v2_id"
  end

  create_table "collections_users", primary_key: ["user_id", "collection_id"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "collection_id", null: false
    t.boolean "is_manager", default: false, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["collection_id"], name: "index_collections_users_on_collection_id"
    t.index ["user_id"], name: "index_collections_users_on_user_id"
  end

  create_table "content_edits", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "user_id_id"
    t.integer "page_content_id"
    t.string "changed_field"
    t.text "changed_from"
    t.text "changed_to"
    t.text "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "content_repositions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "user_id_id"
    t.integer "page_content_id"
    t.integer "changed_from"
    t.integer "changed_to"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "content_sections", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "section_id", null: false
    t.integer "content_id", null: false
    t.string "content_type", null: false
    t.integer "resource_id", null: false
    t.index ["content_type", "content_id"], name: "index_content_sections_on_content_type_and_content_id"
  end

  create_table "crono_jobs", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "job_id", null: false
    t.text "log", limit: 4294967295
    t.datetime "last_performed_at"
    t.boolean "healthy"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_crono_jobs_on_job_id", unique: true
  end

  create_table "curations", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "page_content_id", null: false
    t.integer "trust", default: 0, null: false
    t.boolean "is_incorrect", default: false, null: false
    t.boolean "is_misidentified", default: false, null: false
    t.boolean "is_hidden", default: false, null: false
    t.boolean "is_duplicate", default: false, null: false
    t.boolean "is_low_quality", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "old_trust", default: 0, null: false
    t.boolean "old_is_incorrect", default: false, null: false
    t.boolean "old_is_misidentified", default: false, null: false
    t.boolean "old_is_hidden", default: false, null: false
    t.boolean "old_is_duplicate", default: false, null: false
    t.boolean "old_is_low_quality", default: false, null: false
    t.text "comment"
  end

  create_table "data_integrity_checks", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "type"
    t.integer "status"
    t.text "message"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "delayed_jobs", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "dh_data_sets", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "dataset_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "editor_page_contents", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.integer "status"
    t.integer "editor_page_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale"
    t.index ["editor_page_id"], name: "index_editor_page_contents_on_editor_page_id"
  end

  create_table "editor_page_directories", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_editor_page_directories_on_name"
  end

  create_table "editor_pages", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.integer "editor_page_directory_id"
    t.index ["slug"], name: "index_editor_pages_on_slug", unique: true
  end

  create_table "friendly_id_slugs", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true, length: { slug: 70, scope: 70 }
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type", length: { slug: 140 }
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "gbif_downloads", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "user_id"
    t.integer "term_query_id"
    t.string "status_url"
    t.string "result_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status"
    t.timestamp "completed_at"
    t.text "error_response"
    t.timestamp "processing_since"
    t.integer "response_code"
  end

  create_table "hidden_media", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "resource_pk"
    t.integer "resource_id"
    t.integer "medium_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["medium_id"], name: "index_hidden_media_on_medium_id"
  end

  create_table "home_page_feed_items", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "img_url"
    t.string "link_url"
    t.string "label"
    t.text "desc"
    t.integer "home_page_feed_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "feed_version"
    t.integer "page_id"
    t.index ["home_page_feed_id", "feed_version"], name: "index_home_page_feed_items_on_home_page_feed_id_and_feed_version"
  end

  create_table "home_page_feeds", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.integer "field_mask"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "published_version", default: 0
  end

  create_table "identifiers", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "resource_id", null: false
    t.integer "node_id"
    t.string "node_resource_pk", null: false
    t.string "identifier"
    t.integer "harv_db_id"
    t.index ["node_id"], name: "index_identifiers_on_node_id"
    t.index ["node_resource_pk"], name: "index_identifiers_on_node_resource_pk"
    t.index ["resource_id"], name: "index_identifiers_on_resource_id"
  end

  create_table "image_info", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "resource_id", null: false
    t.integer "medium_id", null: false
    t.string "original_size", limit: 12, null: false
    t.string "large_size", limit: 12
    t.string "medium_size", limit: 12
    t.string "small_size", limit: 12
    t.decimal "crop_x", precision: 5, scale: 2
    t.decimal "crop_y", precision: 5, scale: 2
    t.decimal "crop_w", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "resource_pk"
    t.integer "harv_db_id"
    t.index ["harv_db_id"], name: "index_image_info_on_harv_db_id"
    t.index ["medium_id"], name: "index_image_info_on_medium_id"
    t.index ["resource_id"], name: "index_image_info_on_resource_id"
    t.index ["resource_pk"], name: "index_image_info_on_resource_pk"
  end

  create_table "import_events", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "import_log_id", null: false
    t.integer "cat"
    t.text "body"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "import_logs", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "resource_id", null: false
    t.datetime "completed_at"
    t.datetime "failed_at"
    t.string "status"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "import_runs", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "javascripts", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "resource_id", null: false
    t.string "filename", null: false
  end

  create_table "languages", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "code", limit: 12, null: false
    t.boolean "can_browse_site", default: false, null: false
    t.integer "locale_id"
    t.index ["code"], name: "index_languages_on_code"
    t.index ["locale_id"], name: "index_languages_on_locale_id"
  end

  create_table "license_group_includes", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "this_id"
    t.integer "includes_id"
    t.index ["includes_id"], name: "index_license_group_includes_on_includes_id"
    t.index ["this_id", "includes_id"], name: "index_license_group_includes_on_this_id_and_includes_id", unique: true
    t.index ["this_id"], name: "index_license_group_includes_on_this_id"
  end

  create_table "license_groups", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "key"
    t.index ["key"], name: "index_license_groups_on_key"
  end

  create_table "license_groups_licenses", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "license_id"
    t.integer "license_group_id"
    t.index ["license_group_id"], name: "index_license_groups_licenses_on_license_group_id"
    t.index ["license_id", "license_group_id"], name: "index_license_groups_licenses_on_license_id_and_license_group_id", unique: true
    t.index ["license_id"], name: "index_license_groups_licenses_on_license_id"
  end

  create_table "licenses", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "source_url"
    t.string "icon_url"
    t.boolean "can_be_chosen_by_partners", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "links", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "guid", null: false
    t.string "resource_pk"
    t.integer "language_id"
    t.string "name"
    t.string "source_url", limit: 4096
    t.text "description", null: false
    t.string "icon_url", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "resource_id"
    t.string "rights_statement", limit: 1024
    t.integer "page_id"
    t.index ["guid"], name: "index_links_on_guid"
  end

  create_table "locales", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "locations", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "resource_id", null: false
    t.string "location"
    t.decimal "longitude", precision: 64, scale: 12
    t.decimal "latitude", precision: 64, scale: 12
    t.decimal "altitude", precision: 64, scale: 12
    t.text "spatial_location"
  end

  create_table "media", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "guid", null: false
    t.string "resource_pk"
    t.integer "subclass", default: 0, null: false
    t.integer "format", default: 0, null: false
    t.integer "license_id", null: false
    t.integer "language_id"
    t.integer "location_id"
    t.integer "stylesheet_id"
    t.integer "javascript_id"
    t.integer "bibliographic_citation_id"
    t.text "owner"
    t.string "name"
    t.string "source_url", limit: 4096
    t.text "description"
    t.string "base_url", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "unmodified_url"
    t.string "source_page_url", limit: 4096
    t.integer "resource_id", null: false
    t.string "rights_statement", limit: 1024
    t.integer "page_id"
    t.string "usage_statement"
    t.integer "harv_db_id"
    t.index ["guid"], name: "index_media_on_guid"
    t.index ["harv_db_id"], name: "index_media_on_harv_db_id"
    t.index ["resource_id"], name: "index_media_on_resource_id"
    t.index ["resource_pk"], name: "index_media_on_resource_pk"
    t.index ["subclass"], name: "index_media_on_subclass"
  end

  create_table "node_ancestors", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "resource_id", null: false
    t.integer "node_id"
    t.integer "ancestor_id"
    t.string "node_resource_pk"
    t.string "ancestor_resource_pk"
    t.integer "depth"
    t.integer "harv_db_id"
    t.index ["ancestor_id"], name: "index_node_ancestors_on_ancestor_id"
    t.index ["ancestor_resource_pk"], name: "index_node_ancestors_on_ancestor_resource_pk"
    t.index ["harv_db_id"], name: "index_node_ancestors_on_harv_db_id"
    t.index ["node_id"], name: "index_node_ancestors_on_node_id"
    t.index ["node_resource_pk"], name: "index_node_ancestors_on_node_resource_pk"
    t.index ["resource_id"], name: "index_node_ancestors_on_resource_id"
  end

  create_table "nodes", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "resource_id", null: false
    t.integer "page_id"
    t.integer "rank_id"
    t.integer "parent_id"
    t.string "scientific_name"
    t.string "canonical_form"
    t.string "resource_pk", null: false
    t.string "source_url", limit: 4096
    t.boolean "is_hidden", default: false, null: false
    t.boolean "in_unmapped_area", default: false, null: false
    t.integer "children_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "has_breadcrumb", default: true
    t.string "parent_resource_pk"
    t.integer "landmark", default: 0
    t.integer "harv_db_id"
    t.index ["harv_db_id"], name: "index_nodes_on_harv_db_id"
    t.index ["page_id"], name: "index_nodes_on_page_id"
    t.index ["parent_id"], name: "index_nodes_on_parent_id"
    t.index ["resource_id"], name: "index_nodes_on_resource_id"
    t.index ["resource_pk"], name: "index_nodes_on_resource_pk"
  end

  create_table "occurrence_maps", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "resource_id"
    t.integer "page_id"
    t.string "url", limit: 256
    t.index ["page_id"], name: "index_occurrence_maps_on_page_id"
  end

  create_table "open_authentications", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["user_id"], name: "index_open_authentications_on_user_id"
  end

  create_table "ordered_fallback_locales", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "locale_id"
    t.integer "fallback_locale_id"
    t.integer "position"
  end

  create_table "page_contents", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "page_id", null: false
    t.integer "resource_id", null: false
    t.integer "source_page_id", null: false
    t.integer "position"
    t.integer "content_id", null: false
    t.string "content_type", null: false
    t.integer "association_added_by_user_id"
    t.integer "trust", default: 1, null: false
    t.boolean "is_incorrect", default: false, null: false
    t.boolean "is_misidentified", default: false, null: false
    t.boolean "is_hidden", default: false, null: false
    t.boolean "is_duplicate", default: false, null: false
    t.boolean "is_low_quality", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "content_subclass", default: 0
    t.index ["content_id"], name: "index_page_contents_on_content_id"
    t.index ["content_type", "content_id"], name: "index_page_contents_on_content_type_and_content_id"
    t.index ["page_id", "content_type", "content_id"], name: "effective_pk", unique: true
    t.index ["page_id", "content_type", "position"], name: "contents_for_page_index"
    t.index ["page_id", "content_type"], name: "page_content_by_type_index"
    t.index ["page_id", "position"], name: "page_id_by_position"
    t.index ["page_id"], name: "index_page_contents_on_page_id"
    t.index ["source_page_id"], name: "index_page_contents_on_source_page_id"
  end

  create_table "page_desc_infos", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "page_id"
    t.integer "species_count"
    t.integer "genus_count"
    t.integer "family_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "page_icons", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "page_id"
    t.integer "user_id"
    t.integer "medium_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["medium_id"], name: "index_page_icons_on_medium_id"
    t.index ["page_id"], name: "index_page_icons_on_page_id"
    t.index ["user_id"], name: "index_page_icons_on_user_id"
  end

  create_table "page_redirects", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "redirect_to_id"
  end

  create_table "pages", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "native_node_id"
    t.integer "moved_to_page_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "page_contents_count", default: 0, null: false
    t.integer "media_count", default: 0, null: false
    t.integer "articles_count", default: 0, null: false
    t.integer "links_count", default: 0, null: false
    t.integer "maps_count", default: 0, null: false
    t.integer "nodes_count", default: 0, null: false
    t.integer "vernaculars_count", default: 0, null: false
    t.integer "scientific_names_count", default: 0, null: false
    t.integer "referents_count", default: 0, null: false
    t.integer "species_count", default: 0, null: false
    t.boolean "is_extinct", default: false, null: false
    t.boolean "is_marine", default: false, null: false
    t.boolean "has_checked_extinct", default: false, null: false
    t.boolean "has_checked_marine", default: false, null: false
    t.string "iucn_status"
    t.string "trophic_strategy"
    t.string "habitat"
    t.integer "page_richness"
    t.integer "medium_id"
    t.index ["native_node_id"], name: "index_pages_on_native_node_id"
  end

  create_table "pages_referents", primary_key: ["page_id", "referent_id"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "page_id", null: false
    t.integer "referent_id", null: false
    t.integer "position"
    t.index ["page_id"], name: "index_pages_referents_on_page_id"
  end

  create_table "partners", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "abbr", limit: 16
    t.string "short_name", null: false
    t.string "homepage_url"
    t.text "description"
    t.text "notes"
    t.text "links_json"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "repository_id"
  end

  create_table "partners_users", primary_key: ["partner_id", "user_id"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "partner_id", null: false
    t.integer "user_id", null: false
  end

  create_table "processes", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "resource_id", null: false
    t.string "error"
    t.text "trace"
    t.datetime "created_at"
    t.datetime "stopped_at"
  end

  create_table "ranks", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.integer "treat_as"
  end

  create_table "references", primary_key: ["parent_type", "parent_id", "referent_id"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "parent_id", null: false
    t.integer "referent_id", null: false
    t.string "parent_type", default: "Article", null: false
    t.integer "resource_id", null: false
    t.integer "id", null: false
    t.index ["parent_type", "parent_id"], name: "references_by_parent_index"
    t.index ["resource_id"], name: "index_references_on_resource_id"
  end

  create_table "referents", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "resource_id", null: false
    t.integer "harv_db_id"
    t.index ["harv_db_id"], name: "index_referents_on_harv_db_id"
    t.index ["resource_id"], name: "index_referents_on_resource_id"
  end

  create_table "resource_preferences", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "resource_id", null: false
    t.string "class_name", null: false
    t.integer "position", null: false
    t.index ["class_name"], name: "index_resource_preferences_on_class_name"
  end

  create_table "resources", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "partner_id", null: false
    t.string "name", null: false
    t.string "url"
    t.text "description"
    t.text "notes"
    t.integer "nodes_count"
    t.boolean "is_browsable", default: false, null: false
    t.boolean "has_duplicate_nodes", default: false, null: false
    t.string "node_source_url_template", limit: 4096
    t.datetime "last_published_at"
    t.integer "last_publish_seconds"
    t.integer "dataset_license_id"
    t.string "dataset_rights_holder"
    t.string "dataset_rights_statement"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "abbr"
    t.integer "repository_id"
    t.boolean "classification", default: false
    t.index ["partner_id"], name: "index_resources_on_partner_id"
  end

  create_table "roles", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "scientific_names", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "node_id", null: false
    t.integer "page_id", null: false
    t.string "italicized", null: false
    t.string "canonical_form", null: false
    t.integer "taxonomic_status_id", null: false
    t.boolean "is_preferred", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "resource_id"
    t.string "node_resource_pk"
    t.string "source_reference"
    t.string "genus"
    t.string "specific_epithet"
    t.string "infraspecific_epithet"
    t.string "infrageneric_epithet"
    t.string "uninomial"
    t.text "verbatim"
    t.text "authorship"
    t.text "publication"
    t.text "remarks"
    t.integer "parse_quality"
    t.integer "year"
    t.boolean "hybrid"
    t.boolean "surrogate"
    t.boolean "virus"
    t.text "attribution"
    t.integer "harv_db_id"
    t.text "dataset_name"
    t.text "name_according_to"
    t.index ["canonical_form"], name: "index_scientific_names_on_canonical_form"
    t.index ["harv_db_id"], name: "index_scientific_names_on_harv_db_id"
    t.index ["node_id"], name: "index_scientific_names_on_node_id"
    t.index ["page_id"], name: "index_scientific_names_on_page_id"
    t.index ["resource_id"], name: "index_scientific_names_on_resource_id"
  end

  create_table "search_suggestions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "page_id"
    t.integer "synonym_of_id"
    t.string "match", null: false
    t.string "object_term"
    t.string "path"
    t.text "wkt_string"
  end

  create_table "section_parents", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "section_id"
    t.integer "parent_id"
  end

  create_table "sections", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "position"
    t.string "name", null: false
  end

  create_table "seo_meta", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "seo_meta_id"
    t.string "seo_meta_type"
    t.string "browser_title"
    t.text "meta_description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["id"], name: "index_seo_meta_on_id"
    t.index ["seo_meta_id", "seo_meta_type"], name: "id_type_index_on_seo_meta"
  end

  create_table "stylesheets", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "resource_id", null: false
    t.string "filename", null: false
  end

  create_table "tasks", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "process_id"
    t.string "method"
    t.text "info"
    t.string "progress"
    t.string "summary"
    t.datetime "created_at"
    t.datetime "exited_at"
  end

  create_table "taxon_remarks", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "node_id"
    t.text "body"
    t.index ["node_id"], name: "index_taxon_remarks_on_node_id"
  end

  create_table "taxonomic_statuses", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "is_preferred", default: false, null: false
    t.boolean "is_problematic", default: false, null: false
    t.boolean "is_alternative_preferred", default: false, null: false
    t.boolean "can_merge", default: true, null: false
  end

  create_table "term_queries", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "clade_id"
    t.integer "result_type"
    t.string "digest"
    t.index ["digest"], name: "index_term_queries_on_digest"
  end

  create_table "term_query_filters", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "term_query_id"
    t.string "pred_uri"
    t.string "obj_uri"
    t.string "units_uri"
    t.float "num_val1"
    t.float "num_val2"
    t.integer "op"
    t.string "sex_uri"
    t.string "lifestage_uri"
    t.string "statistical_method_uri"
    t.integer "resource_id"
    t.integer "obj_clade_id"
    t.integer "predicate_id"
    t.integer "object_term_id"
    t.integer "units_term_id"
    t.integer "sex_term_id"
    t.integer "lifestage_term_id"
    t.integer "statistical_method_term_id"
    t.index ["term_query_id"], name: "index_term_query_filters_on_term_query_id"
  end

  create_table "term_query_numeric_filters", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.float "value"
    t.integer "op"
    t.string "units_uri"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pred_uri"
    t.integer "term_query_id"
  end

  create_table "term_query_object_term_filters", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "obj_uri"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pred_uri"
    t.integer "term_query_id"
  end

  create_table "term_query_predicate_filters", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "term_query_id"
    t.string "pred_uri"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["term_query_id"], name: "index_term_query_predicate_filters_on_term_query_id"
  end

  create_table "term_query_range_filters", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.float "from_value"
    t.float "to_value"
    t.string "units_uri"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pred_uri"
    t.integer "term_query_id"
  end

  create_table "user_download_errors", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "message"
    t.text "backtrace"
    t.integer "user_download_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_download_id"], name: "index_user_download_errors_on_user_download_id"
  end

  create_table "user_downloads", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "user_id"
    t.integer "count"
    t.string "filename"
    t.datetime "completed_at"
    t.datetime "expired_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "term_query_id"
    t.text "search_url"
    t.integer "status", default: 0
    t.datetime "processing_since"
    t.integer "duplication"
    t.integer "version"
    t.index ["term_query_id"], name: "index_user_downloads_on_term_query_id"
  end

  create_table "users", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.string "email", default: ""
    t.string "encrypted_password", default: ""
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.string "name"
    t.boolean "active"
    t.string "api_key"
    t.string "tag_line"
    t.text "bio"
    t.string "provider"
    t.string "uid"
    t.datetime "deleted_at"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.integer "role", default: 10, null: false
    t.integer "language_id"
    t.boolean "disable_email_notifications"
    t.text "v2_ids"
    t.integer "curator_level"
    t.integer "breadcrumb_type"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "v2_users", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "user_id", null: false
  end

  create_table "vernacular_preferences", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "vernacular_id", null: false
    t.integer "resource_id", null: false
    t.integer "language_id"
    t.integer "page_id"
    t.integer "overridden_by_id"
    t.string "string", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["page_id", "language_id"], name: "override_lookup"
    t.index ["resource_id"], name: "index_vernacular_preferences_on_resource_id"
    t.index ["vernacular_id"], name: "index_vernacular_preferences_on_vernacular_id"
  end

  create_table "vernaculars", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin", force: :cascade do |t|
    t.string "string"
    t.integer "language_id", null: false
    t.integer "node_id", null: false
    t.integer "page_id", null: false
    t.boolean "is_preferred", default: false, null: false
    t.boolean "is_preferred_by_resource", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "trust", default: 0, null: false
    t.string "node_resource_pk"
    t.string "locality"
    t.text "remarks"
    t.text "source"
    t.integer "resource_id"
    t.integer "harv_db_id"
    t.integer "user_id"
    t.index ["harv_db_id"], name: "index_vernaculars_on_harv_db_id"
    t.index ["node_id"], name: "index_vernaculars_on_node_id"
    t.index ["page_id", "language_id"], name: "preferred_names_index"
    t.index ["page_id"], name: "index_vernaculars_on_page_id"
    t.index ["resource_id"], name: "index_vernaculars_on_resource_id"
  end

  create_table "warnings", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci", force: :cascade do |t|
    t.integer "resource_id", null: false
    t.string "message"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
end
