require_relative 'character_generator_helper'
require_relative 'spell'

module CharacterGenerator
  class SpellList
    include CharacterGeneratorHelper
    attr_reader :name, :spells

    def initialize(name, spells: nil, config: configuration)
      @configuration = config
      @name = name
      if spells
        if spells.none? { |s| s.kind_of? Spell }
          @spells = read_yaml_files("spell")
                    .select { |s| spells.include? s["name"] }
                    .collect { |s| Spell.new(source: "#{name.pretty} Spell List",
                                             spell_data: s.transform_keys(&:to_sym).merge({list: self}),
                                             config: configuration)
                    }
        else
          @spells = spells
        end
      else
        @spells = read_yaml_files("spell")
                  .select { |s| name == "any" or s["classes"].include? name }
                  .collect { |s| Spell.new(source: "#{name.pretty} Spell List",
                                           spell_data: s.transform_keys(&:to_sym).merge({list: self}),
                                           config: configuration)
        }
      end

      def difference(arr)
        @spells.difference(arr)
      end

      def omit_spells(spells_to_omit)
        @spells.select { |s| spells_to_omit.none? { |sto| sto.name == s.name } }
      end

      def cantrips()
        @spells.select { |s| s.level == "Cantrip" }
      end

      def spells_by_level(level)
        @spells.select { |s| s.level == level }
      end

    end
  end
end