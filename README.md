# Dungeons & Dragons Character Generator

A generator for Dungeons & Dragons 5th edition characters.

## Installation

This ruby application relies on Ruby 2.6. To learn how to install Ruby, see this page:

<https://www.ruby-lang.org/en/documentation/installation/>

This application currently has no installation mechanism. Simply clone or download this repository to a desired location.

## Usage

This application has been tested on Linux, but is expected to work on any operating system that runs Ruby. Your mileage may vary when using Windows.

Execute `<path_to_repository>/bin/character_generator` in a terminal emulator. Enter the desired character level as the only argument. If no argument is supplied, a level 1 character is assumed.

## Caveats

The following discrepancies currently exist between the generator and Dungeons & Dragons rules and content:

* Other than spells and races, only content from the Player's Handbook is available.
* Standard humans are currently unavailable.
* Background skills always follow the background chosen.
* The generator does not produce name, alignment, or gender.
* Equipment is not selected.
* Proficiencies are never selected instead of skills, e.g. the rogue will never choose thieves' tools as a proficiency.
* The following feats are problematic, restricted, or unavailable:
  * Elemental Adept cannot be chosen multiple times.
  * Heavily Armored is unavailable because the generator does not currently support armor proficiencies.
  * Heavy Armor Master is unavailable because the generator does not currently support armor proficiencies.
  * Lightly Armored may be chosen despite the character already having proficiency with light armor.
  * Martial Adept does not choose which maneuvers are granted.
  * Medium Armor Master is unavailable because the generator does not currently support armor proficiencies.
  * Moderately Armored is unavailable because the generator does not currently support armor proficiencies.
  * Shield Master may be chosen despite the character not having proficiency with a shield.
  * Spell Sniper does not choose a cantrip.
  * Weapon Master may be chosen despite the character already having proficiency with all weapons. It also does not choose weapons.

