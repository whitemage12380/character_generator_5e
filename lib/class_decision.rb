require_relative 'character_generator_helper'

class ClassDecision
  include CharacterGeneratorHelper
  attr_reader :decision_name, :prerequisites, :decision_data

  def initialize(decision_name, prerequisites: nil, decision_data: nil)
    @decision_name = decision_name
    @prerequisites = prerequisites
    @decision_data = decision_data
  end

  def prerequisites_met?(level: nil, cantrips: nil, class_features: nil)
    return true if @prerequisites.nil?
    # Level Check
    if @prerequisites["level"] and not level
      debug "Cannot select #{decision_name.pretty} because level could not be determined"
      return false
    end
    if @prerequisites["level"] and (@prerequisites["level"] > level)
      debug "Cannot select #{decision_name.pretty} due to not meeting level prerequisites: #{@prerequisites["level"]}"
      return false
    end
    # Cantrip Check
    # return false if @prerequisites["cantrips"] and cantrips.none? { |c|  } # Uncommment and finish when spells are implemented
    # Each key under prerequisites other than those with specific meaning above are assumed to be class feature requirements
    # Class Feature Check
    class_feature_prerequisites = @prerequisites.select { |name, v| ["level", "cantrips"].none? name }
    return false unless class_feature_prerequisites.empty? or class_features
    class_feature_prerequisites.each_pair { |p_name, p_requirement_list|
      p_requirement_list = [p_requirement_list] unless p_requirement_list.kind_of? Array
      # For each required decision under a given class feature name, consider prerequisites not met if there exists no class feature
      # that has the same name as the prerequisite and contains a decision with a name that matches the stated requirement
      p_requirement_list.each { |p_requirement|
        if class_features.none? { |cf| cf.feature_name == p_name and not cf.decisions.none? { |d| d.decision_name == p_requirement } }
          debug "Cannot select #{decision_name.pretty} due to not meeting class feature prerequisites: #{p_name.pretty} - #{p_requirement.pretty}"
          return false
        end
      }
    }
    return true
  end

  def to_s()
    "Decision: #{@decision_name} (Prerequisites: #{prerequisites.to_s}, Data: #{decision_data.to_s})"
  end
end