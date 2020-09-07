require_relative 'character_generator_helper'

class AdventurerClass
  include CharacterGeneratorHelper
  attr_reader :class_name, :subclass_name, :level, :skills

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
  end

  def random_class(classes)
    weighted = $configuration["generation_style"]["class"] == "weighted"
    character_class_hash = weighted ? weighted_random(classes) : classes.to_a.sample(1).to_h
    class_name, character_class = character_class_hash.first
    subclass_name, subclass = random_subclass(character_class, weighted)
    return class_name, character_class, subclass_name, subclass
  end

  def random_subclass(character_class, weighted = false)
    if @level >= character_class["subclass_level"]
      subclass = weighted ? weighted_random(character_class["subclasses"]) : character_class["subclasses"].to_a.sample(1).to_h
      subclass_name, subclass = subclass.first
    else
      subclass_name = nil
      subclass = nil
    end
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
    subclass_name, subclass = random_subclass(character_class, true)
    return class_name, character_class, subclass_name, subclass
  end
end