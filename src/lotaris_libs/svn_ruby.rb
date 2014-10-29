require 'highline/import'
require File.expand_path('../utils/svn_ruby', File.dirname(__FILE__))

module Lotaris
  module Subversion
    module Client

      # Cross-platform subversion client using the SWIG ruby bindings.
      class Ruby < Lotaris::Subversion::Client::Abstract

        def initialize *args
          options = args.extract_options!
          @config = {
            'svn_user' => nil, 'svn_pass' => nil,
            'svn_repo_master' => options[:root_url],
            'svn_repo_working_copy' => options[:working_copy]
          }
        end

        def setup
          puts
          print 'Enter your subversion username: '
          username = ask('')
          print 'Enter your subversion password: '
          password = ask(''){ |q| q.echo = false }
          @config['svn_user'] = username || 'anonymous'
          @config['svn_pass'] = password || 'anonymous'
        end

        def checkout url, path, options = {}
          raw_client.checkout url, path, options
        end

        def add *files
          raw_client.add files
        end

        def commit *files
          options = files.extract_options!
          msg = options[:message]
          raw_client.commit files, msg
        end

        def update *files
          raw_client.update files
        end

        def status path, options = {}
          raw_client.status(path).try(:[], 0).try(:[], :status)
        end

        def list path, options = {}
          rev = options[:revision] || 'head'
          depth = options[:depth] || 'immediates'
          raw_client.list(path, rev, nil, depth).collect{ |e| e[:entry] }
        end

        def exists? path
          begin
            raw_client.info path
          rescue SvnWc::RepoAccessError
            false
          end
        end

        def copy source_path, target_path, options = {}
          msg = options[:message] || ''
          rev = options[:revision].try :to_i
          parents = options[:parents]

          # the revision must be given as peg rev and not operative rev
          # http://svnbook.red-bean.com/en/1.5/svn.advanced.pegrevs.html
          source_path = Svn::Client::CopySource.new source_path, nil, rev if rev

          raw_client.copy source_path, target_path, msg, rev, parents
        end

        def mkdir path, options = {}
          if options[:parents]
            raw_client.mkdir_p path, options
          else
            raw_client.mkdir path, options
          end
        end

        def info path
          raw = raw_client.info path
          {
            :url => raw[:url] || raw[:URL],
            :revision => raw[:rev],
            :repository_uuid => raw[:repos_UUID],
            :repository_root_url => raw[:repos_root_url] || raw[:repos_root_URL],
            :last_changed_author => raw[:last_changed_author],
            :last_changed_revision => raw[:last_changed_rev],
            :last_changed_date => raw[:last_changed_date]
          }
        end

        def revert *files
          raw_client.revert files
        end

        def delete *files
          raw_client.delete *files
        end

        private

        def raw_client
          @client ||= SubversionWithRubyBindings.new raw_client_configuration, false, false
        end

        def raw_client_configuration
          # svn_wc configuration is not required since we only use absolute paths
          YAML::dump(@config || {})
        end
      end
    end
  end
end
