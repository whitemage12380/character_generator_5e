require_relative 'character_generator_helper'

class ClassDecision
  include CharacterGeneratorHelper
  attr_reader :decision_name, :prerequisites, :decision_data

  def initialize(decision_name, prerequisites: nil, decision_data: nil)
    @decision_name = decision_name
    @prerequisites = prerequisites
    @decision_data = decision_data
  end

  def to_s()
    "Decision: #{@decision_name} (Prerequisites: #{prerequisites.to_s}, Data: #{decision_data.to_s})"
  end
end