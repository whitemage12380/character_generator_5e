require 'rake'
Gem::Specification.new do |s|
  s.name        = 'character_generator_5e'
  s.version     = '0.3.0'
  s.summary     = "Generate Dungeons & Dragons 5E Characters"
  s.description = "A tool that randomly produces characters for Dungeons & Dragons 5th Edition"
  s.authors     = ["Egan Neuhengen"]
  s.email       = 'lightningworks@gmail.com'
  s.files       = FileList["bin/character_generator",
                           "config/*.yaml",
                           "data/background/*.yaml",
                           "data/class/*.yaml",
                           "data/feat/*.yaml",
                           "data/race/*.yaml",
                           "data/skill/*.yaml",
                           "data/spell/*.yaml",
                           "lib/*.rb"].to_a
  s.homepage    =
    'https://github.com/whitemage12380/character_generator_5e'
  s.license       = 'MPL-2.0'
end
