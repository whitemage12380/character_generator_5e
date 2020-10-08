require_relative 'character_generator_helper'

class Feat
  include CharacterGeneratorHelper
  attr_reader :feat_name, :source, :prerequisites, :ability_increase, :decisions

  def initialize(source:, feats: nil, adventurer_abilities: nil, is_spellcaster: nil, skills: nil, proficiencies: nil)
    @source = source
    unless feats.nil?
      generate(feats: feats, adventurer_abilities: adventurer_abilities, is_spellcaster: is_spellcaster, proficiencies: proficiencies)
    end
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
      when "special"
        case p_requirement
        when "spellcaster"
          unless is_spellcaster
            debug "Cannot select #{feat_name.pretty} due to not being able to cast at least one spell"
            return false
          end
        else
          debug "Cannot select #{feat_name.pretty} because special prerequisite '#{p_requirement.to_s} is not supported"
        end
      end
    }
    return true
  end

  def make_decisions(ability_choices: nil, choices: nil, adventurer_abilities: nil, skills: nil, proficiencies: nil)
    unless ability_choices.nil?
      # Using randomness to introduce slight uncertainty and to randomize ties
      # TODO: Resilient does not check for or handle save proficiency yet (saves are not yet handled in adventurer_class) 
      @ability_increase = ability_choices.max_by { |a| ability_increase_weight(a, adventurer_abilities) + rand(3) + rand()}.to_sym
      asi_statement = (ability_choices.count == 1) ? "Ability Score Increased" : "Chose Ability Score Increase"
      log "#{@feat_name}: #{asi_statement} - #{@ability_increase.to_s.pretty}"
    end
    unless choices.nil?
      @decisions = Hash.new if @decisions.nil?
      choices.each_pair { |choice_name, choice_data|
        case choice_name
        when "skills"
          log "Choose #{choice_data} skills (generation for skills not supported yet in feats)"
        when "cantrips"
          choose_spell_list(choices["spell_list_choices"])
          log "Choose #{choice_data} cantrips from the #{@decisions["spell list"]} list (generation for cantrips not supported yet in feats)"
        when "spells"
          choose_spell_list(choices["spell_list_choices"])
          choice_data.each_pair { |spell_level, spell_count|
            if choices["spell_restrictions"].nil?
              log "Choose #{spell_count} level #{spell_level} spells from the #{@decisions["spell list"]} list (generation for spells not supported yet in feats)"
            else
              log "Choose #{spell_count} level #{spell_level} spells (#{choices["spell_restrictions"]}) from the #{@decisions["spell list"]} list (generation for spells not supported yet in feats)"
            end
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

  def choose_spell_list(spell_lists)
    return unless @decisions["spell list"].nil?
    @decisions["spell list"] = spell_lists.sample
    log "#{@feat_name}: Chose Spell List - #{@decisions["spell list"]}"
  end
end