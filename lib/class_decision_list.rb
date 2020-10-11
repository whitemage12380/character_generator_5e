require_relative 'character_generator_helper'
require_relative 'class_decision'

class ClassDecisionList
  include CharacterGeneratorHelper
  attr_reader :list_name, :choices, :decisions, :prerequisites

  def initialize(list_name, list, prerequisites = nil)
    @list_name = list_name
    @prerequisites = prerequisites
    case list
    when Array
      @choices = list.map { |l|
        decision_prerequisites = (@prerequisites and @prerequisites[l]) ? @prerequisites[l] : nil
        ClassDecision.new(l, prerequisites: decision_prerequisites)
      }
    when Hash
      @choices = list.to_a.map { |l|
        decision_prerequisites = (prerequisites and prerequisites[l[0]]) ? prerequisites[l[0]] : nil
        ClassDecision.new(l[0], prerequisites: decision_prerequisites, decision_data: l[1])
      }
    else
      raise "Unsupported class decision list type: #{list.to_s}"
    end
  end

  def allowed_choices(level: nil, cantrips: nil, class_features: nil)
    @choices.select { |c| c.prerequisites_met?(level: level, cantrips: cantrips, class_features: class_features) }
  end

  def random_decision(adventurer_decisions, level: nil, cantrips: nil, class_features: nil)
    @decisions = [] unless @decisions
    decision = allowed_choices(level: level, cantrips: cantrips, class_features: class_features)
               .difference(@decisions.union(adventurer_decisions)).sample
    @decisions << decision
    # TODO: Choices should be weighted based on their prerequisities; choices with met prereqs should come up more often than choices
    # with no prereqs. Ideally higher-level prereqs should be more frequent than lower-level ones.
    return decision
  end

  def to_s()
    "#{@list_name}: #{@choices.to_s}"
  end
end