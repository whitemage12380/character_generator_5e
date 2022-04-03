require_relative 'character_generator_helper'

module CharacterGenerator
  class Spell
    include CharacterGeneratorHelper
    extend CharacterGeneratorHelper
    attr_reader :name, :source, :book, :page, :level, :range, :duration, :casting_time, :school, :ritual, :concentration, :components, :classes, :list

    def initialize(source:, max_spell_level: nil, spell_list: nil, spells: nil,
                   min_spell_level: 1, spell_data: nil, name: nil, is_cantrip: false,
                   config: configuration)
      @configuration = config
      @source = source
      @list = spell_list
      @max_spell_level = max_spell_level
      @min_spell_level = min_spell_level
      if is_cantrip
        @level = "cantrip"
        @max_spell_level = "cantrip"
        @min_spell_level = "cantrip"
      end
      if spell_data.nil? and not name.nil? # If the name parameter is set, pull the rest of the data from yaml
        define_spell(read_yaml_files("spell").select { |s| s["name"].downcase == name.downcase }.first)
      elsif not spell_data.nil?
        define_spell(spell_data)
      end
    end

    def define_spell(spell_data)
      spell_detail_fields = [:name, :book, :page, :level, :range, :duration, :casting_time, :school, :ritual, :concentration, :components, :classes]
      case spell_data
      when Spell
        # Set all of this spell's data to that of the provided spell (e.g. from a spell list)
        # Note! For array fields like components and classes, this means both spell objects to the same object.
        # This is all a messy technique, but it's tolerable because neither object nor their variable should be touched after this.
        spell_detail_fields.each { |f| instance_variable_set("@#{f}", spell_data.instance_variable_get("@#{f}")) if instance_variable_get("@#{f}").nil? }
      when Hash
        spell_data.each_pair { |f, v| instance_variable_set("@#{f}", v) if instance_variable_get("@#{f}").nil?}
      else
        raise "Incompatible spell data format: #{spell_data}"
      end
    end

    def generate(spells, spell_list: @list, max_spell_level: @max_spell_level, min_spell_level: @min_spell_level)
      return unless @name.nil?
      unless @level.nil?
        max_spell_level = @level
        min_spell_level = @level
      end
      define_spell(Spell.random_spell(max_spell_level, spell_list, spells, min_spell_level: min_spell_level))
    end

    def self.random_spell(max_spell_level, spell_list, spells, min_spell_level: 1)
      if max_spell_level == "cantrip"
        spell_level = "cantrip"
        spell_str = "Cantrip"
      else
        spell_level = Spell.random_spell_level(min_spell_level, max_spell_level, spells, spell_list)
        spell_str = "Level #{spell_level} Spell"
      end
      chosen_spell = spell_list.spells_by_level(spell_level)
                     .select { |s| spells.none? { |sto| sto.name == s.name } } # Omit spells with names matching ones we already have
                     .sample # Simple random for now, may produce smarter random later
      raise "Failed to pick chosen spell (#{spell_str}, from #{spell_list.spells_by_level(spell_level).count} spells)" if chosen_spell.nil?
      log "Chose #{spell_str}: #{chosen_spell.name}"
      chosen_spell
    end

    def self.random_spell_level(min_spell_level, max_spell_level, spells, spell_list = nil)
      return max_spell_level if min_spell_level == max_spell_level
      weight_multiplier_level = 1
      weight_multiplier_count = 4
      max_spell_count = (min_spell_level..max_spell_level).to_a
        .collect { |lvl| spells.count { |s| s.level == lvl } }
        .max
      level_weights = (min_spell_level..max_spell_level).to_a.collect { |lvl|
        spell_count = spells.count { |s| s.level == lvl }
        # RULE 1: Base weight is inverse spell level (e.g. for level 1-6, level 1's weight is 6, level 6's weight is 1)
        weight = ((max_spell_level + 1) - lvl) * weight_multiplier_level
        # RULE 2: Levels with no spell slots get an additional large weight
        # RULE 3: Otherwise, add additional weight for each spell fewer than the maximum number of spells for a given level
        #         this level has (e.g. if there are 5 lvl 1 spells and 1 lvl 2 spell, add 0 to lvl 1 and 4 * multiplier to lvl 2)
        weight += (spell_count == 0) ? 600 : (max_spell_count - spell_count) * weight_multiplier_count
        # RULE 4: If there aren't any available spells in the spell list for the level, the weight is 0
        if spell_list and spell_list.spells_by_level(lvl).none? { |s| spells.none? { |sto| sto.name == s.name } }
          log_debug "No available level #{lvl} spells"
          weight = 0
        end
        {level: lvl, weight: weight}
      }
      log_debug "Spell level weights: (#{min_spell_level}) #{level_weights.collect { |l| l[:weight] }} (#{max_spell_level})"
      return weighted_random(level_weights)[:level]
    end

    def to_s()
      source_str = @source ? @source.pretty : "<Source not provided>"
      name_str = @name ? @name.pretty : "<Name not provided>"
      book_str = @book ? @book.pretty : ""
      level_str = @level ? @level.to_s : "?"
      if @level == "cantrip"
        "#{name_str.ljust(40)}#{source_str.ljust(30)}#{book_str}"
      else
        "#{name_str.ljust(36)}#{level_str.ljust(4)}#{source_str.ljust(30)}#{book_str}"
      end
    end
  end
end