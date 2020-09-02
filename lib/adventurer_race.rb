require_relative 'configuration'
require_relative 'character_generator_helper'


class AdventurerRace
  include CharacterGeneratorHelper
  attr_reader :race_name, :subrace_name, :race_abilities

  def initialize(adventurer_abilities)
    # There are the weights, but also weight bonuses if:
    #   An ability score bonus would increase the modifier
    #   20: +10
    #   18: +7
    #   16: +4
    #   10: +2
    #   8:  +2
    #   6:  +2
    generate_race(adventurer_abilities)
  end

  def name()
    @subrace_name ? @subrace_name : @race_name
  end

  def pretty_name()
    name.split(/ |\_/).map(&:capitalize).join(" ")
  end

  def generate_race(adventurer_abilities)
    @ability_score_weight_config = YAML.load_file("#{Configuration.project_path}/config/ability_score_weights.yaml")
    races = read_yaml_files("race")
    case $configuration["generation_style"]["race"]
    when "weighted"
      @race_name, @subrace_name, @race_abilities = random_race_weighted(races, adventurer_abilities)
    when "random"
      @race_name, @subrace_name, @race_abilities = random_race_true(races, adventurer_abilities)
    else
      raise "Unrecognized generation style: #{$configuration['generation_style']['race']}"
    end
  end

  #def random_race_smart(races)
  #end

  def random_race_weighted(races, adventurer_abilities)
    race = weighted_random(races)
    race_name = race.keys[0]
    if race[race_name]["subraces"]
      subrace = weighted_random(race[race_name]["subraces"])
      subrace_name = subrace.keys[0]
      race_abilities = spend_ability_points(race[race_name]["abilities"]
                       .merge(subrace[subrace_name]["abilities"]), adventurer_abilities)
                       .transform_keys(&:to_sym)
    else
      race_abilities = spend_ability_points(race[race_name]["abilities"], adventurer_abilities)
                       .transform_keys(&:to_sym)
    end
    return race_name, subrace_name, race_abilities
  end

  def random_race_true(races, adventurer_abilities)
    race = races.to_a.sample(1).to_h
    race_name = race.keys[0]
    if race[race_name]["subraces"]
      subrace = race[race_name]["subraces"].to_a.sample(1).to_h
      subrace_name = subrace.keys[0]
      race_abilities = spend_ability_points(race[race_name]["abilities"]
                       .merge(subrace[subrace_name]["abilities"]))
                       .transform_keys(&:to_sym)
    else
      race_abilities = spend_ability_points(race[race_name]["abilities"]).transform_keys(&:to_sym)
    end
    return race_name, subrace_name, race_abilities
  end

  def spend_ability_points(race_abilities, adventurer_abilities)
    return race_abilities unless race_abilities["any"]
    abilities = race_abilities.clone
    ability_points = abilities["any"]
    ability_points = [ability_points] unless ability_points.kind_of? Array
    abilities_chosen = []
    ability_points.each { |val|
      ability_weights = ABILITIES.collect { |ability|
        if abilities_chosen.include? ability or race_abilities.include? ability
          [ability, {"weight" => 0}]
        else
          [ability, {"weight" => ability_score_weight(adventurer_abilities[ability] + val, val)}]
        end
      }.to_h
      chosen_ability = weighted_random(ability_weights).keys.first
      log "Spending ability point on #{chosen_ability}"
      abilities_chosen << chosen_ability
      if abilities[chosen_ability]
        abilities[chosen_ability] += val
      else
        abilities[chosen_ability] = val
      end
    }
    abilities.delete("any")
    return abilities
  end

  def ability_score_weight(score, increase = 1)
    weight_chart = @ability_score_weight_config["ability_score_weights"][$configuration["generation_style"]["race"]]
    weight = weight_chart[score]
    weight *= 10 if (increase == 1) and (score % 2 == 0)
    return weight
  end
end