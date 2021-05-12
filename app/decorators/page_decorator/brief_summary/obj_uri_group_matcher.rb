require "set"

class PageDecorator
  class BriefSummary
    class ObjUriGroupMatcher
      class Match
        attr_accessor :type
        attr_accessor :uri
        attr_accessor :trait

        def initialize(group, uri, trait)
          @type = group.type
          @uri = uri
          @trait = trait
        end
      end

      class Group
        attr_accessor :type

        def initialize(type, uris)
          @type = type
          @uris = Set.new(uris)
        end

        def include?(uri)
          @uris.include? uri
        end
      end

      class Matches
        def initialize(matches)
          @matches = matches.uniq { |m| m.uri }

          @by_uri = @matches.group_by do |match|
            match.uri
          end

          @by_type = @matches.group_by do |match|
            match.type
          end
        end

        def has_type?(type)
          @by_type.key? type
        end

        def has_uri?(uri)
          @by_uri.key? uri
        end

        def by_type(type)
          @by_type[type]
        end

        def first_of_type(type)
          by_type(type)&.first
        end

        def by_uri(uri)
          @by_uri[uri]
        end

        def any?
          @matches.any?
        end

        def first
          @matches.first
        end

        # XXX: not performant
        def remove(match)
          @matches.delete(match)
          @by_uri[match.uri].delete(match)
          @by_type[match.type].delete(match)
        end
      end

      def initialize(*group_args)
        raise TypeError.new("Must specify at least one uri group") if group_args.empty?

        @groups = group_args.collect do |args|
          raise TypeError.new("Group arg missing :type") unless args.key?(:type)
          raise TypeError.new("Group arg missing :uris") unless args.key?(:uris)

          Group.new(args[:type], args[:uris])
        end
      end

      def match(trait)
        return nil if !trait.object_term
        uri = trait.object_term.uri

        found_group = nil
        @groups.each do |group|
          if group.include? uri
            found_group = group
            break
          end
        end

        if found_group
          Match.new(found_group, uri, trait)
        else
          nil
        end
      end 

      def match_all(traits)
        matches = []

        traits.each do |trait|
          match = self.match(trait)
          matches << match if match
        end

        Matches.new(matches)
      end
    end
  end
end
