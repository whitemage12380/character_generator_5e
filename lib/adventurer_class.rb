require_relative 'character_generator_helper'
require_relative 'class_decision_list'
require_relative 'class_decision'
require_relative 'class_feature'
require_relative 'skill'

class AdventurerClass
  include CharacterGeneratorHelper
  attr_reader :class_name, :subclass_name, :level, :hit_die, :hp_rolls, :skills, :expertises, :decision_lists, :decisions, :class_data, :subclass_data

  def initialize(adventurer_abilities, level = 1)
    @level = level
    generate_class(adventurer_abilities)
  end

  def name()
    @subclass_name ? "#{class_name} (#{subclass_name})" : @class_name
  end

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
    @class_data = character_class
    @subclass_data = subclass
    @hit_die = character_class["hit_die"].delete('Dd').to_i
    @hp_rolls = [@hit_die.clone]
    class_skills = character_class.fetch("skills", [])
    class_skills = Array.new(class_skills, character_class.fetch("skill_list", "any")) if class_skills.kind_of? Integer
    @skills = class_skills.map { |s| Skill.new(s, source: @class_name) }
    @expertises = []
    apply_level(1, character_class, subclass)
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

  def apply_level(level, character_class = @class_data, subclass = @subclass_data)
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
      @subclass_data = subclass
      log "Chose Subclass: #{@subclass_name.pretty}"
      create_decision_lists(subclass["lists"], subclass.fetch("list_prerequisites", nil)) if subclass["lists"]
    end
    # Resolve Class Choices
    decisions = {}
    @decisions = Array.new unless @decisions
    class_choices = character_class["choices"] ? character_class["choices"].fetch(level, {}) : {}
    subclass_choices = (subclass and subclass["choices"]) ? subclass["choices"].fetch(level, {}) : {}
    choices = class_choices.merge(subclass_choices)
    choices.each_pair { |choice_name, choice|
      raise "For level #{level}, #{choice_name} should be a key-value pair, but it isn't." unless choice.kind_of? Hash
      choice.each_pair { |choice_type, choice_content|
        case choice_type
        when "skills"
          case choice_content
          when Integer
            choice_content.times do
              @skills << Skill.new(choice.fetch("skill_list", "any"), source: choice_name)
            end
          when Array
            @skills.concat(choice_content.map { |s| Skill.new(s, source: choice_name) })
          else
            raise "Unsupported type of value for skills: #{choice_content}"
          end
        when "skill_list"
          next
        when "expertises"
          case choice_content
          when Integer
            choice_content.times { @expertises << "any" }
          else
            # Expertise list not currently supported because no class currently requires it
            raise "Unsupported type of value for expertises: #{choice_content}"
          end
        when "spells_known"
          log "Spell choices not yet supported"
        when "options"
          @decisions << ClassFeature.new(choice_name, choices: choice_content)
        else
          list = @decision_lists.select { |dl| dl.list_name == choice_type }.first
          raise "Could not find list for #{choice_content}" unless list
          case choice_content
          when Integer
            decision = @decisions.select { |d| d.feature_name == choice_name }.first
            if decision.nil?
              @decisions << ClassFeature.new(choice_name, list: list, decisions_available: choice_content)
            else
              raise "This feature already exists with a different list" if decision.list_name != list.list_name
              decision.add_decisions(choice_content)
            end
          else
            raise "Unsupported type of value for #{choice_type}: #{choice_content}"
          end
        end
      }
    }
    generate_decisions(level)
  end

  def generate_decisions(level)
    @decisions.each { |d| d.make_decisions(level: level, cantrips: nil, class_features: @decisions) }
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

  def random_subclass(character_class, weighted = false)
    subclass = weighted ? weighted_random(character_class["subclasses"]) : character_class["subclasses"].to_a.sample(1).to_h
    subclass_name, subclass = subclass.first
    return subclass_name, subclass
  end

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

  def decision_strings()
    @decisions.map { |d| d.feature_lines }.flatten
  end
end