require_relative 'character_generator_helper'
require_relative 'spell_list'
require_relative 'spell'
require_relative 'skill'

class Feat
  include CharacterGeneratorHelper
  attr_reader :feat_name, :source, :prerequisites, :ability_increase, :decisions

  def initialize(source:, feats: nil, adventurer_abilities: nil, is_spellcaster: nil, skills: nil, proficiencies: nil)
    @source = source
    @decisions = Hash.new
    unless feats.nil?
      generate(feats: feats, adventurer_abilities: adventurer_abilities, is_spellcaster: is_spellcaster, skills: skills, proficiencies: proficiencies)
    end
  end

  def name()
    @feat_name
  end

  def generate(feats:, adventurer_abilities: nil, is_spellcaster: nil, skills: nil, proficiencies: nil)
    feat_data = read_yaml_files("feat")
    feat_data.each_pair { |feat_name, feat|
      feat["weight"] = feat_weight(feat_name, feat, feats, adventurer_abilities: adventurer_abilities, is_spellcaster: nil, proficiencies: nil)
    }
    chosen_feat_name, chosen_feat = weighted_random(feat_data).first
    @feat_name = chosen_feat_name
    log "Chose Feat: #{@feat_name.pretty}"
    make_decisions(ability_choices: chosen_feat["ability_choices"], choices: chosen_feat["choices"],
                   adventurer_abilities: adventurer_abilities, skills: skills, proficiencies: proficiencies)
  end

  def feat_weight(feat_name, feat_data, feats, adventurer_abilities: nil, is_spellcaster: nil, proficiencies: nil)
    return 0 unless feats.none? { |f| f.feat_name == feat_name}
    return 0 unless prerequisites_met?(feat_name: feat_name, prerequisites: feat_data["prerequisites"], adventurer_abilities: adventurer_abilities, is_spellcaster: is_spellcaster, proficiencies: proficiencies)
    return 0 unless feat_data["proficiencies"].nil? # Proficiencies not yet supported
    unless feat_data["ability_choices"].nil?
      return [feat_data["ability_choices"].collect { |a| ability_increase_weight(a, adventurer_abilities) }.max,
              feat_data.fetch("max_weight", 20)
             ].min
    end
    return feat_data.fetch("weight", 10)
  end

  def ability_increase_weight(ability, adventurer_abilities)
    score = adventurer_abilities[ability.to_sym]
    return 2 if score == 20
    return 5 if score % 2 == 0
    return 15 if score == 19
    return 14 if score == 17
    return 13 if score == 15
    return 10
  end

  def prerequisites_met?(feat_name: @feat_name, prerequisites: @prerequisites, adventurer_abilities: nil, is_spellcaster: nil, proficiencies: nil)
    return true if prerequisites.nil?
    prerequisites.each_pair { |p_name, p_requirement|
      case p_name
      when "abilities"
        p_requirement.each_pair { |ability, score|
          if adventurer_abilities[ability.to_sym] < score
            debug "Cannot select #{feat_name.pretty} due to not meeting #{ability} prerequisites: #{score}"
            return false
          end
        }
      when "proficiencies"
        debug "Cannot select #{feat_name.pretty} because proficiencies are not currently supported"
        return false
      when "special"
        case p_requirement
        when "spellcaster"
          unless is_spellcaster
            debug "Cannot select #{feat_name.pretty} due to not being able to cast at least one spell"
            return false
          end
        else
          debug "Cannot select #{feat_name.pretty} because special prerequisite '#{p_requirement.to_s} is not supported"
          return false
        end
      end
    }
    return true
  end

  def make_decisions(ability_choices: nil, choices: nil, adventurer_abilities: nil, skills: nil, proficiencies: nil)
    unless ability_choices.nil?
      # Using randomness to introduce slight uncertainty and to randomize ties
      # TODO: Resilient does not check for or handle save proficiency yet (saves are not yet handled in adventurer_class)
      debug "Ability increase base weights: #{ability_choices.collect { |a| ability_increase_weight(a, adventurer_abilities)}.to_s}"
      @ability_increase = ability_choices.max_by { |a| ability_increase_weight(a, adventurer_abilities) + rand(3) + rand()}.to_sym
      asi_statement = (ability_choices.count == 1) ? "Ability Score Increased" : "Chose Ability Score Increase"
      log "#{@feat_name.pretty}: #{asi_statement} - #{@ability_increase.to_s.pretty}"
    end
    unless choices.nil?
      choices.each_pair { |choice_name, choice_data|
        case choice_name
        when "skills"
          unless skills.nil?
            @decisions["skills"] = Array.new(choice_data) {Skill.new("any", source: @feat_name)}
          end
        when "cantrips"
          choose_spell_list(choices["spell_list_choices"])
          @decisions["cantrips"] = Array.new(choice_data) {
            Spell.new(source: @feat_name, is_cantrip: true, spell_list: @decisions["spell list"])
          }
          @decisions["cantrips"].each { |s| s.generate(@decisions["cantrips"]) }
        when "spells"
          choose_spell_list(choices["spell_list_choices"], restrictions = choices.fetch("spell_restrictions", {}))
          choice_data.each_pair { |spell_level, spell_count|
            @decisions["spells"] = Array.new(spell_count) {
              Spell.new(source: @feat_name, min_spell_level: spell_level, max_spell_level: spell_level, spell_list: @decisions["spell list"])
            }
            @decisions["spells"].each { |s| s.generate(@decisions["spells"]) }
          }
        when "spell_list_choices"
          next
        when "spell_restrictions"
          next
        when "maneuvers"
          log "Choose #{choice_data} Fighter maneuvers (generation for maneuvers not supported yet in feats)"
        end
      }
    end
  end

  def choose_spell_list(spell_lists, restrictions = {})
    return unless @decisions["spell list"].nil?
    @decisions["spell list"] = SpellList.new(spell_lists.sample)
    restrictions.each_pair { |field, requirement|
      @decisions["spell list"].spells.select! { |s|
        case field
        when "ritual"
          s.ritual == requirement
        else
          raise "Spell restriction not supported for feats: #{field}"
        end
      }
    }
    log "#{@feat_name}: Chose Spell List - #{@decisions["spell list"].name}"
  end

  def feat_lines()
    lines = [@feat_name.pretty]
    return lines if @decisions.nil? or @decisions.empty?
    @decisions.each_pair { |d_name, d_content|
      case d_content
      when Array
        lines << "  #{d_name.pretty}:"
        lines.concat(d_content.collect { |c|
          case c
          when Spell, SpellList, Skill
            "    - #{c.name}"
          when String
            "    - #{c}"
          else
            "<Not Supported>"
          end
        })
      when SpellList
        lines << "  #{d_name.pretty}: #{d_content.name.pretty}"
      else
        lines << "  #{d_name.pretty}: <Could not identify value>"
      end
    }
    return lines
  end
end