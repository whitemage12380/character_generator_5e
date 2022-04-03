require 'logger'

module CharacterGenerator
  class CharacterGeneratorLogger < Logger
    class << self
      def logger(log_level = 'INFO')
        @logger ||= CharacterGeneratorLogger.new(STDOUT, level: log_level)
      end
    end
  end
end