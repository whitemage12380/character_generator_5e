require_relative 'character_generator_helper'

class Skill
  include CharacterGeneratorHelper
  attr_reader :skill_name, :skill_list, :source

  def initialize(name, source: nil, ability: nil)
    if name.kind_of? String and name != "any"
      @skill_name = name
    elsif name.kind_of? Array
      @skill_list = name
    end
    @source = source
  end

  def generate(adventurer_skills)
    return if @skill_name
    final_skill_list = (@skill_list ? @skill_list : all_skills).difference(adventurer_skills.map { |as| as.skill_name })
    @skill_name = final_skill_list.sample()
    if source
      log "Chose Skill: #{name} (from #{@source.pretty})"
    else
      log "Chose Skill: #{name}"
    end
  end

  def name()
    return @skill_name.pretty if @skill_name
    return "<Unused Skill Slot>" if @skill_list
    return "<Unused Skill Slot - Any>"
  end

  def ability()
    all_skills_hash[name]
  end

  def to_s()
    @source ? "#{name.ljust(30)}#{@source.pretty}" : name
  end
end