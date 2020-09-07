require_relative 'character_generator_helper'
require_relative 'adventurer_race'
require_relative 'adventurer_class'
require_relative 'adventurer_background'

class Adventurer
  include CharacterGeneratorHelper
  attr_reader :base_abilities, :race, :character_class, :background

  def initialize()
    @base_abilities = roll_abilities()
    @race = AdventurerRace.new(@base_abilities)
    @character_class = AdventurerClass.new(@base_abilities)
    @background = AdventurerBackground.new()
  end

  def abilities()
    a = @base_abilities.clone()
    if @race
      @race.race_abilities.each_pair { |ability, bonus|
        a[ability.to_sym] += bonus
      }
    end
    a
  end

  def roll_abilities()
    Hash[ABILITIES.zip(Array.new(6) {roll_ability})]
  end

  def roll_ability()
    Array.new(4) {rand(1..6)}.sort.reverse[0..2].sum
  end

  def modifier(ability_score)
    (ability_score - 10) / 2
  end

  def score_string(ability)
    score_num = abilities[ability]
    score_str = score_num.to_s.rjust(3)
    case score_num - @base_abilities[ability]
    when 1..20
      score_str.green
    when -20..-1
      score_str.red
    when 0
      score_str
    end
  end

  def modifier_string(ability)
    mod_num = modifier(abilities[ability])
    mod_str = (mod_num > 0 ? "+#{mod_num}" : "#{mod_num}").rjust(3)
    case mod_num - modifier(@base_abilities[ability])
    when 1..5
      mod_str.green
    when -5..-1
      mod_str.red
    when 0
      mod_str
    end
  end

  def print_abilities
    ability_score_strings = []
    ability_modifier_strings = []
    ABILITIES.each { |ability|
      ability_score_strings << score_string(ability)
      ability_modifier_strings << modifier_string(ability)
    }
    puts "STR  DEX  CON  INT  WIS  CHA"
    puts ability_score_strings.join("  ")
    puts ability_modifier_strings.join("  ")
  end

  def print_adventurer()
    puts "----------------------------"
    puts "Adventurer"
    puts "#{@race.name.pretty} #{@character_class.name.pretty}"
    puts "----------------------------"
    @background.print()
    puts "----------------------------"
    print_abilities()
    puts "----------------------------"
  end
end

### Testing only
adventurer = Adventurer.new()
adventurer.print_adventurer