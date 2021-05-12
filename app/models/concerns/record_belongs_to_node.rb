# Include in an ActiveRecord model to provide 'belongs_to_node' association with an ActiveGraph::Node model.
# Example:
#
# include RecordBelongsToNode
# belongs_to_node 'predicate', 'TermNode'
#
# where the calling class has a predicate_id field in its database table.
module RecordBelongsToNode
  extend ActiveSupport::Concern

  class_methods do
    def belongs_to_node(assoc_name, class_name)
      id_field_name = :"#{assoc_name}_id"
      instance_var_name = :"@#{assoc_name}"
      klass = Object.const_get class_name

      define_method(:"#{assoc_name}=") do |term|
        instance_variable_set(instance_var_name, term)
        self.write_attribute(id_field_name, term&.id) 
      end


      define_method(:"#{id_field_name}=") do |val|
        if val != self.read_attribute(id_field_name)
          self.write_attribute(id_field_name, val)
          instance_variable_set(instance_var_name, nil)
        end
      end

      define_method(assoc_name) do
        assoc_id = self.read_attribute(id_field_name)
        return nil if assoc_id.nil?

        cur_val = instance_variable_get(instance_var_name)
        return cur_val if cur_val

        instance_variable_set(
          instance_var_name,
          klass.find_by(id: Integer(self.read_attribute(id_field_name)))
        )
      end
    end
  end
end
