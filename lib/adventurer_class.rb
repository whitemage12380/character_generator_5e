require_relative 'character_generator_helper'

class AdventurerClass
  include CharacterGeneratorHelper
  attr_reader :class_name, :subclass_name, :level, :skills, :class_data, :subclass_data

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
    @class_data = character_class
    @subclass_data = subclass
    class_skills = character_class.fetch("skills", [])
    class_skills = Array.new(class_skills, character_class.fetch("skill_list", "any")) if class_skills.kind_of? Integer
    @skills = class_skills.map { |s| Skill.new(s, source: @class_name) }
    apply_level(1, character_class, subclass)
  end

  def apply_level(level, character_class = @class_data, subclass = @subclass_data)
    log "Applying level #{level}"
    # Add Subclass
    if level == character_class["subclass_level"] and not subclass
      @subclass_name, subclass = random_subclass(character_class) # TODO: weighted parameter should be set appropriately
      @subclass_data = subclass
      log "Chose Subclass: #{@subclass_name.pretty}"
    end
    # Resolve Class Choices
    decisions = {}
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
        when "options"
          case choice_content
          when Array
            decisions[choice_name] = choice_content.sample(1).first
            log "Chose #{choice_name.pretty}: #{decisions[choice_name].pretty}"
          when Hash
            decisions[choice_name] = choice_content.to_a.sample(1).to_h
            log "Chose #{choice_name.pretty}: #{decisions[choice_name].keys[0].pretty}"
          else
            raise "Unsupported type of value for options: #{choice_content}"
          end

        else
        end
      }
    }
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
      class_weight = 0
      character_class["ability_weights"].each_pair { |ability, weight|
        ability_modifier = (adventurer_abilities[ability.to_sym] - 10) / 2
        class_weight +=  ability_modifier * weight
        class_weight += weight if ability_modifier >= 3
        class_weight += weight if ability_modifier >= 4
        class_weight += weight if ability_modifier >= 5
      }
      character_class["weight"] = [class_weight, 0].max
      debug "#{class_name}: #{classes[class_name]["weight"]}"
    }
    chosen_class = weighted_random(classes)
    class_name, character_class = chosen_class.first
    if character_class["subclass_level"] == 1
      subclass_name, subclass = random_subclass(character_class, true)
      return class_name, character_class, subclass_name, subclass
    else
      return class_name, character_class, nil, nil
    end
  end
end