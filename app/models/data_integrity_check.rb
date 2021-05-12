class DataIntegrityCheck < ApplicationRecord
  validates_presence_of :type
  validates_presence_of :status

  enum type: {
    circular_relationships: 0,
    same_name_not_synonym: 1,
    term_ancestry_height: 2,
		extinction_status: 3,
    size_wo_units: 4,
    migrated_metadata: 5,
    named_metadata_candidates: 6,
    exclusive_to_clade: 7,
    incompatible_with_clade: 8
  }

  enum status: {
    pending: 0,
    running: 1,
    passed: 2,
    failed: 3,
    errored: 4,
    warned: 5,
  }

  TYPES_TO_CLASSES = {
    circular_relationships: DataIntegrityCheck::CircularRelationships,
    same_name_not_synonym: DataIntegrityCheck::SameNameNotSynonym,
    term_ancestry_height: DataIntegrityCheck::TermAncestryHeight,
		extinction_status: DataIntegrityCheck::ExtinctionStatus,
    size_wo_units: DataIntegrityCheck::SizeWoUnits,
    migrated_metadata: DataIntegrityCheck::MigratedMetadata,
    named_metadata_candidates: DataIntegrityCheck::NamedMetadataCandidates,
    exclusive_to_clade: DataIntegrityCheck::ExclusiveToClade,
    incompatible_with_clade: DataIntegrityCheck::IncompatibleWithClade
  }

  class << self
    # 'type' column is reserved for polymorphic associations unless this is overridden
    def inheritance_column
      'none'
    end

    def all_most_recent
      types.map do |k, v|
        { type: k, record: self.where(type: v).order('created_at DESC').limit(1)&.first }
      end
    end

    def run(type)
      type = type.to_sym
      raise TypeError, "invalid type: #{type}" unless types.symbolize_keys.include?(type)
      pending = self.where(type: type, status: [:pending, :running])&.first

      return false if pending

      new = self.create!(type: type, status: :pending)
      new.background_run_with_delay
      true
    end

    def run_all
      types.keys.each { |k| run(k) }
    end

    def detailed_report(type)
      class_for_type(type).new.detailed_report
    end

    def type_has_detailed_report?(type)
      class_for_type(type).new.respond_to?(:detailed_report)
    end

    def class_for_type(type)
      TYPES_TO_CLASSES[type.to_sym]
    end
  end

  def show_detailed_report?
    klass = self.class.class_for_type(type)
    self.class.type_has_detailed_report?(type) && 
      (
        failed? || 
        (
          passed? &&
          klass.respond_to?(:show_detailed_report_on_pass?) &&
          klass.show_detailed_report_on_pass?
        )
      )
  end

  def background_run
    update!(status: :running, started_at: Time.now)

    begin
      result = self.class.class_for_type(type).new.run
      self.status = result.status
      self.message = result.message
    rescue => e 
      self.status = :errored
      self.message = e.message
      raise e
    ensure
      self.completed_at = Time.now
      save!
    end
  end
  handle_asynchronously :background_run, queue: 'data_integrity'
end
