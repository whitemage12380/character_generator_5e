#!/bin/env ruby
require 'yaml'
require 'logger'
require_relative 'character_generator_helper'

class Configuration < Hash

  def initialize()
    self.merge!(YAML.load_file(Configuration.configuration_path))
    self.transform_values! { |v|
      if v.kind_of? String
        case v.downcase
        when "true", "on", "yes"
          true
        when "false", "off", "no"
          false
        else
          v
        end
      else
        v
      end
    }
    puts "Configurations loaded: #{to_s}"
  end
  def self.configuration_path()
    "#{self.project_path}/config/character_generator.yaml"
  end
  def self.project_path()
    File.expand_path('../', File.dirname(__FILE__))
  end
end
$configuration = Configuration.new()