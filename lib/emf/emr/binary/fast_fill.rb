# frozen_string_literal: true

module Emf
  module Emr
    module Binary
      # Copy of an instantiated BinData struct tree. BinData builds each lazy
      # field by cloning a prototype, which dominates `new` plus first access
      # for a record; cloning the finished tree gives the same objects (same
      # classes, params, nil values, parent links) at a fraction of the cost.
      # Relies on BinData::Struct#@field_objs and Base#@parent, as
      # Emf::Binary::ClassFieldAccessors already does for @field_objs.
      module WireCopy
        module_function

        # Drops a cached BinData lazy evaluator so a template copy does not
        # evaluate parameters against the template.
        def forget_evaluator(object)
          return unless object.instance_variable_defined?(:@lazy_evaluator)

          object.send(:remove_instance_variable, :@lazy_evaluator)
        end

        def call(template, parent)
          copy = template.dup
          copy.instance_variable_set(:@parent, parent)
          objs = template.instance_variable_get(:@field_objs).map do |field|
            field.respond_to?(:field_names) ? call(field, copy) : leaf(field, copy)
          end
          copy.instance_variable_set(:@field_objs, objs)
          copy
        end

        # Field name to position in @field_objs.
        def slots(sample)
          fields = sample.send(:get_parameter, :fields)
          fields.each_with_index.with_object({}) do |(field, index), slots|
            slots[field.name_as_sym] = index if field.name_as_sym
          end.freeze
        end

        # A copy of the template with each given field assigned, as BinData's
        # constructor does after instantiating the fields one by one. BinData
        # skips nil values in a constructor hash, so does this.
        def build(template, slots, attrs)
          return unless attrs.each_key.all? { |name| slots.key?(name) }

          wire = call(template, nil)
          objs = wire.instance_variable_get(:@field_objs)
          attrs.each { |name, value| assign(objs[slots[name]], value) unless value.nil? }
          wire
        end

        STRUCT_SLOTS = {}.compare_by_identity
        private_constant :STRUCT_SLOTS

        # Same result as `target.assign(value)` on a fresh (clear) target. A
        # nested struct takes a symbol-keyed Hash of its own fields or a struct
        # of exactly its class leaf by leaf, skipping BinData's clear and
        # stringified-hash round trip; any other value goes through BinData.
        def assign(target, value)
          return target.assign(value) unless target.respond_to?(:field_names)

          slots = (STRUCT_SLOTS[target.class] ||= slots(target))
          if value.instance_of?(Hash) && value.each_key.all? { |name| slots.key?(name) }
            objs = target.instance_variable_get(:@field_objs)
            value.each { |name, leaf| assign(objs[slots[name]], leaf) unless leaf.nil? }
          elsif value.instance_of?(target.class)
            objs = target.instance_variable_get(:@field_objs)
            slots.each_value { |index| assign(objs[index], source_field(value, index)) }
          else
            target.assign(value)
          end
        end

        def source_field(struct, index)
          struct.send(:instantiate_obj_at, index)
          struct.instance_variable_get(:@field_objs)[index]
        end

        # BinData extends each array with its initial_length behavior; dup
        # would drop that singleton module, clone keeps it.
        def leaf(leaf, parent)
          copy = leaf.is_a?(BinData::Array) ? leaf.clone : leaf.dup
          copy.instance_variable_set(:@parent, parent)
          copy
        end
      end

      # Source of a FastFill's generated `build_attrs`, same result as
      # WireCopy.build: every known key is fetched into a local first (an
      # unknown key makes the count disagree and returns nil before any
      # copy), then each non-nil value is assigned straight into the copy.
      # A nested struct given as the same struct class is copied leaf by
      # leaf inline; any other value goes through WireCopy.assign.
      class BuildSource
        ABSENT = Object.new.freeze

        def initialize(template, slots)
          @struct_classes = []
          @templates = []
          @copy = copy_lines(template, "wire", "nil")
          objs = template.instance_variable_get(:@field_objs)
          @fetches = []
          @counts = []
          @assigns = []
          slots.each_with_index do |(name, index), position|
            value = "v#{position}"
            @fetches << "#{value} = attrs.fetch(:#{name}, ABSENT)"
            @counts << "seen += 1 unless ABSENT.equal?(#{value})"
            @assigns << assign(objs[index], index, value)
          end
        end

        # A module holding `build_attrs` and the constants it refers to.
        def to_module
          source = to_s
          classes = @struct_classes
          Module.new.tap do |mod|
            mod.const_set(:STRUCTS, classes.freeze)
            mod.const_set(:ABSENT, ABSENT)
            mod.const_set(:TEMPLATES, @templates.freeze)
            mod.module_eval(source, __FILE__, __LINE__)
          end
        end

        def to_s
          <<~RUBY
            def build_attrs(attrs)
              #{@fetches.join("\n  ")}
              seen = 0
              #{@counts.join("\n  ")}
              return unless seen == attrs.size
              #{@copy.join("\n  ")}
              objs = wire.instance_variable_get(:@field_objs)
              #{@assigns.join("\n  ")}
              wire
            end
          RUBY
        end

        private

        # Straight-line twin of WireCopy.call: dup of every struct and leaf of
        # the template, parents pointed into the copy, field lists rebuilt.
        def copy_lines(struct, var, parent)
          @templates << struct
          lines = ["#{var} = TEMPLATES[#{@templates.size - 1}].dup", "#{var}.instance_variable_set(:@parent, #{parent})"]
          children = struct.instance_variable_get(:@field_objs).each_with_index.map do |field, index|
            child = "#{var}_#{index}"
            lines.concat(field.respond_to?(:field_names) ? copy_lines(field, child, var) : leaf_lines(field, child, var))
            child
          end
          lines << "#{var}.instance_variable_set(:@field_objs, [#{children.join(', ')}])"
        end

        def leaf_lines(field, var, parent)
          @templates << field
          copier = field.is_a?(BinData::Array) ? "clone" : "dup"
          ["#{var} = TEMPLATES[#{@templates.size - 1}].#{copier}", "#{var}.instance_variable_set(:@parent, #{parent})"]
        end

        def assign(field, index, value)
          present = "unless #{value}.nil? || ABSENT.equal?(#{value})"
          return "objs[#{index}].assign(#{value}) #{present}" unless field.respond_to?(:field_names)

          @struct_classes << field.class
          klass = "STRUCTS[#{@struct_classes.size - 1}]"
          <<~RUBY.chomp
            #{present}
              if #{value}.instance_of?(#{klass})
                t1 = objs[#{index}].instance_variable_get(:@field_objs)
                #{struct_copy(field, 1, value).join("\n    ")}
              else
                Emf::Emr::Binary::WireCopy.assign(objs[#{index}], #{value})
              end
            end
          RUBY
        end

        # Leaf-by-leaf assignments from `source` into the target field list `t<depth>`.
        def struct_copy(struct, depth, source)
          fields = struct.instance_variable_get(:@field_objs)
          WireCopy.slots(struct).flat_map do |name, index|
            field = fields[index]
            if field.respond_to?(:field_names)
              ["t#{depth + 1} = t#{depth}[#{index}].instance_variable_get(:@field_objs)",
               *struct_copy(field, depth + 1, "#{source}.#{name}")]
            else
              ["t#{depth}[#{index}].assign(#{source}.#{name})"]
            end
          end
        end
      end

      # Self-check for a FastFill, run once when the filler is built. Proves on
      # the installed BinData that a template copy is a faithful, independent
      # twin of a fresh instance and that the generated reader and writer agree
      # with BinData's own on a record with distinct leaf values.
      module SelfCheck
        # Raised when BinData's internals do not behave as WireCopy assumes.
        class Unverified < StandardError; end

        BINDATA_WRITER = BinData::Base.instance_method(:to_binary_s)
        private_constant :BINDATA_WRITER

        def self.included(base)
          base.extend(ClassMethods)
        end

        # Class-level entry point.
        module ClassMethods
          # A verified filler for the class, or nil when the class cannot be
          # filled safely: construction or the self-check raised or disagreed
          # with plain BinData. Callers treat nil as "use BinData".
          def guarded(klass)
            filler = new(klass)
            filler.verify!
            filler
          rescue StandardError
            nil
          end
        end

        # Raises Unverified (or whatever the internals raise) on any difference.
        def verify!
          fresh = @wire_class.new
          verify_template(fresh)
          verify_independent
          sample = verification_record
          bytes = bindata_bytes(sample) + verification_tail
          verify_read(bytes)
          verify_write(sample)
          verify_build
          self
        end

        private

        def unverified!(what)
          raise Unverified, "#{@wire_class}: #{what}"
        end

        def bindata_bytes(wire)
          BINDATA_WRITER.bind_call(wire)
        end

        def verify_template(fresh)
          copy = WireCopy.call(@template, nil)
          same = copy.instance_of?(@wire_class) && copy.snapshot == fresh.snapshot &&
                 copy.num_bytes == fresh.num_bytes && bindata_bytes(copy) == bindata_bytes(fresh)
          unverified!("template copy differs from a fresh instance") unless same
          unverified!("slots do not cover the field list") unless @slots.keys == fresh.field_names
        end

        # No object of a copy is shared with the template, and every parent
        # link points into the copy.
        def verify_independent
          copy = WireCopy.call(@template, nil)
          shared = tree_objects(@template).map(&:object_id) & tree_objects(copy).map(&:object_id)
          unverified!("copy shares objects with the template") unless shared.empty?
          unverified!("copy parent links are wrong") unless parents_consistent?(copy)
          edit_leaf(copy)
          again = WireCopy.call(@template, nil)
          unverified!("editing a copy changed the template") unless again.snapshot == @wire_class.new.snapshot
        end

        def tree_objects(struct)
          objs = struct.instance_variable_get(:@field_objs)
          raise Unverified, "no field objects" unless objs.is_a?(::Array)

          [struct] + objs.flat_map { |obj| obj.respond_to?(:field_names) ? tree_objects(obj) : [obj] }
        end

        def parents_consistent?(struct)
          struct.instance_variable_get(:@field_objs).all? do |obj|
            obj.instance_variable_get(:@parent).equal?(struct) &&
              (!obj.respond_to?(:field_names) || parents_consistent?(obj))
          end
        end

        def edit_leaf(wire)
          path, field = @leaves.first
          target = path.inject(wire) { |obj, name| obj.public_send(name) }
          float?(field) ? target.assign_bits(1) : target.assign(1)
        end

        # A record with a distinct small value in every leaf.
        def verification_record
          wire = @wire_class.new
          @leaves.each_with_index do |(path, field), index|
            target = path.inject(wire) { |obj, name| obj.public_send(name) }
            float?(field) ? target.assign_bits(index + 1) : target.assign(index + 1)
          end
          wire
        end

        def verification_tail
          "\x07\x08".b
        end

        def verify_read(bytes)
          wire, rest = call(bytes)
          expected = @wire_class.read(bytes)
          unverified!("call differs from read") unless wire.snapshot == expected.snapshot &&
                                                       bindata_bytes(wire) == bindata_bytes(expected)
          unverified!("call kept the wrong suffix") unless rest == verification_tail
        end

        def verify_write(sample)
          packed = pack(sample)
          return if packed.nil? || packed == bindata_bytes(sample)

          unverified!("pack differs from BinData's writer")
        end

        # Keyword construction with the first scalar field set.
        def verify_build
          name = @slots.each_key.find { |slot| @leaves.any? { |path, _| path == [slot] } }
          return unless name

          built = build(name => 1)
          unverified!("build refused a known field") unless built
          expected = @wire_class.new({ name => 1 })
          same = built.snapshot == expected.snapshot && bindata_bytes(built) == bindata_bytes(expected)
          unverified!("build differs from BinData's constructor") unless same
          verify_build_copy
          verify_build_structs
          unverified!("build accepted an unknown key") if build(name => 1, no_such_field_: 1)
        end

        # The generated copy is a fresh, independent twin of the template.
        def verify_build_copy
          copy = build({})
          unless copy.instance_of?(@wire_class) && copy.snapshot == @wire_class.new.snapshot
            unverified!("build copy differs from a fresh instance")
          end
          shared = tree_objects(@template).map(&:object_id) & tree_objects(copy).map(&:object_id)
          unverified!("build copy shares objects with the template") unless shared.empty? && parents_consistent?(copy)
        end

        # Every nested struct field, given as a distinct-valued struct of its
        # own class, builds the same record as BinData's constructor.
        def verify_build_structs
          sample = verification_record
          @slots.each_key do |slot|
            next unless @template.public_send(slot).respond_to?(:field_names)

            given = sample.public_send(slot)
            built = build(slot => given)
            expected = @wire_class.new({ slot => given })
            same = built && built.snapshot == expected.snapshot && bindata_bytes(built) == bindata_bytes(expected)
            unverified!("build of #{slot} differs from BinData's constructor") unless same
          end
        end
      end

      # Eager fill of fixed-layout records: one String#unpack for the whole
      # record, then leaf assignment into a fresh instance of the same wire
      # class. The unpack format and leaf paths are derived once per class
      # from its field list, so the result is indistinguishable from `read`.
      class FastFill
        DIRECTIVES = {
          "BinData::Uint32le" => "V",
          "BinData::Int32le" => "l<",
          "BinData::Uint8" => "C",
          "Emf::Binary::Float32Le" => "V"
        }.freeze
        FLOAT_LEAF = "Emf::Binary::Float32Le"
        EMPTY_SUFFIX = "".b.freeze
        private_constant :DIRECTIVES, :FLOAT_LEAF, :EMPTY_SUFFIX

        include SelfCheck

        def self.for(type_id)
          BY_TYPE[type_id]
        end

        def self.for_class(wire_class)
          BY_CLASS[wire_class] || POINT_ARRAY_BY_CLASS[wire_class] || TEXT_BY_CLASS[wire_class]
        end

        attr_reader :size, :wire_class

        def initialize(klass)
          @wire_class = klass
          sample = klass.new
          @size = sample.num_bytes
          @leaves = leaves = leaf_paths(sample, [])
          # leaf_paths touched every field, so the sample is fully instantiated.
          @template = sample
          @format = leaves.map { |_, field| DIRECTIVES.fetch(field.name) }.join
          # Float layouts are not packed: measured on test-000, BinData writes
          # SETWORLDTRANSFORM in 15 objects against 18+ for a value pack, and
          # Float32Le must write its retained NaN bits itself.
          @pack_format = @format unless leaves.any? { |_, field| float?(field) }
          @slots = WireCopy.slots(sample)
          generate_call(leaves)
          generate_pack(leaves)
          extend(BuildSource.new(@template, @slots).to_module)
        end

        # Keyword construction, `wire_class.new(**attrs)`; nil when a key is
        # not a field, so the caller falls back to BinData. Generated per
        # class by generate_build; subclasses override `build` and call super.
        def build(attrs) = build_attrs(attrs)

        private

        def float?(field)
          field.name == FLOAT_LEAF
        end

        def suffix(record_bytes, consumed = @size)
          return EMPTY_SUFFIX if record_bytes.bytesize == consumed

          record_bytes.byteslice(consumed, record_bytes.bytesize - consumed).b.freeze
        end

        def leaf_paths(record, prefix)
          record.field_names.flat_map do |name|
            field = record.public_send(name)
            if field.respond_to?(:field_names)
              leaf_paths(field, prefix + [name])
            else
              [[prefix + [name], field.class]]
            end
          end
        end

        # One specialized `call` per wire class: the record is unpacked into
        # locals and each leaf is assigned through the accessors BinData
        # already resolved for the class, with no per-leaf dispatch loop.
        def generate_call(leaves)
          locals = []
          lines = leaves.each_with_index.map do |(path, field), index|
            value = "v#{index}"
            locals << value
            target = accessor_chain(path)
            verb = float?(field) ? "assign_bits" : "assign"
            "#{target}.#{verb}(#{value})"
          end
          define_generated(:call, <<~RUBY)
            def call(record_bytes)
              #{locals.join(', ')} = record_bytes.unpack(@format)
              wire = WireCopy.call(@template, nil)
              #{lines.join("\n  ")}
              [wire, suffix(record_bytes)]
            end
          RUBY
        end

        def generate_pack(leaves)
          if @pack_format
            reads = leaves.map { |path, _| "#{accessor_chain(path)}.value" }
            body = "[#{reads.join(', ')}].pack(@pack_format)"
          else
            body = "nil"
          end
          define_generated(:pack, "def pack(wire)\n  #{body}\nend\n")
        end

        def accessor_chain(path)
          path.inject("wire") { |expr, name| "#{expr}.#{name}" }
        end

        def define_generated(name, source)
          singleton_class.class_eval(source, __FILE__, __LINE__)
          singleton_class.send(:public, name)
        end

        ENABLED_TYPES = [
          TypeCodes::SELECTOBJECT, TypeCodes::MOVETOEX, TypeCodes::LINETO,
          TypeCodes::DELETEOBJECT, TypeCodes::CREATEBRUSHINDIRECT,
          TypeCodes::SETBKCOLOR, TypeCodes::SETPIXELV, TypeCodes::CREATEPEN,
          TypeCodes::SETBKMODE, TypeCodes::SETTEXTCOLOR, TypeCodes::SETTEXTALIGN,
          TypeCodes::ELLIPSE, TypeCodes::SETVIEWPORTORGEX, TypeCodes::RESTOREDC,
          TypeCodes::SETWORLDTRANSFORM, TypeCodes::MODIFYWORLDTRANSFORM,
          TypeCodes::SETMAPMODE, TypeCodes::SETWINDOWEXTEX, TypeCodes::SETWINDOWORGEX,
          TypeCodes::SETVIEWPORTEXTEX, TypeCodes::SETPOLYFILLMODE, TypeCodes::SETROP2,
          TypeCodes::SETSTRETCHBLTMODE, TypeCodes::SETBRUSHORGEX, TypeCodes::SAVEDC,
          TypeCodes::BEGINPATH, TypeCodes::ENDPATH, TypeCodes::CLOSEFIGURE,
          TypeCodes::FILLPATH, TypeCodes::STROKEANDFILLPATH, TypeCodes::STROKEPATH,
          TypeCodes::RECTANGLE, TypeCodes::INTERSECTCLIPRECT, TypeCodes::EXCLUDECLIPRECT,
          TypeCodes::SETMITERLIMIT, TypeCodes::SETICMMODE, TypeCodes::SETLAYOUT
        ].freeze
        BY_TYPE = ENABLED_TYPES.to_h { |type_id| [type_id, guarded(Records.lookup(type_id))] }.compact.freeze
        BY_CLASS = BY_TYPE.values.to_h { |filler| [filler.wire_class, filler] }.freeze
        private_constant :ENABLED_TYPES, :BY_TYPE, :BY_CLASS
      end

      class FastFill
        # Header plus one counted array of PointL (32-bit) or PointS (16-bit)
        # points. The array field, its count field, the point class, the
        # unpack directive and the coordinate range are all read from the
        # record template, so one class serves every such record. The header is unpacked and assigned like a fixed layout; the points
        # come from one `unpack` and are built by copying a PointL template,
        # so the array holds the same BinData elements a read produces.
        # `call` returns nil when the count overruns the bytes, and `pack`
        # when a coordinate is not an int32, leaving those to BinData.
        class PointArrayFill < FastFill
          LAYOUTS = {
            "BinData::Int32le" => { directive: "l<", bytes: 8, range: (-(2**31))..((2**31) - 1) },
            "BinData::Int16le" => { directive: "s<", bytes: 4, range: (-(2**15))..((2**15) - 1) }
          }.freeze
          private_constant :LAYOUTS

          def initialize(klass)
            super
            array = @template.public_send(array_name)
            @point = array.send(:new_element)
            @point_class = @point.class
            @directive, @point_bytes, @range = LAYOUTS.fetch(@point.x.class.name).values_at(:directive, :bytes, :range)
            @x_leaf = @point.x
            @y_leaf = @point.y
            # The sample's num_bytes built the array's (empty) element list and
            # cached evaluators that read the template's cptl; copies share
            # neither.
            array.instance_variable_set(:@elements, nil)
            [@template, array, @point, @x_leaf, @y_leaf].each { |object| WireCopy.forget_evaluator(object) }
          end

          # Keyword construction; the points are built from template copies
          # when every element is a PointL or an {x:, y:} hash, else BinData's.
          def build(attrs)
            points = attrs[array_name]
            return super unless points.is_a?(::Array) && points.all? { |source| fast_point?(source) }

            wire = super(attrs.except(array_name))
            return unless wire

            array = wire.public_send(array_name)
            array.instance_variable_set(:@elements, points.map { |source| copy_point(array, source) })
            wire
          end

          def pack(wire)
            coords = []
            wire.public_send(array_name).each { |point| coords << point.x.value << point.y.value }
            return unless coords.all? { |v| v.is_a?(Integer) && @range.cover?(v) }

            [*header_values(wire), *coords].pack("#{@format}#{@directive}*")
          end

          private

          # Two points, so the counted array is exercised by the self-check.
          def verification_record
            wire = super
            wire.public_send(count_name).assign(2)
            wire.public_send(array_name).assign([{ x: 3, y: 4 }, { x: -5, y: 6 }])
            wire
          end

          # The record's one counted array field.
          def array_name
            @array_name ||= @template.field_names.find { |name| @template.public_send(name).is_a?(BinData::Array) }
          end

          def count_name
            @template.public_send(array_name).send(:get_parameter, :initial_length)
          end

          def leaf_paths(record, prefix)
            super.reject { |_, field| field <= BinData::Array }
          end

          def fast_point?(point)
            point.instance_of?(@point_class) ||
              (point.instance_of?(Hash) && point.size == 2 && point.key?(:x) && point.key?(:y))
          end

          def point_copy(array)
            point = @point.dup
            x = @x_leaf.dup
            y = @y_leaf.dup
            point.instance_variable_set(:@parent, array)
            x.instance_variable_set(:@parent, point)
            y.instance_variable_set(:@parent, point)
            point.instance_variable_set(:@field_objs, [x, y])
            [point, x, y]
          end

          def copy_point(array, source)
            point, x, y = point_copy(array)
            x.assign(source.is_a?(Hash) ? source[:x] : source.x)
            y.assign(source.is_a?(Hash) ? source[:y] : source.y)
            point
          end

          def points_from(array, flat)
            list = Array.new(flat.size / 2)
            index = 0
            while index < list.size
              point, x, y = point_copy(array)
              x.assign(flat[index * 2])
              y.assign(flat[(index * 2) + 1])
              list[index] = point
              index += 1
            end
            list
          end

          def generate_call(leaves)
            count = leaves.index { |path, _| path == [count_name] }
            array = array_name
            locals = leaves.each_index.map { |i| "v#{i}" }
            lines = leaves.each_with_index.map { |(path, _), i| "#{accessor_chain(path)}.assign(v#{i})" }
            define_generated(:call, <<~RUBY)
              def call(record_bytes)
                #{locals.join(', ')} = record_bytes.unpack(@format)
                consumed = @size + v#{count} * @point_bytes
                return if record_bytes.bytesize < consumed
                wire = WireCopy.call(@template, nil)
                #{lines.join("\n  ")}
                array = wire.#{array}
                flat = record_bytes.unpack("\#{@directive}\#{v#{count} * 2}", offset: @size)
                array.instance_variable_set(:@elements, points_from(array, flat))
                [wire, suffix(record_bytes, consumed)]
              end
            RUBY
          end

          def generate_pack(leaves)
            reads = leaves.map { |path, _| "#{accessor_chain(path)}.value" }
            define_generated(:header_values, "def header_values(wire)\n  [#{reads.join(', ')}]\nend\n")
          end
        end

        POINT_ARRAY_TYPES = [
          TypeCodes::POLYGON, TypeCodes::POLYLINE, TypeCodes::POLYBEZIER, TypeCodes::POLYBEZIERTO,
          TypeCodes::POLYLINETO, TypeCodes::POLYGON16, TypeCodes::POLYLINE16,
          TypeCodes::POLYBEZIER16, TypeCodes::POLYBEZIERTO16, TypeCodes::POLYLINETO16
        ].freeze
        POINT_ARRAY_BY_TYPE = POINT_ARRAY_TYPES.to_h do |type_id|
          [type_id, PointArrayFill.guarded(Records.lookup(type_id))]
        end.compact.freeze
        POINT_ARRAY_BY_CLASS = POINT_ARRAY_BY_TYPE.values.to_h { |filler| [filler.wire_class, filler] }.freeze
        private_constant :POINT_ARRAY_TYPES, :POINT_ARRAY_BY_TYPE, :POINT_ARRAY_BY_CLASS

        # The filler for a header plus point array record, which parses only
        # when its count fits the bytes.
        def self.for_points(type_id)
          POINT_ARRAY_BY_TYPE[type_id]
        end
      end

      class FastFill
        # EMR_EXTTEXTOUTA/W: a fixed header, an optional clip rectangle (absent
        # when f_options has ETO_NO_RECT, 0x100) and `rest :trailing`, which
        # takes every remaining byte, so a parse never leaves a suffix. The
        # option bits are read from the bytes to pick the with-rect or
        # without-rect layout; both unpack the header in one call and copy
        # one template, the rect leaves just staying at their defaults when
        # absent, as BinData leaves them. `call` returns nil when the bytes
        # are too short for the layout they select, and `pack` when a scale is
        # NaN (Float32Le keeps NaN bits) or trailing is not a String, leaving
        # those to BinData.
        class TextFill < FastFill
          NO_RECT = 0x100
          OPTIONS_OFFSET = 52
          FLOAT_DIRECTIVE = "e"
          private_constant :NO_RECT, :OPTIONS_OFFSET, :FLOAT_DIRECTIVE

          def initialize(klass)
            super
            @rect_size = @size
            @size = @rect_size - rect_bytes
            forget_evaluators(@template)
          end

          def call(record_bytes)
            return if record_bytes.bytesize < @size

            if record_bytes.unpack1("V", offset: OPTIONS_OFFSET).anybits?(NO_RECT)
              read_plain(record_bytes)
            elsif record_bytes.bytesize >= @rect_size
              read_rect(record_bytes)
            end
          end

          def pack(wire)
            options = wire.f_options.value
            trailing = wire.trailing.value
            return unless options.is_a?(Integer) && trailing.is_a?(::String)
            return unless [wire.ex_scale.value, wire.ey_scale.value].all? { |v| v.is_a?(Numeric) && !(v.is_a?(Float) && v.nan?) }

            if options.anybits?(NO_RECT)
              [*plain_values(wire), trailing].pack("#{@plain_pack_format}a*")
            else
              [*rect_values(wire), trailing].pack("#{@rect_pack_format}a*")
            end
          end

          private

          def rect_bytes
            @template.rcl.num_bytes
          end

          def forget_evaluators(object)
            WireCopy.forget_evaluator(object)
            object.instance_variable_get(:@field_objs).each do |field|
              field.respond_to?(:field_names) ? forget_evaluators(field) : WireCopy.forget_evaluator(field)
            end
          end

          def leaf_paths(record, prefix)
            super.reject { |path, _| path == [:trailing] }
          end

          # Distinct trailing bytes, so the rest field is exercised.
          def verification_record
            wire = super
            wire.trailing.assign("abc".b)
            wire
          end

          def verification_tail
            "".b
          end

          # The base self-check covers the with-rect layout; this repeats the
          # read and write comparison with ETO_NO_RECT set, where BinData
          # skips the rect.
          def verify_write(sample)
            super
            sample.f_options.assign(NO_RECT)
            bytes = bindata_bytes(sample)
            unverified!("no-rect layout is not shorter") unless bytes.bytesize == @size + 3
            wire, rest = call(bytes)
            expected = @wire_class.read(bytes)
            same = wire.snapshot == expected.snapshot && bindata_bytes(wire) == bytes && rest.empty?
            unverified!("no-rect call differs from read") unless same
            unverified!("no-rect pack differs from BinData's writer") unless pack(sample) == bytes
          end

          def generate_call(leaves)
            plain = leaves.reject { |path, _| path.first == :rcl }
            @rect_format = @format
            @plain_format = plain.map { |_, field| DIRECTIVES.fetch(field.name) }.join
            @rect_pack_format = pack_format(leaves)
            @plain_pack_format = pack_format(plain)
            define_reader(:read_rect, leaves, @rect_format, :@rect_size)
            define_reader(:read_plain, plain, @plain_format, :@size)
            define_values(:rect_values, leaves)
            define_values(:plain_values, plain)
          end

          def generate_pack(_leaves); end

          # Scales are packed as floats, everything else as in the read format.
          def pack_format(leaves)
            leaves.map { |_, field| float?(field) ? FLOAT_DIRECTIVE : DIRECTIVES.fetch(field.name) }.join
          end

          def define_reader(name, leaves, format, size)
            locals = leaves.each_index.map { |i| "v#{i}" }
            lines = leaves.each_with_index.map do |(path, field), i|
              "#{accessor_chain(path)}.#{float?(field) ? 'assign_bits' : 'assign'}(v#{i})"
            end
            define_generated(name, <<~RUBY)
              def #{name}(record_bytes)
                #{locals.join(', ')} = record_bytes.unpack("#{format}")
                wire = WireCopy.call(@template, nil)
                #{lines.join("\n  ")}
                wire.trailing.assign(record_bytes.byteslice(#{size}, record_bytes.bytesize - #{size}))
                [wire, EMPTY_SUFFIX]
              end
            RUBY
          end

          # Pack-ready values; scale leaves are read as floats, not bits.
          def define_values(name, leaves)
            reads = leaves.map { |path, _| "#{accessor_chain(path)}.value" }
            define_generated(name, "def #{name}(wire)\n  [#{reads.join(', ')}]\nend\n")
          end
        end

        TEXT_TYPES = [TypeCodes::EXTTEXTOUTA, TypeCodes::EXTTEXTOUTW].freeze
        TEXT_BY_TYPE = TEXT_TYPES.to_h { |type_id| [type_id, TextFill.guarded(Records.lookup(type_id))] }.compact.freeze
        TEXT_BY_CLASS = TEXT_BY_TYPE.values.to_h { |filler| [filler.wire_class, filler] }.freeze
        private_constant :TEXT_TYPES, :TEXT_BY_TYPE, :TEXT_BY_CLASS

        # The filler for the text-out records, whose layout depends on f_options.
        def self.for_text(type_id)
          TEXT_BY_TYPE[type_id]
        end
      end
    end
  end
end
