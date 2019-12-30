require "csv"

class DhDataSet < ActiveRecord::Base
  validates_presence_of :dataset_id
  validates_presence_of :name

  TSV_PATH = Rails.application.root.join("db", "seed_data", "dh_data_sets.tsv")

  class << self
    def rebuild_from_tsv
      model_data = []
      CSV.foreach(TSV_PATH, col_sep: "\t", headers: true) do |row|
        model_data << {
          dataset_id: row["datasetID"],
          name: row["name"]
        }
      end

      self.transaction do
        self.destroy_all
        self.create(model_data)
      end
    end
  end
end
