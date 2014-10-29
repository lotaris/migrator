require 'yaml'
require File.join(File.dirname(__FILE__), 'utils')

# Classes with functionality that is specific to Lotaris.
module Lotaris

  # Attemps to traverse the configuration hierarchy using the
  # given arguments.
  #
  # ==== Examples
  # Calling
  #   Lotaris.conf :svn, :lme, :root
  #
  # is equivalent to calling
  #   Lotaris::CONFIGURATION[:svn][:lme][:root]
  #
  # with the added bonus that the method will return nil instead
  # of raising an error if any of the elements does not exist.
  def self.conf *args
    args.inject(raw_configuration){ |memo,arg| memo.try :[], arg }
  end

  def self.user_conf *args
    args.inject(raw_user_configuration){ |memo,arg| memo.try :[], arg }
  end

  def self.username
    user_conf(:user, :name) || ENV['USER'] || ENV['USERNAME']
  end

  def self.process_path path
    path.gsub /\%\{USER\}/, username
  end

  private

  @@configuration = nil
  @@user_configuration = nil

  def self.raw_configuration
    @@configuration ||= YAML::load(File.open(File.expand_path('../resources/lotaris.yml', File.dirname(__FILE__))))
  end

  def self.raw_user_configuration
    unless @@user_configuration
      config = File.join(File.expand_path('~'), '.lotaris', 'config.yml')
      @@user_configuration ||= YAML::load(File.open(config)) if File.exists? config
    end
    @@user_configuration
  end
end

# Auto-load libs.
[ :db, :svn ].each do |lib|
  require File.join(File.dirname(__FILE__), 'lotaris_libs', lib.to_s)
end
