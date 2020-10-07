#!/usr/bin/env ruby

require 'yaml'

made_changes = false

spells = YAML.load(File.read("/home/whitemage/Development/character_generator/data/spells/spells.yaml"))["spells"]

spells.each { |s|
  if s["classes"].include? "wizard" and ["abjuration", "evocation"].include? s["school"] and [1,2,3,4].include? s["level"] and not s["classes"].include? "eldritch knight"
    puts "Making #{s["name"]} an eldritch knight spell"
    s["classes"] << "eldritch knight"
    made_changes = true
  end
  if s["classes"].include? "wizard" and ["enchantment", "illusion"].include? s["school"] and [1,2,3,4].include? s["level"] and not s["classes"].include? "arcane trickster"
    puts "Making #{s["name"]} an arcane trickster spell"
    s["classes"] << "arcane trickster"
    made_changes = true
  end
}

unless made_changes
  puts "No changes made."
  exit
end

puts "Saving spells..."
File.open("/home/whitemage/Development/character_generator/data/spells/spells.yaml", "w") { |f|
  f.write({"spells" => spells.sort_by { |s| s["name"] }}.to_yaml )
}
puts "All done!"
