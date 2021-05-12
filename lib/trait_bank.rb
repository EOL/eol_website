# Abstraction between our traits and the implementation of their storage. ATM, we use neo4j. THE SCHEMA FOR TRAITS CAN
# BE FOUND IN db/neo4j_schema.md ...please read that file before attempting to understand this one. :D
module TraitBank
  class << self
    def query(q, params={})
      response = nil
      clean_q = q.gsub(/^\s+/, "")
      response = ActiveGraph::Base.query(clean_q, params, wrap: false)

      return nil if response.nil?

      response_a = response.to_a # NOTE: you must call to_a since the raw response only allows for iterating through once

      # Map neo4j-ruby-driver response to neography-like response
      cols = response_a.first&.keys || []
      data = response_a.map do |row|
        cols.map do |col|
          col_data = row[col]
          if col_data.respond_to?(:properties)
            { 
              'data' => col_data.properties.stringify_keys,
              'metadata' => { 'id' => col_data.id }
            }
          else
            col_data
          end
        end
      end

      result = { 
        'columns' => cols.map { |c| c.to_s }, # hashrocket for string keys
        'data' => data
      }

      result['plan'] = response.summary.plan.to_h unless response.summary.plan.nil?

      result
    end
  end
end
