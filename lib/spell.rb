require_relative 'character_generator_helper'

class Spell
  include CharacterGeneratorHelper
  extend CharacterGeneratorHelper
  attr_reader :name, :source, :page, :level, :range, :duration, :casting_time, :school, :ritual, :concentration, :components, :classes, :list

  def initialize(name:, source: nil, page: nil, level:, range: nil, duration: nil, casting_time: nil,
                 school:, ritual: false, concentration: false, components: nil, classes: [], list: nil)
    @name = name
    @source = source
    @page = page
    @level = level
    @range = range
    @duration = duration
    @casting_time = casting_time
    @school = school
    @ritual = ritual
    @concentration = concentration
    @components = components
    @classes = classes
    @list = list
  end

  def self.random_spell(spell_level, spell_list, spells)
    spell_str = spell_level == "cantrip" ? "Cantrip" : "Level #{spell_level} Spell"
    chosen_spell = spell_list.spells_by_level(spell_level).omit_spells(spells).sample
    log "Chose #{spell_str}: #{chosen_spell.name}"
    spells << chosen_spell
    chosen_spell
  end

  def self.random_spell_any_level(adventurer_level)
    
  end
end