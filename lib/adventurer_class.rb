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
    when "weighted"
      @class_name, @subclass_name = random_class_weighted(classes)
    when "random"
      @class_name, @subclass_name = random_class_true(classes)
    else
      raise "Unrecognized generation style: #{$configuration['generation_style']['class']}"
    end
  end

  def random_class_weighted(classes)
  end

  def random_class_true(classes)
    character_class = classes.to_a.sample(1).to_h
    class_name = character_class.keys[0]
    if @level >= character_class[class_name]["subclass_level"]
      subclass = character_class[class_name]["subclasses"].to_a.sample(1).to_h
      subclass_name = subclass.keys[0]
    else
      subclass_name = nil
    end
    return class_name, subclass_name
  end
end