class ExporterPdf

  require 'pdf-forms'
  require 'fileutils'
  require_relative 'adventurer'
  require_relative 'character_generator_helper'

  extend CharacterGeneratorHelper

  class << self

    def export(adventurer)
      raise "Could not find configured pdftk_path" if pdftk_path(adventurer.configuration).nil?
      ['main', 'spellcasting', 'details'].each { |page_name| export_page(page_name, adventurer) }
    end

    def export_page(page_name, adventurer)
      config = adventurer.configuration
      if ['details'].include? page_name
        log "Filling out #{page_name} sheet not yet implemented"
        return
      end
      blank_path = blank_page_path(page_name, config)
      filled_path = filled_page_path(page_name, adventurer)
      field_map = pdf_field_map(adventurer)[page_name]
      pdftk = PdfForms.new(pdftk_path(config))
      log "Filling out form: #{blank_path}"
      log "  and saving to: #{filled_path}"
      pdftk.fill_form(blank_path, filled_path, field_map)
    end

    def blank_page_path(page_name, config = configuration)
      page_path_base = pdf_configuration(config)['blank_path']
      sheet_name = pdf_configuration(config)['sheet_names'][page_name]
      return "#{parse_path(page_path_base)}/#{sheet_name}.pdf"
    end

    def filled_page_path(page_name, adventurer)
      config = adventurer.configuration
      # If filled_path is set, just use that
      # Otherwise, use name.
      # If name is generic/already exists, append a numeral
      filled_path = parse_path(pdf_configuration(config)['filled_path'])
      puts "filled path: #{filled_path}"
      if filled_path.nil?
        filled_path = parse_path("#{saved_character_path(config)}/#{adventurer.filename}")
        FileUtils.mkdir_p filled_path
      end
      return "#{filled_path}/#{pdf_configuration(config)['sheet_names'][page_name]}.pdf"
    end

    def pdf_field_map(adv)
      {
        'main' => {
          "ClassLevel" =>          "#{adv.character_class.name.pretty} #{adv.character_class.level}",
          "Background" =>          adv.background.pretty_name,
          "CharacterName" =>       "",
          "Race " =>               adv.race.name.pretty,
          "Alignment" =>           "",
          "XP" =>                  "",
          "STR" =>                 adv.abilities[:strength],
          "ProfBonus" =>           adv.proficiency_bonus,
          "AC" =>                  "",
          # "Initiative" =>        # Leave blank; not all circumstances are considered.
          # "Speed" =>             # Leave blank; not all circumstances are considered.
          "PersonalityTraits " =>  adv.background.personality_traits.join("\n"),
          "STRmod" =>              adv.modifier(:strength),
          "HPMax" =>               adv.hp,
          "ST Strength" =>         adv.save_value(:strength),
          "DEX" =>                 adv.abilities[:dexterity],
          # "HPCurrent" =>         # Leave blank; temporary value
          "Ideals" =>              adv.background.ideals.collect { |i| adv.background.ideal_string(i) }.join("\n"),
          "DEXmod " =>             adv.modifier(:dexterity),
          # "HPTemp" =>            # Leave blank; temporary value
          "Bonds" =>               adv.background.bonds.join("\n"),
          "CON" =>                 adv.abilities[:constitution],
          "HDTotal" =>             adv.character_class.hit_dice,
          # "Check Box 12" =>      # Leave blank; Death Saves
          # "Check Box 13" =>      # Leave blank; Death Saves
          # "Check Box 14" =>      # Leave blank; Death Saves
          "CONmod" =>              adv.modifier(:constitution),
          # "Check Box 15" =>      # Leave blank; Death Saves
          # "Check Box 16" =>      # Leave blank; Death Saves
          # "Check Box 17" =>      # Leave blank; Death Saves
          # "HD" =>                # Leave blank; temporary value
          "Flaws" =>               adv.background.flaws.join("\n"),
          "INT" =>                 adv.abilities[:intelligence],
          "ST Dexterity" =>        adv.save_value(:dexterity),
          "ST Constitution" =>     adv.save_value(:constitution),
          "ST Intelligence" =>     adv.save_value(:intelligence),
          "ST Wisdom" =>           adv.save_value(:wisdom),
          "ST Charisma" =>         adv.save_value(:charisma),
          "Acrobatics" =>          adv.skill_value("acrobatics"),
          "Animal" =>              adv.skill_value("animal handling"),
          "Athletics" =>           adv.skill_value("athletics"),
          "Deception " =>          adv.skill_value("deception"),
          "History " =>            adv.skill_value("history"),
          "Insight" =>             adv.skill_value("insight"),
          "Intimidation" =>        adv.skill_value("intimidation"),
          "Check Box 11" =>        adv.character_class.saves.include?(:strength) ? "Yes" : "Off",
          "Check Box 18" =>        adv.character_class.saves.include?(:dexterity) ? "Yes" : "Off",
          "Check Box 19" =>        adv.character_class.saves.include?(:constitution) ? "Yes" : "Off",
          "Check Box 20" =>        adv.character_class.saves.include?(:intelligence) ? "Yes" : "Off",
          "Check Box 21" =>        adv.character_class.saves.include?(:wisdom) ? "Yes" : "Off",
          "Check Box 22" =>        adv.character_class.saves.include?(:charisma) ? "Yes" : "Off",
          # "Wpn Name" =>          # Leave blank; Equipment and money not implemented
          # "Wpn1 AtkBonus" =>     # Leave blank; Equipment and money not implemented
          # "Wpn1 Damage" =>       # Leave blank; Equipment and money not implemented
          "INTmod" =>              adv.modifier(:intelligence),
          # "Wpn Name 2" =>        # Leave blank; Equipment and money not implemented
          # "Wpn2 AtkBonus " =>    # Leave blank; Equipment and money not implemented
          # "Wpn2 Damage " =>      # Leave blank; Equipment and money not implemented
          "Investigation " =>      adv.skill_value("investigation"),
          "WIS" =>                 adv.abilities[:wisdom],
          # "Wpn Name 3" =>        # Leave blank; Equipment and money not implemented
          # "Wpn3 AtkBonus  " =>   # Leave blank; Equipment and money not implemented
          "Arcana" =>              adv.skill_value("arcana"),
          # "Wpn3 Damage " =>      # Leave blank; Equipment and money not implemented
          "Perception " =>         adv.skill_value("perception"),
          "WISmod" =>              adv.modifier(:wisdom),
          "CHA" =>                 adv.abilities[:charisma],
          "Nature" =>              adv.skill_value("nature"),
          "Performance" =>         adv.skill_value("performance"),
          "Medicine" =>            adv.skill_value("medicine"),
          "Religion" =>            adv.skill_value("religion"),
          "Stealth " =>            adv.skill_value("stealth"),
          "Check Box 23" =>        adv.has_skill?('acrobatics') ? "Yes" : "Off",
          "Check Box 24" =>        adv.has_skill?('animal handling') ? "Yes" : "Off",
          "Check Box 25" =>        adv.has_skill?('arcana') ? "Yes" : "Off",
          "Check Box 26" =>        adv.has_skill?('athletics') ? "Yes" : "Off",
          "Check Box 27" =>        adv.has_skill?('deception') ? "Yes" : "Off",
          "Check Box 28" =>        adv.has_skill?('history') ? "Yes" : "Off",
          "Check Box 29" =>        adv.has_skill?('insight') ? "Yes" : "Off",
          "Check Box 30" =>        adv.has_skill?('intimidation') ? "Yes" : "Off",
          "Check Box 31" =>        adv.has_skill?('investigation') ? "Yes" : "Off",
          "Check Box 32" =>        adv.has_skill?('medicine') ? "Yes" : "Off",
          "Check Box 33" =>        adv.has_skill?('nature') ? "Yes" : "Off",
          "Check Box 34" =>        adv.has_skill?('perception') ? "Yes" : "Off",
          "Check Box 35" =>        adv.has_skill?('performance') ? "Yes" : "Off",
          "Check Box 36" =>        adv.has_skill?('persuasion') ? "Yes" : "Off",
          "Check Box 37" =>        adv.has_skill?('religion') ? "Yes" : "Off",
          "Check Box 38" =>        adv.has_skill?('sleight of hand') ? "Yes" : "Off",
          "Check Box 39" =>        adv.has_skill?('stealth') ? "Yes" : "Off",
          "Check Box 40" =>        adv.has_skill?('survival') ? "Yes" : "Off",
          "Persuasion" =>          adv.skill_value("persuasion"),
          "SleightofHand" =>       adv.skill_value("sleight of hand"),
          "CHamod" =>              adv.modifier(:charisma),
          "Survival" =>            adv.skill_value("survival"),
          # "AttacksSpellcasting" => 
          "Passive" =>             (10 + adv.skill_value("perception")),
          # "CP" =>                # Leave blank; Equipment and money not implemented
          # "ProficienciesLang" =>  
          # "SP" =>                # Leave blank; Equipment and money not implemented
          # "EP" =>                # Leave blank; Equipment and money not implemented
          # "GP" =>                # Leave blank; Equipment and money not implemented
          # "PP" =>                # Leave blank; Equipment and money not implemented
          # "Equipment" =>         # Leave blank; Equipment and money not implemented
          "Features and Traits" => features_and_traits_text(adv)
        },
        'spellcasting' => pdf_spellcasting_field_map(adv)
        # 'details' => {

        # }
      }
    end

    def features_and_traits_text(adventurer)
      # Currently includes feats and class choices
      output = Array.new
      advclass = adventurer.character_class
      unless advclass.feats.empty?
        output << "Feats:"
        output.concat(advclass.feats.collect { |feat| feat.name.pretty })
        output << ""
      end
      unless advclass.class_features.empty?
        output << "Class Choices:"
        output.concat(advclass.class_features.collect { |feature| feature.feature_lines }.flatten)
      end
      return output.join("\n")
    end

    def pdf_spellcasting_field_map(adv)
      (["cantrip"] + (1..9).to_a).collect { |level|
        # Currently, the Prepared checkboxes are not supported (only relevant for Wizards, who prepare a subset of their spellbook spells)
        if level == "cantrip"
          spell_labels = adv.cantrips.collect { |s| s.name.pretty }.sort
        else
          spell_labels = adv.spells.select { |s| (s.level == level) }
            .collect { |s| [adv.character_class.name, adv.character_class.class_name].include?(s.source) ? s.name.pretty : "#{s.name.pretty} (#{s.source.pretty})" }
            .sort
        end
        spell_line_map = Hash.new
        spell_labels.each_index { |i|
          spell_line_map[spell_fields[level][i]] = spell_labels[i]
        }
        spell_line_map
      }.reduce(&:merge)
    end

    def spell_fields()
      {
        "cantrip" => ["Spells 1014", "Spells 1016", "Spells 1017", "Spells 1018", "Spells 1019", "Spells 1020", "Spells 1021", "Spells 1022"],
        1 => ["Spells 1015", "Spells 1023", "Spells 1024", "Spells 1025", "Spells 1026", "Spells 1027", "Spells 1028", "Spells 1029", "Spells 1030", "Spells 1031", "Spells 1032", "Spells 1033"],
        2 => ["Spells 1046", "Spells 1034", "Spells 1035", "Spells 1036", "Spells 1037", "Spells 1038", "Spells 1039", "Spells 1040", "Spells 1041", "Spells 1042", "Spells 1043", "Spells 1044", "Spells 1045"],
        3 => ["Spells 1048", "Spells 1047", "Spells 1049", "Spells 1050", "Spells 1051", "Spells 1052", "Spells 1053", "Spells 1054", "Spells 1055", "Spells 1056", "Spells 1057", "Spells 1058", "Spells 1059"],
        4 => ["Spells 10461", "Spells 1060", "Spells 1062", "Spells 1063", "Spells 1064", "Spells 1065", "Spells 1066", "Spells 1067", "Spells 1068", "Spells 1069", "Spells 1070", "Spells 1071", "Spells 1072"],
        5 => ["Spells 1074", "Spells 1073", "Spells 1075", "Spells 1076", "Spells 1077", "Spells 1078", "Spells 1079", "Spells 1080", "Spells 1081"],
        6 => ["Spells 1083", "Spells 1082", "Spells 1084", "Spells 1085", "Spells 1086", "Spells 1087", "Spells 1088", "Spells 1089", "Spells 1090"],
        7 => ["Spells 1092", "Spells 1091", "Spells 1093", "Spells 1094", "Spells 1095", "Spells 1096", "Spells 1097", "Spells 1098", "Spells 1099"],
        8 => ["Spells 10101", "Spells 10100", "Spells 10102", "Spells 10103", "Spells 10104", "Spells 10105", "Spells 10106"],
        9 => ["Spells 10108", "Spells 10107", "Spells 10109", "Spells 101010", "Spells 101011", "Spells 101012", "Spells 101013"]
      }
    end

    def pdftk_path(config = configuration)
      pdf_configuration(config)['pdftk_path']
    end

    def pdf_configuration(config = configuration)
      # Temporary way to handle this config until I create a defaults config file
      {
        'blank_path' => 'charactersheet/blank',
        'sheet_names' => {
          'main' => 'main',
          'spellcasting' => 'spellcasting',
          'details' => 'details'
        },
        'pdftk_path' => '/usr/bin/pdftk'
      }.deep_merge(config.fetch('pdf', {}))
    end
  end
end