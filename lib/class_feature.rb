require_relative 'character_generator_helper'

module CharacterGenerator
  class ClassFeature
    include CharacterGeneratorHelper
    attr_reader :feature_name, :list, :choices, :decisions, :decisions_available

    def initialize(feature_name, list: nil, choices: nil, decisions_available: 1)
      raise "Class features cannot include both a DecisionList object and an arbitrary list of choices" if list and choices
      @feature_name = feature_name
      @list = list
      @decisions_available = decisions_available
      @decisions = []
      if choices
        case choices
        when Array
          @choices = choices.map { |c| ClassDecision.new(c) }
        when Hash
          @choices = choices.to_a.map { |c| ClassDecision.new(c[0], decision_data: c[1]) }
        end
      end
    end

    def make_decisions(level: nil, cantrips: nil, class_features: nil)
      if @list
        @decisions_available.times do
          chosen_decision = @list.random_decision(@decisions, level: level, cantrips: cantrips, class_features: class_features)
          @decisions << chosen_decision
          log "Chose #{@feature_name.pretty}: #{chosen_decision.decision_name.pretty}"
        end
      elsif @choices
        return if @decisions_available == 0
        chosen_decision = @choices.sample(@decisions_available).first
        @decisions << chosen_decision
        log "Chose #{@feature_name.pretty}: #{chosen_decision.decision_name.pretty}"
      else
        log "No decisions to make for feature #{@feature_name}"
      end
      @decisions_available = 0
    end

    def list_name()
      @list.list_name
    end

    def add_decisions(decisions_available)
      @decisions_available += decisions_available
    end

    def feature_lines()
      if @decisions.nil? or @decisions.length == 0
        return []
      elsif @decisions.length == 1
        return ["#{feature_name.pretty}: #{decisions.first.decision_name.pretty}"]
      else
        output = ["#{feature_name.pretty}"]
        output.concat(@decisions.map { |d| "  - #{d.decision_name.pretty}"}.sort)
        return output
      end
    end
  end
end