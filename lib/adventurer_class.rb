require_relative 'character_generator_helper'
require_relative 'class_decision_list'
require_relative 'class_decision'
require_relative 'class_feature'
require_relative 'skill'
require_relative 'feat'
require_relative 'spell_list'
require_relative 'spell'

class AdventurerClass
  include CharacterGeneratorHelper
  attr_reader :class_name, :subclass_name, :level, :hit_die, :hp_rolls, :skills, :expertises, :feats, :ability_score_increases,
              :cantrips, :spells_known, :spells_prepared, :spellbook, :spell_lists, :mystic_arcana, :decision_lists, :class_features,
              :class_data, :subclass_data

  def initialize(adventurer_abilities, level = 1)
    @level = level
    generate_class(adventurer_abilities)
  end

  def name()
    @subclass_name ? "#{class_name} (#{subclass_name})" : @class_name
  end

  ###########
  ## LEVELING UP
  ###########

  def apply_level(level, adventurer_abilities, feat_params = nil, character_class = @class_data, subclass = @subclass_data)
    log "Applying level #{level}"
    @level = level
    # Roll HP
    if level > 1
      hp_roll = rand(@hit_die - 1) + 1
      log "Rolled #{hp_roll} on a d#{@hit_die} for hit points"
      @hp_rolls << hp_roll
    end
    # Add Subclass
    if level == character_class["subclass_level"] and not subclass
      @subclass_name, subclass = random_subclass(character_class) # TODO: weighted parameter should be set appropriately
      @subclass_data = subclass.merge({"name" => @subclass_name})
      log "Chose Subclass: #{@subclass_name.pretty}"
      create_decision_lists(subclass["lists"], subclass.fetch("list_prerequisites", nil)) if subclass["lists"]
    end
    # Add and Resolve Cantrips (because they can be prerequisites for other abilities)
    add_cantrips()
    generate_spells(@cantrips)
    # Resolve Class Choices
    @class_features = Array.new if @class_features.nil?
    class_choices = character_class["choices"] ? character_class["choices"].fetch(level, {}) : {}
    subclass_choices = (subclass and subclass["choices"]) ? subclass["choices"].fetch(level, {}) : {}
    choices = class_choices.merge(subclass_choices)
    choices.each_pair { |choice_name, choice|
      raise "For level #{level}, #{choice_name} should be a key-value pair, but it isn't." unless choice.kind_of? Hash
      evaluate_choice(choice_name, choice)
    }
    generate_decisions(level)
    # Resolve Ability Score Increases and Feats
    generate_ability_score_increases(character_class.fetch("ability_score_increases", [4, 8, 12, 16, 19]),
                                     adventurer_abilities: adventurer_abilities)
    # Add and Resolve Spells
    add_spells_known()
    add_spellbook_spells()
    generate_spells(@spells_known)
    generate_spells(@spellbook)
  end


  ###########
  ## CLASS/SUBCLASS
  ###########

  # Main Generator

  def generate_class(adventurer_abilities)
    classes = read_yaml_files("class")
    case $configuration["generation_style"]["class"]
    when "smart"
      @class_name, character_class, @subclass_name, subclass = random_class_smart(classes, adventurer_abilities)
    when "weighted", "random"
      @class_name, character_class, @subclass_name, subclass = random_class(classes)
    else
      raise "Unrecognized generation style: #{$configuration['generation_style']['class']}"
    end
    log "Chose Class: #{@class_name}"
    log "Chose Subclass: #{@subclass_name}" if @subclass_name
    create_decision_lists(character_class["lists"], character_class.fetch("list_prerequisites", nil)) if character_class["lists"]
    @class_data = character_class.merge({"name" => @class_name})
    @subclass_data = subclass ? subclass.merge({"name" => @subclass_name}) : nil
    @hit_die = character_class["hit_die"].delete('Dd').to_i
    @hp_rolls = [@hit_die.clone]
    class_skills = character_class.fetch("skills", [])
    class_skills = Array.new(class_skills, character_class.fetch("skill_list", "any")) if class_skills.kind_of? Integer
    @skills = class_skills.map { |s| Skill.new(s, source: @class_name) }
    @expertises = []
    @spell_lists = []
    apply_level(1, adventurer_abilities, nil, character_class, subclass)
  end

  # Random - Class

  def random_class_smart(classes, adventurer_abilities)
    debug "Class probabilities:"
    classes.each_pair { |class_name, character_class|
      character_class["weight"] = class_weight(adventurer_abilities, character_class["ability_weights"])
      debug "#{class_name}: #{classes[class_name]["weight"]}"
    }
    if classes.values.select { |c| c["weight"] > 0}.count == 0
      log "There is no recommended class based on ability scores! Allowing class to be entirely random."
      return random_class(classes)
    end
    chosen_class = weighted_random(classes)
    class_name, character_class = chosen_class.first
    if character_class["subclass_level"] == 1
      subclass_name, subclass = random_subclass(character_class, true)
      return class_name, character_class, subclass_name, subclass
    else
      return class_name, character_class, nil, nil
    end
  end

  def random_class(classes)
    weighted = $configuration["generation_style"]["class"] == "weighted"
    character_class_hash = weighted ? weighted_random(classes) : classes.to_a.sample(1).to_h
    class_name, character_class = character_class_hash.first
    if character_class["subclass_level"] == 1
      subclass_name, subclass = random_subclass(character_class, weighted)
      return class_name, character_class, subclass_name, subclass
    else
      return class_name, character_class, nil, nil
    end
  end

  def class_weight(adventurer_abilities, ability_weights = @class_data["ability_weights"])
    total_weight = 0
    ability_weights.each_pair { |ability, weight|
      ability_modifier = (adventurer_abilities[ability.to_sym] - 10) / 2
      total_weight +=  ability_modifier * weight
      total_weight += weight if ability_modifier >= 3
      total_weight += weight if ability_modifier >= 4
      total_weight += weight if ability_modifier >= 5
    }
    return [total_weight, 0].max
  end

  # Random - Subclass

  def random_subclass(character_class, weighted = false)
    subclass = weighted ? weighted_random(character_class["subclasses"]) : character_class["subclasses"].to_a.sample(1).to_h
    subclass_name, subclass = subclass.first
    return subclass_name, subclass
  end

  ###########
  ## CLASS FEATURES/DECISIONS
  ###########

  def evaluate_choice(choice_name, choice)
    choice.each_pair { |choice_type, choice_content|
      case choice_type
      when "skills"
        add_skills(choice_content, choice_name, choice.fetch("skill_list", "any"))
      when "skill_list"
        next
      when "expertises"
        add_expertises(choice_content)
      when "arcanum_level"
        generate_mystic_arcanum(choice_content)
      else
        add_class_feature(choice_name, choice_type, choice_content)
      end
    }
  end

  def create_decision_lists(lists, list_prerequisites = nil)
    @decision_lists = [] unless @decision_lists
    lists.each_pair { |list_name, list|
      if @decision_lists.none? { |l| l.list_name == list_name}
        prerequisites = (list_prerequisites and list_prerequisites[list_name]) ? list_prerequisites[list_name] : nil
        @decision_lists << ClassDecisionList.new(list_name, list, prerequisites)
      end
    }
  end

  def add_class_feature(feature_name, list_name, choices)
    if list_name == "options"
      @class_features << ClassFeature.new(feature_name, choices: choices)
      return
    end
    list = @decision_lists.select { |dl| dl.list_name == list_name }.first
    raise "Could not find list for #{list_name}" unless list
    case choices
    when Integer
      decision = @class_features.select { |d| d.feature_name == feature_name }.first
      if decision.nil?
        @class_features << ClassFeature.new(feature_name, list: list, decisions_available: choices)
      else
        raise "This feature already exists with a different list" if decision.list_name != list.list_name
        decision.add_decisions(choices)
      end
    else
      raise "Unsupported type of value for #{list_name}: #{choices}"
    end
  end

  def generate_decisions(level)
    @class_features.each { |d| d.make_decisions(level: level, cantrips: @cantrips, class_features: @class_features) }
  end

  def decision_strings()
    @class_features.map { |d| d.feature_lines }.flatten
  end

  ###########
  ## SKILLS
  ###########

  def add_skills(skills, source, skill_list = "any")
    @skills = Array.new if @skills.nil?
    case skills
    when Integer
      skills.times do
        @skills << Skill.new(skill_list, source: source)
      end
    when Array
      @skills.concat(skills.map { |s| Skill.new(s, source: source) })
    else
      raise "Unsupported type of value for skills: #{choice_content}"
    end
  end

  def add_expertises(expertises)
    case expertises
    when Integer
      expertises.times { @expertises << "any" }
    else
      # Expertise list not currently supported because no class currently requires it
      raise "Unsupported type of value for expertises: #{expertises}"
    end
  end

  ###########
  ## ABILITY SCORE INCREASES/FEATS
  ###########

  def generate_ability_score_increases(asi_levels, level: @level, source: @class_name, adventurer_abilities:, skills: nil, proficiencies: nil)
    return unless asi_levels and asi_levels.include? level
    # For now, decide whether to choose an ASI or a feat based on a coin flip
    case $configuration["feats"]
    when "always"
      is_feat = true
    when "sometimes"
      is_feat = rand(1)
    when "never"
      is_feat = false
    else
      log_warn "feats configuration not set; assuming never"
      is_feat = false
    end
    if is_feat
      @feats = Array.new if @feats.nil?
      @feats << Feat.new(source: source, feats: @feats, adventurer_abilities: adventurer_abilities, is_spellcaster: spellcaster?, skills: skills, proficiencies: proficiencies)
    else
      log "Ability score increases not yet supported"
    end
  end

  def feat_strings()
    @feats.collect { |f| f.feat_name.pretty }.sort
  end

  ###########
  ## SPELLS
  ###########

  # Adding placeholder spells

  def add_cantrips(level = @level, source = nil, cantrips_data = nil)
    @cantrips = Array.new if @cantrips.nil?
    add_spells(@cantrips, "cantrips", level)
  end

  def add_spells_known(level = @level)
    @spells_known = Array.new if @spells_known.nil?
    add_spells(@spells_known, "spells_known", level)
  end

  def add_spellbook_spells(level = @level)
    @spellbook = Array.new if @spellbook.nil?
    add_spells(@spellbook, "spellbook", level)
  end

  def add_spells(spells, spell_field, level = @level)
    [@class_data, @subclass_data].each { |character_class|
      next if character_class.nil? or character_class[spell_field].nil?
      spell_data = character_class[spell_field]
      source = character_class["name"]
      spell_data.each_pair { |list_name, list_data|
        if list_data.kind_of? Array and list_data.first.kind_of? String
          list_data.each { |spell_name|
            next unless spells.none? { |s| s.name.downcase == spell_name.downcase }
            log "Adding Spell: #{spell_name.pretty}"
            spells << Spell.new(source: source, spell_list: find_or_create_spell_list(list_name), name: spell_name)
          }
          next
        end
        spell_count = spell_count_for_level(list_data, level)
        next if spell_count == 0
        spell_source = source == list_name ? source : "#{source} (#{list_name})" # Makes it clear when a spell uses an unusual list
        debug "Adding #{spell_count} new spells (#{spell_field}, #{list_name})"
        max_level = max_spell_level(level)
        spell_count_for_level(list_data, level).times do
          spells << Spell.new(source: spell_source,
                              spell_list: find_or_create_spell_list(list_name),
                              max_spell_level: max_level,
                              is_cantrip: (spell_field == "cantrips"))
        end
      }
    }
  end

  # Generating spells

  def generate_spells(spells)
    return if spells.nil?
    spells.each { |spell| spell.generate(spells) }
  end

  def generate_mystic_arcanum(level, spell_list = "warlock")
    @mystic_arcana = Array.new if @mystic_arcana.nil?
    spell = Spell.random_spell(level, find_or_create_spell_list(spell_list), @mystic_arcana, min_spell_level: level)
    @mystic_arcana << spell
    log "Chose Mystic Arcanum: #{spell.name.pretty}"
  end

  # Preparing spells

  def prepare_spells(adventurer_abilities, level = @level)
    @spells_prepared = Array.new
    # No classes have spells automatically prepared outside of subclasses, so not searching for those
    # Add subclass spells
    prepare_spells_from_data(@subclass_data["spells"], @subclass_name, level) if @subclass_data and @subclass_data["spells"]
    # Add class feature spells
    @class_features.each { |class_feature|
      class_feature.decisions.each { |decision|
        prepare_spells_from_data(decision.spell_data, class_feature.feature_name, level)
      }
    }
    # Choose spells
    max_level = max_spell_level(level)
    [@class_data, @subclass_data].each { |character_class|
      next if character_class.nil? or character_class["spells_prepared"].nil?
      spells_prepared_data = character_class["spells_prepared"]
      spells_prepared_ability = spells_prepared_data["ability"].to_sym
      spells_prepared_spellbook = spells_prepared_data.fetch("spellbook", false)
      spells_prepared_class = spells_prepared_data["class"]
      spells_prepared_level_multiplier = spells_prepared_data.fetch("level_multiplier", 1.0)
      spell_count_ability = (adventurer_abilities[spells_prepared_ability]  - 10) / 2
      spell_count_level = (level * spells_prepared_level_multiplier).floor
      spell_count = spell_count_ability + spell_count_level
      spell_list = spells_prepared_spellbook ? SpellList.new("spellbook", @spellbook) : find_or_create_spell_list(spells_prepared_class)
      log "Preparing #{spell_count} #{spells_prepared_class} spells"
      debug "Preparing #{spell_count_ability} spells from ability"
      debug "Preparing #{spell_count_level} spells from level"
      spell_count.times do
        @spells_prepared << Spell.new(source: character_class["name"],
                            spell_list: spell_list,
                            max_spell_level: max_level)
      end
      generate_spells(@spells_prepared)
    }
  end

  def prepare_spells_from_data(spell_data, source, level = @level)
    spell_data.each_pair { |spell_level, spells|
      if spell_level <= level
        spells.each { |spell_name|
          if @spells_prepared.none? { |s| s.name == spell_name }
            @spells_prepared << Spell.new(name: spell_name, source: source, spell_list: nil)
          else
            log_warn "Tried to prepare #{source} spell #{spell_name.pretty} but it is already prepared!"
          end
        }
      end
    }
  end

  # Helpful spell methods

  def find_or_create_spell_list(list_name)
    @spell_lists = Array.new if @spell_lists.nil?
    if @spell_lists.one? { |sl| sl.name == list_name }
      spell_list = @spell_lists.select { |sl| sl.name == list_name }.first
    else
      spell_list = SpellList.new(list_name)
      @spell_lists << spell_list
    end
    return spell_list
  end

  def max_spell_level(level = @level, spell_level_data = class_data_element("spell_levels"))
    spell_level_data = {1 => 1, 3 => 2, 5 => 3, 7 => 4, 9 => 5, 11 => 6, 13 => 7, 15 => 8, 17 => 9} if spell_level_data.nil?
    spell_level_data.select { |character_level, v| character_level <= level }.values.max
  end

  def spell_count_for_level(list_data, level = @level)
    case list_data
    when nil
      return 0
    when Array
      return list_data[level-1]
    when Hash
      return list_data.fetch(level, 0)
    else
      raise "Unsupported type of value for list data: #{list_data}"
    end
  end

  def spellcaster?()
    [@class_data, @subclass_data].any? { |c| ["cantrips", "spells_known", "spells_prepared", "spellbook"].any? { |s| not c[s].nil? }} or
    (not @cantrips.to_a.empty?) or
    (not @spells_known.to_a.empty?) or
    (not @spells_prepared.to_a.empty?) or
    (not @spellbook.to_a.empty?)
  end

  def spell_strings(spells)
    spells.sort_by { |s| [s.level, s.name] }.collect { |s| s.to_s }
  end

  ###########
  ## GENERAL HELPERS
  ###########

  def class_data_element(elem)
    if @subclass_data.nil? or @subclass_data[elem].nil?
      return @class_data[elem]
    elsif @class_data[elem].nil?
      return @subclass_data[elem]
    else
      raise "Both class and subclass have #{elem}, this is not supported"
    end
  end

end