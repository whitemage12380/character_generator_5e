require_relative 'character_generator_helper'


class AdventurerRace
  include CharacterGeneratorHelper
  attr_reader :race_name, :subrace_name, :race_abilities, :skills, :tools, :feats, :cantrips, :languages

  def initialize(adventurer_abilities)
    generate_race(adventurer_abilities)
  end

  def name()
    @subrace_name ? @subrace_name : @race_name
  end

  def generate_race(adventurer_abilities)
    races = read_yaml_files("race")
    case $configuration["generation_style"]["race"]
    when "smart", "weighted"
      @race_name, race, @subrace_name, subrace = random_race_weighted(races)
    when "random"
      @race_name, race, @subrace_name, subrace = random_race_true(races)
    else
      raise "Unrecognized generation style: #{$configuration['generation_style']['race']}"
    end
    log "Chose Race: #{@race_name.pretty}"
    log "Chose Subrace: #{@subrace_name.pretty}" if @subrace_name
    @race_abilities = random_race_abilities(race, subrace, adventurer_abilities)
    # Set race skills
    race_skills = race.fetch("skills", [])
    subrace_skills = subrace ? subrace.fetch("skills", []) : []
    race_skills = Array.new(race_skills, "any") if race_skills.kind_of? Integer
    subrace_skills = Array.new(subrace_skills, "any") if subrace_skills.kind_of? Integer
    @skills = (race_skills + subrace_skills).collect { |s| Skill.new(s, source: name) }
    # Set race feats
    # Cheat: Assuming feats is an integer and not supporting subclass feats, since only humans get a feat and it can be any feat
    @feats = Array.new(race.fetch("feats", 0)) { |f| Feat.new(source: @race_name) }
  end

  #def random_race_smart(races)
  #end

  def random_race_weighted(races)
    race_hash = weighted_random(races)
    race_name, race = race_hash.first
    if race["subraces"]
      subrace_hash = weighted_random(race["subraces"])
      subrace_name, subrace = subrace_hash.first
    end
    return race_name, race, subrace_name, subrace
  end

  def random_race_true(races)
    race_hash = races.to_a.sample(1).to_h
    race_name, race = race_hash.first
    if race["subraces"]
      subrace_hash = race["subraces"].to_a.sample(1).to_h
      subrace_name, subrace = subrace_hash.first
    end
    return race_name, race, subrace_name, subrace
  end

  def random_race_abilities(race, subrace, adventurer_abilities)
    race_abilities = race.fetch("abilities", {}).transform_keys(&:to_sym)
    subrace_abilities = subrace ? subrace.fetch("abilities", {}).transform_keys(&:to_sym) : {}
    return spend_ability_points(race_abilities.merge(subrace_abilities), adventurer_abilities, "race")
  end
end