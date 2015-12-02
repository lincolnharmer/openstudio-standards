$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'minitest/autorun'
require 'minitest/reporters'
require 'openstudio'
require 'openstudio-standards'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'json'
require 'fileutils'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new # spec-like progress