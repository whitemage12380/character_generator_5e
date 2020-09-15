require_relative 'character_generator_helper'
require_relative 'class_decision'

class ClassDecisionList
  include CharacterGeneratorHelper
  attr_reader :list_name, :choices, :decisions, :prerequisites

  def initialize(list_name, list, prerequities = nil)
    @list_name = list_name
    @prerequisites = prerequisites
    case list
    when Array
      @choices = list.map { |l|
        decision_prerequisites = (prerequisites and prerequisites[l]) ? prerequisites[l] : nil
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

  def random_decision(adventurer_decisions)
    @decisions = [] unless @decisions
    decision = @choices.difference(@decisions.union(adventurer_decisions)).sample
    @decisions << decision
    return decision
  end
end