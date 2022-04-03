require 'yaml'
require_relative 'character_generator_logger'
require_relative 'configuration'


# Stole from https://stackoverflow.com/questions/9381553/ruby-merge-nested-hash
class ::Hash
    def deep_merge(second)
        merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
        self.merge(second, &merger)
    end
    def deep_merge!(second)
      merger = proc { |_, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : Array === v1 && Array === v2 ? v1 | v2 : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
      merge!(second.to_h, &merger)
    end
end

# Stole from https://stackoverflow.com/questions/1489183/colorized-ruby-output-to-the-terminal
class String

  def pretty()
    output = split(/ |\_/).map(&:capitalize).join(" ")
            .split("-").map(&:capitalize).join("-")
            .split("(").map(&:capitalize).join("(")
    output = capitalize.gsub(/_/, " ")
            .gsub(/\b(?<!\w['])[a-z]/) { |match| match.capitalize }
    return output
  end

  # colorization
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def yellow
    colorize(33)
  end

  def blue
    colorize(34)
  end

  def pink
    colorize(35)
  end

  def light_blue
    colorize(36)
  end
end

module CharacterGenerator
  module CharacterGeneratorHelper
    require 'stringio'
    require 'logger'

    ABILITIES = [:strength, :dexterity, :constitution, :intelligence, :wisdom, :charisma]

    def init_data()
      init_all_skills_hash()
    end

    def init_configuration(settings, configuration_path = nil)
      @configuration = Configuration.new(settings, configuration_path)
    end

    def configuration
      @configuration ||= Configuration.new()
    end

    def init_logger(log_level = configuration.fetch('log_level', 'INFO'))
      CharacterGeneratorLogger.logger(log_level)
    end

    def logger()
      CharacterGeneratorLogger.logger
    end

    def log_debug(message)
      logger.debug(message)
    end

    def log(message)
      logger.info(message)
    end

    def log_error(message)
      logger.error(message)
    end

    # def log_important(message)
    #   logger.info(message)
    #   $message_log.info(message)
    # end

    def saved_character_path(config = configuration)
      config.fetch("saved_character_path", "data/character")
    end

    def parse_path(path_str)
      # Currently only callable from ruby files directly in lib, no nesting (can be changed later)
      return nil if path_str.nil?
      (path_str[0] == "/") ? path_str : "#{Configuration.project_path}/#{path_str}"
    end

    def read_yaml_files(type, config: configuration)
      allowed_files = config.data_sources_allowed(type)
      if allowed_files == 'all'
        files = Dir["#{__dir__}/../data/#{type}/*.yaml"]
      else
        files = allowed_files.collect { |f| "#{__dir__}/../data/#{type}/#{f}.yaml" }
      end
      key = YAML.load(File.read(files[0])).keys[0]
      files.map { |f| read_yaml_file(f) }.reduce({}, :deep_merge)[key]
    end

    def read_yaml_file(file)
      YAML.load(File.read(file))
    end

    def weighted_random(obj)
      arr = obj.kind_of?(Array) ? obj : obj.to_a
      weighted_arr = []
      arr.each { |elem|
        if (elem.kind_of? Array) and (elem.length == 2) and ((elem[0].kind_of? String) or (elem[0].kind_of? Symbol)) and (elem[1].kind_of? Hash)
          elem_weight = elem[1].fetch("weight", elem[1][:weight]) if elem[1].kind_of? Hash
        else
          elem_weight = elem.fetch("weight", elem[:weight]) if elem.kind_of? Hash
        end
        probability = elem_weight ? elem_weight : 10
        probability.times do
          weighted_arr << elem
        end
      }
      return [weighted_arr.sample].to_h if obj.kind_of? Hash
      return weighted_arr.sample
    end

    def generate_skills(skills, expertises = [])
      skills = [] unless skills
      # Restricted options, in ascending order of options available
      skills.select { |s| s.skill_list and not s.skill_name }.sort_by { |s| s.skill_list.length }.each { |s| s.generate(skills) }
      # Unrestricted options
      skills.select { |s| not s.skill_list and not s.skill_name }.each { |s| s.generate(skills) }
      # Expertises
      expertises.each { |e|
        skills.select { |s| not s.expertise? }.sample.make_expertise()
        expertises.delete_at(expertises.index(e))
      }
    end

    def init_all_skills_hash()
      @all_skills_hash = read_yaml_files("skill")
    end

    # def self.all_skills_hash()
    #   @all_skills_hash ||= read_yaml_files("skill")
    # end

    def all_skills_hash()
      # CharacterGeneratorHelper.all_skills_hash
      @all_skills_hash ||= read_yaml_files("skill")
    end

    def all_skills()
      all_skills_hash.keys
    end

    def all_skills_without_expertise()
      all_skills_hash.select { |s| not s.expertise }.keys
    end

    def random_skills(adventurer_skills, skill_list = all_skills, num = 1)
      skill_list.difference(adventurer_skills).sample(num)
    end

    def generate_feats(feats, adventurer_abilities, is_spellcaster, adventurer_choices)
      feats.each { |f|
        f.generate(feats: feats, adventurer_abilities: adventurer_abilities, is_spellcaster: is_spellcaster, adventurer_choices: adventurer_choices)
      }
    end

    def generate_spells(spells, existing_spells = [])
      return if spells.nil?
      spells.each { |spell| spell.generate(spells + existing_spells) }
    end

    def spend_ability_points(ability_point_data, adventurer_abilities, category = "default")
      case ability_point_data
      when Hash
        return ability_point_data unless ability_point_data[:any]
        abilities = ability_point_data.clone
        ability_points = abilities[:any]
        ability_points = [ability_points] unless ability_points.kind_of? Array
      when Array
        abilities = Hash.new
        ability_points = ability_point_data
      when Integer
        abilities = Hash.new
        ability_points = [ability_point_data]
      else
        raise "Incompatible format for ability points: #{ability_point_data}"
      end
      abilities_chosen = []
      ability_points.each { |val|
        ability_weights = ABILITIES.collect { |ability|
          if abilities_chosen.include? ability or ability_point_data.include? ability
            [ability, {weight: 0}]
          else
            [ability, {weight: ability_score_weight(adventurer_abilities[ability] + val, increase: val, category: category)}]
          end
        }.to_h
        chosen_ability = weighted_random(ability_weights).keys.first
        log "Spending ability point on #{chosen_ability}"
        abilities_chosen << chosen_ability
        if abilities[chosen_ability]
          abilities[chosen_ability] += val
        else
          abilities[chosen_ability] = val
        end
      }
      abilities.delete(:any)
      return abilities
    end

    def ability_score_weight(score, increase: 1, category: "default", config: configuration)
      weight_chart = config.ability_score_weights(category)
      raise "score (#{score}) is not an integer" unless score.kind_of? Integer
      weight = weight_chart[score]
      raise "Could not find weight value for score #{score}" if weight.nil?
      weight *= 10 if score % 2 == 0
      return weight
    end
  end
end