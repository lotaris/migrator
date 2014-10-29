require File.expand_path(File.join(File.dirname(__FILE__), 'svn_conf'))

module Lotaris
  
  module Subversion

    class Error < StandardError; end

    def self.repository_conf choice = nil, msg = nil
      svn_names = Lotaris::SubversionConfiguration.names.collect(&:to_s).sort
      msg ||= "Which SVN do you wish to use? (#{svn_names.join(', ')})? "
      svn_name = CL::UI.choose_from_or_exit msg, *(svn_names.push :choice => choice)
      Lotaris::SubversionConfiguration.new svn_name
    end

    private

    @@default_client_type = :cli
    CLIENT_TYPE_REGEXP = /^\s*(cli|ruby)\s*$/i

    public

    def self.default_client_type
      @@default_client_type
    end

    def self.register_options optparser
      optparser.on '--svn-client TYPE', [ :cli, :ruby ], 'choose the svn client, cli by default (cli or ruby)' do |value|
        @@default_client_type = value
      end
    end

    def self.client *args
      options = args.extract_options!
      type = options.delete(:type) || @@default_client_type
      args << options
      case type.to_s.strip.downcase
      when 'cli'
        require File.expand_path(File.join(File.dirname(__FILE__), 'svn_cli'))
        Lotaris::Subversion::Client::CLI.new *args
      when 'ruby'
        require File.expand_path(File.join(File.dirname(__FILE__), 'svn_ruby'))
        Lotaris::Subversion::Client::Ruby.new *args
      else
        raise Error, "Unknown subversion client type '#{type}'."
      end
    end

    module Client

      class Abstract

        def initialize *args
          # leave to implementation
        end

        def setup
          abstract
        end

        def checkout url, path, options = {}
          abstract
        end

        def add *paths
          abstract
        end

        def commit *paths
          abstract
        end

        def update *paths
          abstract
        end

        def status path, options = {}
          abstract
        end

        def list path, options = {}
          abstract
        end

        def exists? path
          abstract
        end

        def copy source_path, target_path, options = {}
          abstract
        end

        def mkdir path, options = {}
          abstract
        end

        def info path
          abstract
        end

        def revert *paths
          abstract
        end

        def delete *paths
          abstract
        end

        private

        def abstract
          raise Error, 'This is an abstract client. Use an implementation.'
        end
      end
    end
  end
end
