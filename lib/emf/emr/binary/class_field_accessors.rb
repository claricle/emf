# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      # BinData defines three singleton accessors per field on every instance,
      # which dominates allocation when a metafile holds tens of thousands of
      # records. The accessors depend only on the field's index, so they are
      # defined once per class on first instantiation and shared afterwards.
      module ClassFieldAccessors
        private

        def define_field_accessors
          klass = self.class
          return if klass.instance_variable_get(:@field_accessors_defined)

          get_parameter(:fields).each_with_index do |field, index|
            name = field.name_as_sym
            define_class_accessors(klass, name, index) if name
          end
          klass.instance_variable_set(:@field_accessors_defined, true)
        end

        def define_class_accessors(klass, name, index)
          klass.define_method(name) do
            instantiate_obj_at(index) if @field_objs[index].nil?
            @field_objs[index]
          end
          klass.define_method("#{name}=") do |*vals|
            instantiate_obj_at(index) if @field_objs[index].nil?
            @field_objs[index].assign(*vals)
          end
          klass.define_method("#{name}?") do
            instantiate_obj_at(index) if @field_objs[index].nil?
            include_obj?(@field_objs[index])
          end
        end
      end
    end
  end
end
