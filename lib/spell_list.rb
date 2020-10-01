require_relative 'character_generator_helper'
require_relative 'spell'

class SpellList
  include CharacterGeneratorHelper
  attr_reader :name, :spells

  def initialize(name, spells = nil)
    @name = name
    if spells
      @spells = read_yaml_files("spells")
                .select { |s| spells.include? s["name"] }
                .collect { |s| Spell.new(s.transform_keys(&:to_sym).merge({list: self})) }
                #.to_h { |s| [s.level, s] }
    else
      @spells = read_yaml_files("spells")
                .select { |s| name == "any" or s["classes"].include? name }
                .collect { |s| Spell.new(s.transform_keys(&:to_sym).merge({list: self})) }
                #.to_h { |s| [s.level, s] }
    end

    def difference(arr)
      @spells.difference(arr)
    end

    def omit_spells(spells_to_omit)
      @spells.select { |s| spells_to_omit.none? { |sto| sto.name == s.name } }
    end

    def cantrips()
      spells.select { |s| s.level == "Cantrip" }
    end

    def spells_by_level(level)
      spells.select { |s| s.level == level }
    end

    #@spells = (0..9).to_a.collect { |l|
    #  [l, spells_all_levels.select { |s| }]
    #}
    #@spells_hash = spells_all_levels
  end
end