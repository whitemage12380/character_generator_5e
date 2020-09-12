require_relative 'character_generator_helper'

class AdventurerBackground
  include CharacterGeneratorHelper
  attr_reader :background_name, :skills, :tools, :languages, :choices, :personality_traits, :ideals, :bonds, :flaws

  def name()
    background_name
  end

  def pretty_name()
    name.split(/ |\_/).map(&:capitalize).join(" ")
  end

  def initialize()
    generate_background()
  end

  def generate_background()
    backgrounds = read_yaml_files("background")
    background_hash = random_background(backgrounds)
    @background_name = background_hash.keys[0]
    background = background_hash[@background_name]
    @choices = random_choices(background)
    @personality_traits, @ideals, @bonds, @flaws = random_personality(background_hash)
    @skills = background["skills"].map { |s| Skill.new(s, source: name) }
    @tools = background["tools"]
  end

  def random_background(backgrounds)
    backgrounds.to_a.sample(1).to_h
  end

  def random_choices(background)
    return Hash.new unless background["choices"]
    choices = Hash.new
    background["choices"].each_pair { |name, options| choices[name] = options.sample }
    return choices
  end

  def random_personality(backgrounds)
    return random_personality_choices(backgrounds, "personality_traits", 2),
           random_personality_choices(backgrounds, "ideals", 1),
           random_personality_choices(backgrounds, "bonds", 1),
           random_personality_choices(backgrounds, "flaws", 1)
  end

  def random_personality_choices(backgrounds, type, num)
    personality = instance_variable_get("@#{type}")
    chosen_traits = personality ? personality.clone : []
    num.times do
      options = backgrounds.to_a.map { |background| background[1][type] }.flatten
      chosen_traits.each { |t| options.delete(t) }
      chosen_trait = options.sample(1).first
      chosen_traits << chosen_trait
    end
    return chosen_traits
  end

  def ideal_string(ideal)
    "#{ideal['ideal'].pretty}. #{ideal['statement']} (#{ideal['alignment'].pretty})"
  end

  def print()
    puts background_name.pretty
    @choices.each_pair { |name, option| puts "   #{name.pretty}: #{option.pretty}" }
    @personality_traits.each { |t| puts "Personality: #{t}"}
    @ideals.each             { |t| puts "Ideal:       #{ideal_string(t)}"}
    @bonds.each              { |t| puts "Bond:        #{t}"}
    @flaws.each              { |t| puts "Flaw:        #{t}"}
  end
end