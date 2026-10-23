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

      # Source generation for the lazy fields of a FastFill's wires (see Record):
      # how to copy one field from the template and read its leaves from the
      # record's bytes.
      module LazySource
        private

        # The template's struct alone: no field object is copied, so each
        # slot of its @field_objs is nil until `lazy_field` makes it.
        def shell_lines(template)
          @templates << template
          ["wire = TEMPLATES[#{@templates.size - 1}].dup", "wire.instance_variable_set(:@parent, nil)",
           "wire.instance_variable_set(:@field_objs, Array.new(#{template.instance_variable_get(:@field_objs).size}))"]
        end

        # One `when` per top-level field: a copy of its subtree with the
        # values of the leaves beneath it, read from the record's bytes,
        # assigned.
        def lazy_cases(objs, slots, leaves, reads)
          slots.map do |name, index|
            field = objs[index]
            first = leaves.index { |path, _| path.first == name }
            lines = field.respond_to?(:field_names) ? copy_lines(field, "f", "wire") : leaf_lines(field, "f", "wire")
            lines += lazy_assigns(name, leaves, reads, first)
            "when #{index}\n    #{lines.join("\n    ")}\n    f"
          end
        end

        def lazy_assigns(name, leaves, reads, first)
          return ["fill_unvalued(f, data, base)"] unless first

          leaves.each_with_index.filter_map do |(path, leaf), position|
            next unless path.first == name

            verb = leaf.name == "Emf::Binary::Float32Le" ? "assign_bits" : "assign"
            directive, at = reads[position]
            "#{path.drop(1).inject('f') { |expr, step| "#{expr}.#{step}" }}.#{verb}(data.unpack1(\"#{directive}\", offset: base + #{at}))"
          end
        end
      end

      # Where each leaf of a fixed layout sits in the record's bytes, and the
      # shell that reads them on demand.
      module LeafReads
        WIDTHS = { "V" => 4, "l<" => 4, "C" => 1 }.freeze
        private_constant :WIDTHS

        # `build` without a wire: a shell over the bytes PackPlan packs from
        # the attributes, n_size as given. nil when there is no verified
        # plan, the attributes are not ones it takes, or fields cannot be
        # made lazily; the caller then builds.
        def build_packed(attrs)
          bytes = pack_plan&.pack(attrs, size: false) or return
          bytes = bytes.b unless bytes.encoding == Encoding::BINARY
          return eager(copy_shell, bytes, 0) unless @lazy_ok

          copy_shell.packed_from(bytes, self)
        rescue StandardError
          nil
        end

        private

        # A shell whose fields are made, from the record's bytes, as they are
        # first used.
        def lazy_wire(data, base)
          wire = copy_shell
          return eager(wire, data, base) unless @lazy_ok

          wire.instance_variable_set(:@lazy_data, data)
          wire.instance_variable_set(:@lazy_base, base)
          wire.instance_variable_set(:@lazy_filler, self)
          wire
        end

        # The same record with every field made now: what lazy fill is
        # checked against, and the fallback when the check fails.
        def eager(wire, data, base)
          objs = wire.instance_variable_get(:@field_objs)
          objs.each_index { |index| objs[index] = lazy_field(index, wire, data, base) }
          wire
        end

        # [directive, byte offset in the record] of each leaf, in leaf order;
        # the layout must be gap-free up to the end of the fixed part.
        def leaf_reads(leaves, directives)
          at = 0
          reads = leaves.map do |_, field|
            directive = directives.fetch(field.name)
            [directive, at].tap { at += WIDTHS.fetch(directive) }
          end
          raise SelfCheck::Unverified, "#{@wire_class}: leaves do not tile the record" unless at == @size

          reads
        end
      end

      # The self-check of FlatPoints, run once per point array filler.
      module FlatPointsCheck
        # The BinData::Array API the flat-points holder was written
        # against (bindata 2.5.1): every reader of its element list goes
        # through `elements`, `clear?` or `assign`.
        ARRAY_METHODS = %i[<< [] []= assign at clear? concat debug_name_of do_num_bytes do_write each empty?
                           find_index find_index_of first index initialize_instance initialize_shared_instance
                           insert last length offset_of push size slice snapshot to_ary unshift].freeze
        ARRAY_PRIVATE_METHODS = %i[append_new_element elements extend_array new_element slice_index slice_range
                                   slice_start_length sum_num_bytes_below_index
                                   sum_num_bytes_for_all_elements].freeze
        private_constant :ARRAY_METHODS, :ARRAY_PRIVATE_METHODS

        # Reads of a held array, one fresh pair (held, BinData-built) per
        # scenario; each returns what it observed.
        FLAT_SCENARIOS = [
          ->(_wire, array, _write) { [array.size, array.first.snapshot, array.last.snapshot, array.to_a.map(&:snapshot)] },
          ->(_wire, array, _write) { [array.map { |point| point.x.value + point.y.value }, array[1].x.value] },
          ->(wire, array, _write) { [array.num_bytes, wire.num_bytes, array.empty?, array.clear?] },
          ->(wire, _array, _write) { [wire.snapshot] },
          lambda { |wire, array, write|
            array << { x: 9, y: -9 }
            [array.size, array.last.snapshot, write.call(wire)]
          },
          lambda { |wire, array, write|
            array.assign([])
            [array.size, write.call(wire)]
          },
          lambda { |_wire, array, _write|
            array.assign([{ x: 1, y: 2 }])
            [array.size, array.first.snapshot, array.clear?]
          },
          ->(_wire, array, _write) { [array.to_binary_s, array.clear?, array.snapshot] }
        ].freeze
        private_constant :FLAT_SCENARIOS

        # True when this BinData still behaves as the flat-points holder
        # assumes: the Array API is the one it was written against and a
        # parsed record that holds its points flat reads, writes and
        # edits like the same record built by BinData. Any difference, or
        # an error, makes parsed and built records use eager points.
        def verify_flat_points
          return false unless BinData::Array.instance_methods(false).sort == ARRAY_METHODS.sort &&
                              BinData::Array.private_instance_methods(false).sort == ARRAY_PRIVATE_METHODS.sort

          bytes = bindata_bytes(verification_record)
          write = method(:bindata_bytes)
          FLAT_SCENARIOS.all? do |scenario|
            held = call(bytes).first
            reference = @wire_class.read(bytes)
            held.public_send(array_name).respond_to?(:hold_flat_points) &&
              scenario.call(held, held.public_send(array_name), write) ==
                scenario.call(reference, reference.public_send(array_name), write)
          end
        rescue StandardError
          false
        end
      end

      # Source of a FastFill's generated `build_attrs`, same result as
      # WireCopy.build: every known key is fetched into a local first (an
      # unknown key makes the count disagree and returns nil before any
      # copy), then each non-nil value is assigned straight into the copy.
      # A nested struct given as the same struct class is copied leaf by
      # leaf inline; any other value goes through WireCopy.assign.
      class BuildSource
        include LazySource

        ABSENT = Object.new.freeze

        def initialize(template, slots, leaves = [], reads = [])
          @struct_classes = []
          @templates = []
          @copy = copy_lines(template, "wire", "nil")
          objs = template.instance_variable_get(:@field_objs)
          @shell = shell_lines(template)
          @lazy = lazy_cases(objs, slots, leaves, reads)
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
            def copy_template
              #{@copy.join("\n  ")}
              wire
            end

            def copy_shell
              #{@shell.join("\n  ")}
              wire
            end

            # The field at `index` of a shell, copied from the template and
            # given the value read from `data`, the record starting at `base`.
            def lazy_field(index, wire, data, base)
              case index
              #{@lazy.join("\n  ")}
              end
            end

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
        # Each compares a lazy record with the read one after the same use.
        LAZY_SCENARIOS = [
          ->(lazy, ref, write, _) { lazy.snapshot == ref.snapshot && write.call(lazy) == write.call(ref) },
          lambda { |lazy, ref, write, leaves|
            path = leaves.last.first
            last = ->(wire) { path.inject(wire) { |obj, name| obj.public_send(name) } }
            last.call(lazy).value == last.call(ref).value && lazy.snapshot == ref.snapshot &&
              write.call(lazy) == write.call(ref)
          },
          lambda { |lazy, ref, write, leaves|
            [lazy, ref].each { |wire| leaves.first.first.inject(wire) { |o, n| o.public_send(n) }.assign(0x2A) }
            lazy.snapshot == ref.snapshot && write.call(lazy) == write.call(ref)
          },
          lambda { |lazy, _ref, write, _|
            lazy.assign(lazy.class.new)
            fresh = lazy.class.new
            lazy.snapshot == fresh.snapshot && write.call(lazy) == write.call(fresh)
          },
          lambda { |lazy, _ref, _write, _|
            was_clear = lazy.clear?
            lazy.clear
            was_clear == false && lazy.snapshot == lazy.class.new.snapshot
          }
        ].freeze
        private_constant :LAZY_SCENARIOS

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
          @lazy_ok = verify_lazy(bytes)
          self
        end

        private

        # BinData::Struct as the lazy shell assumes (bindata 2.5.1): fields
        # are reached only through instantiate_obj_at / instantiate_all_objs,
        # and clear / clear? are the only readers of @field_objs besides.
        STRUCT_METHODS = %i[[] []= assign clear clear? debug_name_of do_num_bytes do_read do_write each_pair
                            field_names has_key? initialize_instance initialize_shared_instance key?
                            offset_of snapshot].freeze
        STRUCT_PRIVATE_METHODS = %i[as_stringified_hash assign_fields base_field_name define_field_accessors
                                    define_field_accessors_for find_index_of find_obj_for_name include_obj?
                                    include_obj_for_io? instantiate_all_objs instantiate_obj_at
                                    sum_num_bytes_below_index sum_num_bytes_for_all_fields].freeze
        private_constant :STRUCT_METHODS, :STRUCT_PRIVATE_METHODS

        # True when a lazily filled record reads, writes and edits like the
        # BinData-read one; false (eager fill) on any difference or error.
        def verify_lazy(bytes)
          return false unless BinData::Struct.instance_methods(false).sort == STRUCT_METHODS.sort &&
                              BinData::Struct.private_instance_methods(false).sort == STRUCT_PRIVATE_METHODS.sort

          data = bytes.b.freeze
          LAZY_SCENARIOS.all? do |scenario|
            lazy = lazy_wire(data, 0)
            reference = @wire_class.read(data)
            lazy.instance_variable_get(:@lazy_filler) &&
              scenario.call(lazy, reference, method(:bindata_bytes), @leaves) == true
          end
        rescue StandardError
          false
        end

        def unverified!(what)
          raise Unverified, "#{@wire_class}: #{what}"
        end

        def bindata_bytes(wire)
          BINDATA_WRITER.bind_call(wire)
        end

        def verify_template(fresh)
          [WireCopy.call(@template, nil), copy_template].each { |copy| verify_copy_of(copy, fresh) }
          unverified!("slots do not cover the field list") unless @slots.keys == fresh.field_names
        end

        def verify_copy_of(copy, fresh)
          same = copy.instance_of?(@wire_class) && copy.snapshot == fresh.snapshot &&
                 copy.num_bytes == fresh.num_bytes && bindata_bytes(copy) == bindata_bytes(fresh)
          unverified!("template copy differs from a fresh instance") unless same
        end

        # No object of a copy is shared with the template, and every parent
        # link points into the copy.
        def verify_independent
          [-> { WireCopy.call(@template, nil) }, -> { copy_template }].each { |copier| verify_independent_copy(copier) }
        end

        def verify_independent_copy(copier)
          copy = copier.call
          shared = tree_objects(@template).map(&:object_id) & tree_objects(copy).map(&:object_id)
          unverified!("copy shares objects with the template") unless shared.empty?
          unverified!("copy parent links are wrong") unless parents_consistent?(copy)
          edit_leaf(copy)
          unverified!("editing a copy changed the template") unless copier.call.snapshot == @wire_class.new.snapshot
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
        include LeafReads

        def self.for(type_id)
          BY_TYPE[type_id]
        end

        def self.for_class(wire_class)
          BY_CLASS[wire_class] || POINT_ARRAY_BY_CLASS[wire_class] || TEXT_BY_CLASS[wire_class]
        end

        attr_reader :size, :wire_class, :template

        # The PackPlan for the class (bytes straight from attributes), or nil
        # when no verified plan exists.
        def pack_plan = defined?(@pack_plan) ? @pack_plan : (@pack_plan = PackPlan.build(self))

        def initialize(klass)
          @wire_class = klass
          @lazy_ok = true
          sample = klass.new
          @size = sample.num_bytes
          @leaves = leaves = leaf_paths(sample, [])
          # leaf_paths touched every field, so the sample is fully instantiated.
          @template = sample
          @format = leaves.map { |_, field| DIRECTIVES.fetch(field.name) }.join
          @leaf_reads = leaf_reads(leaves, DIRECTIVES)
          # Float layouts are not packed: measured on test-000, BinData writes
          # SETWORLDTRANSFORM in 15 objects against 18+ for a value pack, and
          # Float32Le must write its retained NaN bits itself.
          @pack_format = @format unless leaves.any? { |_, field| float?(field) }
          @slots = WireCopy.slots(sample)
          generate_call(leaves)
          generate_pack(leaves)
          extend(BuildSource.new(@template, @slots, leaves, @leaf_reads).to_module)
        end

        # Keyword construction, `wire_class.new(**attrs)`; nil when a key is
        # not a field, so the caller falls back to BinData. Generated per
        # class by generate_build; subclasses override `build` and call super.
        def build(attrs) = build_attrs(attrs)

        # [wire, suffix] for one record's bytes. The wire reads its fields
        # from a private frozen view of them when they are first used.
        def call(record_bytes)
          data = record_bytes.b.freeze
          call_at(data, 0, data.bytesize)
        end

        # The same for the n_size-byte record at `offset` of the frozen
        # binary `data`, which the wire keeps and reads fields from.
        def call_at(data, offset, n_size)
          [lazy_wire(data, offset), suffix(data, offset, n_size)]
        end

        # The wire `call_at` answers for a record that is exactly the layout
        # (no suffix), without the [wire, suffix] pair; nil for any other
        # n_size, which `call_at` reads.
        def exact_wire(data, offset, n_size) = (lazy_wire(data, offset) if n_size == @size)

        # Whether `call_at` reads the n_size-byte record at `offset`: always
        # for a fixed layout.
        def fits?(_data, _offset, _n_size) = true

        # Called by a lazy wire's field copy for a field `call` has no
        # unpacked leaf value for (subclasses with such a field override it).
        def fill_unvalued(_field, _data, _base); end

        private

        def float?(field)
          field.name == FLOAT_LEAF
        end

        # Bytes of the record at `offset` of `data` past the `consumed` ones.
        def suffix(data, offset, n_size, consumed = @size)
          return EMPTY_SUFFIX if n_size == consumed

          data.byteslice(offset + consumed, n_size - consumed).b.freeze
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
        def generate_call(_leaves); end

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
        # Extended onto the template's array (clones keep it). A built
        # record holds its coordinates as one flat list of integers; the
        # BinData points are made the first time anything reads the array's
        # elements, so a record built and serialized untouched never pays
        # for them. Every reader of @elements in BinData::Array goes through
        # `elements`, `clear?` or `assign`, which are the methods covered here.
        module FlatPoints
          def hold_flat_points(flat, filler)
            @elements = nil
            @flat_points = flat
            @point_filler = filler
          end

          def initialize_instance
            @flat_points = @point_filler = nil
            super
          end

          def clear?
            @flat_points ? false : super
          end

          def assign(array)
            return if equal?(array)

            @flat_points = @point_filler = nil
            super
          end

          # The coordinates of the given points as one list of Integers, the
          # values `assign` would store; nil when any is not an Integer or
          # there are no points, leaving those to the element-by-element copy.
          def self.coords_of(points)
            return if points.empty?

            flat = Array.new(points.size * 2)
            points.each_with_index do |source, index|
              x, y = source.is_a?(Hash) ? [source[:x], source[:y]] : [source.x, source.y]
              flat[index * 2] = x.respond_to?(:snapshot) ? x.snapshot : x
              flat[(index * 2) + 1] = y.respond_to?(:snapshot) ? y.snapshot : y
            end
            return unless flat.all?(Integer)

            flat
          end

          private

          def elements
            materialize_points if @flat_points
            super
          end

          # Build the full element list before publishing it, so a concurrent
          # reader sees either the flat list or complete elements.
          def materialize_points
            list = @point_filler.points_from(self, @flat_points)
            @elements = list
            @flat_points = @point_filler = nil
          end
        end

        # Builds BinData points from the filler's point template (`@point`
        # and its x and y leaves, set up by PointArrayFill).
        module PointCopying
          # Points as BinData elements, built from one flat coordinate list.
          def points_from(array, flat)
            Array.new(flat.size / 2) do |index|
              point, x, y = point_copy(array)
              x.assign(flat[index * 2])
              y.assign(flat[(index * 2) + 1])
              point
            end
          end

          private

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
        end

        # Header plus one counted array of PointL (32-bit) or PointS (16-bit)
        # points. The array field, its count field, the point class, the
        # unpack directive and the coordinate range are all read from the
        # record template, so one class serves every such record. The header is unpacked and assigned like a fixed layout; the points
        # come from one `unpack` and are built by copying a PointL template,
        # so the array holds the same BinData elements a read produces.
        # `call` returns nil when the count overruns the bytes, and `pack`
        # when a coordinate is not an int32, leaving those to BinData.
        class PointArrayFill < FastFill
          include PointCopying
          include FlatPointsCheck

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
            array.extend(FlatPoints)
            @pack_points_format = "#{@format}#{@directive}*"
            @hold_flat = true
            @hold_flat = verify_flat_points
          end

          # `nil` when the count overruns the n_size bytes of the record.
          def call_at(data, offset, n_size)
            consumed = @size + (data.unpack1("V", offset: offset + @count_offset) * @point_bytes)
            return if n_size < consumed

            [lazy_wire(data, offset), suffix(data, offset, n_size, consumed)]
          end

          def fits?(data, offset, n_size)
            @size + (data.unpack1("V", offset: offset + @count_offset) * @point_bytes) <= n_size
          end

          # The array field of a lazy wire: its points, held flat or built.
          def fill_unvalued(array, data, base)
            count = data.unpack1("V", offset: base + @count_offset)
            flat = data.unpack("#{@directive}#{count * 2}", offset: base + @size)
            if @hold_flat
              array.hold_flat_points(flat, self)
            else
              array.instance_variable_set(:@elements, points_from(array, flat))
            end
          end

          # Keyword construction; the points are built from template copies
          # when every element is a PointL or an {x:, y:} hash, else BinData's.
          def build(attrs)
            points = attrs[array_name]
            return super unless points.is_a?(::Array) && points.all? { |source| fast_point?(source) }

            wire = super(attrs.except(array_name))
            return unless wire

            array = wire.public_send(array_name)
            flat = FlatPoints.coords_of(points)
            if flat && @hold_flat
              array.hold_flat_points(flat, self)
            else
              array.instance_variable_set(:@elements, points.map { |source| copy_point(array, source) })
            end
            wire
          end

          # [point class, coordinate directive, low, high, bytes per coordinate, count field]
          def points_layout
            [@point_class, @directive, @range.begin, @range.end, @point_bytes / 2, count_name]
          end

          def pack(wire)
            array = wire.public_send(array_name)
            coords = array.instance_variable_get(:@flat_points) || collect_coords(array)
            return unless coords.all?(Integer) && coords.all?(@range)

            header_values(wire).concat(coords).pack(@pack_points_format)
          end

          private

          def collect_coords(array)
            array.each_with_object([]) { |point, coords| coords << point.x.value << point.y.value }
          end

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

          def generate_call(leaves)
            count = leaves.index { |path, _| path == [count_name] }
            @count_offset = @leaf_reads.fetch(count).last
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

          def call_at(data, offset, n_size)
            call(data.byteslice(offset, n_size))
          end

          # A text record's layout varies with its options, so `call_at` reads it.
          def exact_wire(_data, _offset, _n_size); end

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
                wire = copy_template
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
