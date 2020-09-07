require_relative 'character_generator_helper'

class AdventurerClass
  include CharacterGeneratorHelper
  attr_reader :class_name, :subclass_name, :level

  def initialize(adventurer_abilities, level = 1)
    @level = level
    generate_class(adventurer_abilities)
  end

  def name()
    @subclass_name ? "#{class_name} (#{subclass_name})" : @class_name
  end

  def pretty_name()
    name.split(/ |\_|/).map(&:capitalize).join(" ") # TODO: Doesn't play nice with the parentheses
  end

  def generate_class(adventurer_abilities)
    classes = read_yaml_files("class")
    case $configuration["generation_style"]["class"]
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
    if @level >= character_class["subclass_level"]
      subclass = weighted ? weighted_random(character_class["subclasses"]) : character_class["subclasses"].to_a.sample(1).to_h
      subclass_name = subclass.keys[0]
      subclass = subclass[subclass_name]
    else
      subclass_name = nil
      subclass = nil
    end
    return class_name, character_class, subclass_name, subclass
  end
end