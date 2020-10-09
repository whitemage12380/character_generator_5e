require 'yaml'
require_relative 'configuration'

# Stole from https://stackoverflow.com/questions/9381553/ruby-merge-nested-hash
class ::Hash
    def deep_merge(second)
        merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
        self.merge(second, &merger)
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

module CharacterGeneratorHelper
  require 'stringio'
  require 'logger'

  ABILITIES = [:strength, :dexterity, :constitution, :intelligence, :wisdom, :charisma]

  def init_logger()
    $log = Logger.new(STDOUT) if $log.nil?
    $log.level = $configuration['log_level'] ? $configuration['log_level'].upcase : Logger::INFO
    $messages = StringIO.new() if $messages.nil?
    $message_log = Logger.new($messages) if $message_log.nil?
    $message_log.level = Logger::INFO
  end

  def debug(message)
    init_logger()
    $log.debug(message)
  end

  def log(message)
    init_logger()
    $log.info(message)
  end

  def log_error(message)
    init_logger()
    $log.error(message)
  end

  def log_important(message)
    init_logger()
    $log.info(message)
    $message_log.info(message)
  end

  def read_yaml_files(type)
    files = Dir["#{__dir__}/../data/#{type}/*.yaml"]
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
        elem_weight = elem[1]["weight"] if elem[1].kind_of? Hash
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
    # Restriect options, in ascending order of options available
    skills.select { |s| s.skill_list and not s.skill_name }.sort_by { |s| s.skill_list.length }.each { |s| s.generate(skills) }
    # Unrestricted options
    skills.select { |s| not s.skill_list and not s.skill_name }.each { |s| s.generate(skills) }
    # Expertises
    expertises.each { |e|
      skills.select { |s| not s.expertise? }.sample.make_expertise()
      expertises.delete_at(expertises.index(e))
    }
  end

  def all_skills()
    $all_skills = read_yaml_files("skill") unless $all_skills
    $all_skills.keys
  end

  def all_skills_without_expertise()
    $all_skills = read_yaml_files("skill") unless $all_skills
    $all_skills.select { |s| not s.expertise }.keys
  end

  def all_skills_hash()
    all_skills() # Populate $all_skills if it hasn't been populated
    $all_skills
  end

  def random_skills(adventurer_skills, skill_list = all_skills, num = 1)
    skill_list.difference(adventurer_skills).sample(num)
  end
end