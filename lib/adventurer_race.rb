require_relative 'character_generator_helper'


class AdventurerRace
  include CharacterGeneratorHelper
  attr_reader :race_name, :subrace_name, :race_abilities, :skills, :tools, :feats, :cantrips, :languages, :choices

  def initialize(adventurer_abilities, config: configuration)
    @configuration = config
    generation_style = configuration.fetch("generation_style", {"race"=>"smart"})["race"]
    generate_race(adventurer_abilities, generation_style)
  end

  def name()
    @subrace_name ? @subrace_name : @race_name
  end

  def generate_race(adventurer_abilities, generation_style = "smart")
    races = read_yaml_files("race")
    case generation_style
    when "smart", "weighted"
      @race_name, race, @subrace_name, subrace = random_race_weighted(races)
    when "random"
      @race_name, race, @subrace_name, subrace = random_race_true(races)
    else
      raise "Unrecognized generation style: #{generation_style}"
    end
    log "Chose Race: #{@race_name.pretty}"
    log "Chose Subrace: #{@subrace_name.pretty}" if @subrace_name
    @race_abilities = random_race_abilities(race, subrace, adventurer_abilities)
    # Set race skills
    race_skills = race.fetch("skills", [])
    subrace_skills = subrace ? subrace.fetch("skills", []) : []
    race_skills = Array.new(race_skills, race.fetch("skill_list", "any")) if race_skills.kind_of? Integer
    subrace_skills = Array.new(subrace_skills, subrace.fetch("skill_list", "any")) if subrace_skills.kind_of? Integer
    @skills = (race_skills + subrace_skills).collect { |s| Skill.new(s, source: name, config: configuration) }
    # Set race feats
    # Cheat: Assuming feats is an integer and not supporting subrace feats, since only humans get a feat and it can be any feat
    @feats = Array.new(race.fetch("feats", 0)) { |f| Feat.new(source: @race_name, config: configuration) }
    # Set race cantrips
    @cantrips = add_cantrips(race, subrace)
    # Set race choices
    @choices = random_race_choices(race)
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

  def random_race_choices(race)
    # So far, race choices only involve unique option sets, so that is all I will code for
    race.fetch("choices", {}).to_a.collect { |c| {c[0] => c[1]["options"].sample} }.reduce(&:merge)
  end

  def add_cantrips(race_data, subrace_data)
    spells = Array.new
    [race_data, subrace_data].each { |race|
      next if race.nil? or race['cantrips'].nil?
      spell_data = race['cantrips']
      case spell_data
      when Array
        spell_data.each { |spell_name|
          next unless spells.none? { |s| s.name and (s.name.downcase == spell_name.downcase) }
          log "Adding Cantrip from race: #{spell_name.pretty}"
          spells << Spell.new(source: name, name: spell_name, is_cantrip: true, config: configuration)
        }
      when Hash
        # Cheat: Assume races will never provide multiple choices of cantrips from different class lists
        list_name, spell_count = spell_data.first
        spell_list = SpellList.new(list_name, config: configuration)
        spell_source = "#{name} (#{list_name})"
        log "Adding #{spell_count} new #{list_name} cantrip(s) from race"
        spell_count.times do
          spells << Spell.new(source: spell_source, spell_list: spell_list, is_cantrip: true, config: configuration)
        end
      else
        raise "Invalid format for cantrips: #{spell_data}"
      end
    }
    return spells
  end
end