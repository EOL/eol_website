class ApiReconciliationController < ApplicationController
  skip_before_action :verify_authenticity_token

  DATA_DIR = Rails.application.root.join('config', 'api_reconciliation')
  QUERY_SCHEMA_PATH = DATA_DIR.join('query_schema.json')
  QUERY_SCHEMA = JSONSchemer.schema(QUERY_SCHEMA_PATH)

  def index
    if params[:queries]
      reconcile(JSON.parse(params[:queries]))
    else
      manifest
    end
  end

  def suggest_properties
    prefix = (params[:prefix] || '').downcase
    cursor = params[:cursor] || 0

    matches = ReconciliationResult::PropertyType::ALL.select do |prop|
      prop.id.starts_with?(prefix) || prop.name.starts_with?(prefix)
    end

    @result = matches[cursor..] || []
    render formats: :json
  end

  def test
    @sample_query = {
      q1: {
        query: 'northern raccoon',
        properties: [
          {
            pid: 'ancestor',
            v: [
              { id: "pages/1642", name: "Mammalia" },  
              "carnivores"
            ]
          },
          {
            pid: 'rank',
            v: 'species'
          }
        ]
      }
    }
  end

  private
  # GET "/" -- service manifest 
  def manifest
    @types = ReconciliationResult::MANIFEST_TYPES
    render :index, formats: :json
  end

  # GET "/?queries=...", POST "/" 
  def reconcile(qs)
    unless QUERY_SCHEMA.valid?(qs)
      first_error = QUERY_SCHEMA.validate(qs).next
      return bad_request("Invalid attribute or value: #{first_error["pointer"]}")
    end

    render json: ReconciliationResult.new(qs).to_h
  end

  def bad_request(msg)
    render json: { error: msg }, status: :bad_request
  end
end

