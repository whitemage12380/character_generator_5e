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

  def ability_score_weights(category = nil)
    @ability_score_weight_config = YAML.load_file("#{Configuration.project_path}/config/ability_score_weights.yaml") if @ability_score_weight_config.nil?
    if category.nil?
      @ability_score_weight_config["ability_score_weights"]
    else
      @ability_score_weight_config["ability_score_weights"][self["generation_style"][category]]
    end
  end

  def data_sources_allowed(type)
    if self['data_sources_allowed'] and self['data_sources_allowed'][type]
      list = self['data_sources_allowed'][type]
      return (list == 'all' or list.kind_of? Array) ? list : [list]
    elsif self['data_sources_allowed'] and self['data_sources_allowed']['default']
      list = self['data_sources_allowed']['default']
      return (list == 'all' or list.kind_of? Array) ? list : [list]
    else
      return 'all'
    end
  end

  def self.configuration_path()
    "#{self.project_path}/config/character_generator.yaml"
  end

  def self.project_path()
    File.expand_path('../', File.dirname(__FILE__))
  end
end
$configuration = Configuration.new()