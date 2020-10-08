require_relative 'character_generator_helper'
require_relative 'adventurer_race'
require_relative 'adventurer_class'
require_relative 'adventurer_background'
require_relative 'skill'

class Adventurer
  include CharacterGeneratorHelper
  attr_reader :base_abilities, :race, :character_class, :background

  def initialize(level = 1)
    @base_abilities = roll_abilities()
    @race = AdventurerRace.new(@base_abilities)
    @character_class = AdventurerClass.new(abilities)
    @background = AdventurerBackground.new()
    generate_skills(skills, @character_class.expertises)
    level_up(level)
    prepare_spells()
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

  def hp()
    @character_class.hp_rolls.collect { |hr| hr + modifier(:constitution) >= 1 ? hr + modifier(:constitution) : 1 }.sum
  end

  def skills()
    race_skills = race.skills ? race.skills : []
    class_skills = character_class.skills ? character_class.skills : []
    background_skills = background.skills ? background.skills : []
    race_skills + class_skills + background_skills
  end

  def roll_abilities()
    Hash[ABILITIES.zip(Array.new(6) {roll_ability})]
  end

  def roll_ability()
    rolls = Array.new(4) {rand(1..6)}
    log "Rolling ability score: (#{rolls.join(",")})"
    return rolls.sort.reverse[0..2].sum
  end

  def level_up(level)
    return if level < 2
    for l in 2..level
      character_class.apply_level(l)
      generate_skills(skills, character_class.expertises)
    end
  end

  def prepare_spells()
    @character_class.prepare_spells(abilities)
  end

  def modifier(ability_score)
    ability_score = abilities[ability_score] if ability_score.kind_of? Symbol
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

  def skill_strings(skills_to_display = skills)
    skills_to_display.map { |skill| skill.to_s }.sort
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

  def abilities_summary()
    score = abilities.to_a.reduce(0) { |m, a|
      m += case modifier(a[1])
      when -4; -10
      when -3; -7
      when -2; -3
      when -1; -1
      when 0;   0
      when 1;   2
      when 2;   6
      when 3;   12
      when 4;   20
      when 5;   30
      else
        raise "Failed to determine modifier (#{modifier(a[1])}"
      end
    }
    summary_word = case score
    when -999..0; "Worthless".red
    when 1..10;   "Terrible".red
    when 11..17;  "Poor".red
    when 18..21;  "Decent"
    when 22..27;  "Good".green
    when 28..33;  "Great".green
    when 34..44;  "Fantastic".green
    when 45..999; "Godlike".green
    end
    return "#{summary_word} (#{score})"
  end

  def class_abilities_summary()
    score = @character_class.class_weight(abilities)
    summary_word = case score
    when 0;       "Worthless".red
    when 1..10;   "Terrible".red
    when 11..17;  "Poor".red
    when 18..21;  "Decent"
    when 22..27;  "Good".green
    when 28..33;  "Great".green
    when 34..44;  "Fantastic".green
    when 45..999; "Godlike".green
    end
    return "#{summary_word} (#{score})"
  end

  def print_adventurer()
    puts "----------------------------"
    puts "Adventurer"
    puts "#{@race.name.pretty} #{@character_class.name.pretty}"
    puts "Level #{@character_class.level}"
    puts "HP: #{hp}"
    puts "----------------------------"
    @background.print()
    puts "----------------------------"
    print_abilities()
    puts "----------------------------"
    puts "Ability Outlook:"
    puts "          Class:  #{class_abilities_summary()}"
    puts "        Overall:  #{abilities_summary()}"
    unless skills.empty?
      puts "----------------------------"
      puts "Skills:"
      puts skill_strings.join("\n")
    end
    unless @character_class.class_features.nil? or @character_class.class_features.empty?
      puts "----------------------------"
      puts "Class Features:"
      puts @character_class.decision_strings.join("\n")
    end
    unless @character_class.cantrips.nil? or @character_class.cantrips.empty?
      puts "----------------------------"
      puts "Cantrips:"
      puts @character_class.spell_strings(@character_class.cantrips).join("\n")
    end
    unless @character_class.spells_known.nil? or @character_class.spells_known.empty?
      puts "----------------------------"
      puts "Spells Known:"
      puts @character_class.spell_strings(@character_class.spells_known).join("\n")
    end
    unless @character_class.mystic_arcana.nil? or @character_class.mystic_arcana.empty?
      puts "----------------------------"
      puts "Mystic Arcana:"
      puts @character_class.spell_strings(@character_class.mystic_arcana).join("\n")
    end
    unless @character_class.spellbook.nil? or @character_class.spellbook.empty?
      puts "----------------------------"
      puts "Spellbook:"
      puts @character_class.spell_strings(@character_class.spellbook).join("\n")
    end
    unless @character_class.spells_prepared.nil? or @character_class.spells_prepared.empty?
      puts "----------------------------"
      puts "Spells Prepared:"
      puts @character_class.spell_strings(@character_class.spells_prepared).join("\n")
    end
    puts "----------------------------"
  end
end