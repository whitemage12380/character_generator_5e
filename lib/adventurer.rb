require_relative 'character_generator_helper'
require_relative 'adventurer_race'
require_relative 'adventurer_class'
require_relative 'adventurer_background'
require_relative 'skill'
require_relative 'exporter_pdf'

class Adventurer
  include CharacterGeneratorHelper
  attr_reader :character_name, :base_abilities, :race, :character_class, :background

  def initialize(level = 1)
    @base_abilities = roll_abilities()
    @race = AdventurerRace.new(@base_abilities)
    @character_class = AdventurerClass.new(abilities, adventurer_choices)
    @background = AdventurerBackground.new()
    generate_skills(skills, @character_class.expertises)
    generate_feats(@race.feats, abilities, @character_class.spellcaster?, adventurer_choices)
    level_up(level)
    prepare_spells()
  end

  def name()
    @character_name ? @character_name : "Adventurer"
  end

  def filename()
    return @filename unless @filename.nil?
    base_name = @character_name ? @character_name : "#{@race.name}_#{@character_class.name}_lvl#{@character_class.level}".tr(" ", "_").delete('()')
    directory_path = parse_path($configuration.fetch("saved_character_path", "data/character"))
    unless File.exist? "#{directory_path}/#{base_name}.yaml"
      @filename = base_name
      return @filename
    end
    (1..99).each { |n|
      unless File.exist? "#{directory_path}/#{base_name}_#{n}.yaml"
        @filename = "#{base_name}_#{n}"
        return @filename
      end
    }
    raise "Failed to find suitable filename (name used: #{base_name})"
  end

  def abilities()
    a = @base_abilities.clone()
    unless @race.nil?
      @race.race_abilities.each_pair { |ability, bonus|
        a[ability.to_sym] += bonus
      }
    end
    unless @character_class.nil? or @character_class.feats.nil?
      @character_class.feats.each { |f|
        a.each_key { |ability| (a[ability] += 1) if f.ability_increase == ability }
      }
    end
    unless @character_class.nil? or @character_class.ability_score_increases.nil?
      @character_class.ability_score_increases.each_pair { |asi_ability, asi_bonus|
        a[asi_ability] += asi_bonus
      }
    end
    a.each_key { |ability| a[ability] = 20 if a[ability] > 20 }
    a
  end

  def hp()
    @character_class.hp_rolls.collect { |hr| hr + modifier(:constitution) >= 1 ? hr + modifier(:constitution) : 1 }.sum + extra_hp
  end

  def extra_hp
    (((@race.name.downcase == "hill dwarf") ? 1 : 0) + (tough? ? 2 : 0)) * @character_class.level
  end

  def tough?()
    @character_class and @character_class.feats and @character_class.feats.one? { |f| f.name.downcase == "tough" }
  end

  def skills()
    race_skills = (race and race.skills) ? race.skills : []
    class_skills = (character_class and character_class.skills) ? character_class.skills : []
    background_skills = (background and background.skills) ? background.skills : []
    feat_skills = (character_class and character_class.feats) ? character_class.feats.collect { |f| f.decisions.fetch("skills", []) }.flatten : []
    race_skills + class_skills + background_skills + feat_skills
  end

  def has_skill?(skill_name)
    skills.any? { |s| s.skill_name.downcase == skill_name.downcase }
  end

  def skill_value(skill_name)
    ability_value = modifier(all_skills_hash[skill_name.downcase].to_sym) # Should be a better way to do this
    prof_value = has_skill?(skill_name) ? proficiency_bonus : 0
    return ability_value + prof_value
  end

  def saves()
    @character_class.saves
  end

  def has_save?(ability)
    saves.include? ability
  end

  def save_value(ability)
    ability_value = modifier(ability)
    prof_value = has_save?(ability) ? proficiency_bonus : 0
    return ability_value + prof_value
  end

  def cantrips()
    race_cantrips = (race and race.cantrips) ? race.cantrips : []
    class_cantrips = (@character_class and @character_class.cantrips) ? @character_class.cantrips : []
    feat_cantrips = (@character_class and @character_class.feats) ? @character_class.feats.collect { |f| f.decisions.fetch("cantrips", []) }.flatten : []
    race_cantrips + class_cantrips + feat_cantrips
  end

  def spells()
    class_spells = @character_class ? @character_class.spells : []
    feat_spells = (@character_class and @character_class.feats) ? @character_class.feats.collect { |f| f.decisions.fetch("spells", []) }.flatten : []
    class_spells + feat_spells
  end

  def feats()
    race_feats = (race and race.feats) ? race.feats : []
    class_feats = (character_class and character_class.feats) ? character_class.feats : []
    race_feats + class_feats
  end

  def feat_strings()
    feats.sort_by { |f| f.name }.collect { |f| f.feat_lines }.flatten
  end

  def proficiencies()
    nil # Proficiencies (e.g. tool proficiencies) not yet supported
  end

  def languages()
    background.languages
  end

  def adventurer_choices()
    {skills: skills(), feats: feats(), cantrips: cantrips(), proficiencies: proficiencies()}
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
      @character_class.apply_level(l, abilities, adventurer_choices)
      generate_skills(skills, @character_class.expertises)
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

  def proficiency_bonus(level = @character_class.level)
    case level
    when 1..4; 2
    when 5..8; 3
    when 9..12; 4
    when 13..16; 5
    when 17..20; 6
    else
      raise "Invalid level: #{level}"
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
    puts name
    puts "#{@race.name.pretty} #{@character_class.name.pretty}"
    puts "Level #{@character_class.level}"
    puts "HP: #{hp}"
    unless @race.choices.nil? or @race.choices.empty?
      puts "----------------------------"
      max_name_length = @race.choices.keys.max_by(&:length).length + 1
      puts @race.choices.to_a.collect { |c| "#{(c[0] + ":").pretty.ljust(max_name_length)} #{c[1]}" }.join("\n")
    end
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
    unless feats.nil? or feats.empty?
      puts "----------------------------"
      puts "Feats:"
      puts feat_strings.join("\n")
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

  def save(filename = filename(), filepath = $configuration['saved_character_path'])
    if filename =~ /^\/.*\.yaml$/
      fullpath = filename
    else
      #filepath = prase_path(filepath)
      #filepath = File.expand_path("#{File.dirname(__FILE__)}/../#{filepath}") unless filepath[0] == '/'
      fullpath = "#{parse_path(filepath)}/#{filename}.yaml"
    end
    log "Saving character to file: #{fullpath}"
    File.open(fullpath, "w") do |f|
      YAML::dump(self, f)
    end
  end

  def export_to_pdf()
    ExporterPdf.export(self)
  end
end