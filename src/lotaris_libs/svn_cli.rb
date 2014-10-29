require 'rexml/document'

module Lotaris
  module Subversion
    module Client

      # Subversion client using the command-line svn binary. Only tested on UNIX platforms.
      class CLI < Lotaris::Subversion::Client::Abstract

        def initialize *args
          @binary = 'svn'
        end

        def setup
        end

        def checkout url, path, options = {}
          build_and_execute_command :checkout, url, path, keep(options, :revision, :depth)
        end

        def add *files
          build_and_execute_command :add, *files
        end

        def commit *files
          options = files.extract_options!
          options[:verbose] = true
          files << options
          extract_revision build_and_execute_command(:commit, *files)
        end

        def update *files
          build_and_execute_command :update, *files
        end

        def info file, options = {}
          options[:quiet] = true
          options[:verbose] = true
          options[:xml] = true
          doc = REXML::Document.new build_and_execute_command(:info, file, options)
          {
            :url => xml_text(doc, '/info/entry/url'),
            :revision => xml_attr(doc, '/info/entry', 'revision').to_i,
            :repository_uuid => xml_text(doc, '/info/entry/repository/uuid'),
            :repository_root_url => xml_text(doc, '/info/entry/repository/root'),
            :last_changed_author => xml_text(doc, '/info/entry/commit/author'),
            :last_changed_revision => xml_attr(doc, '/info/entry/commit', 'revision').to_i,
            :last_changed_date => xml_text(doc, '/info/entry/commit/date')
          }
        end

        def revert *files
          build_and_execute_command :revert, *files
        end

        def status path, options = {}
          options[:verbose] = true
          raw = build_and_execute_command(:status, path, options).sub(/^\s*/, '').sub(/\s.*$/, '').chomp
          raw.empty? ? nil : raw
        end

        def list path, options = {}
          options = keep options, :revision, :depth
          options[:revision] ||= 'head'
          options[:depth] ||= 'immediates'
          options[:verbose] = true
          build_and_execute_command(:list, path, options).split(/\n/).collect{ |e| e.chomp '/' }
        end

        def exists? path
          begin
            build_and_execute_command :info, path, :quiet => true
            true
          rescue StandardError
            false
          end
        end

        def copy source_path, target_path, options = {}
          options[:verbose] = true
          extract_revision build_and_execute_command(:copy, source_path, target_path, keep(options, :message, :revision, :parents))
        end

        def mkdir path, options = {}
          build_and_execute_command :mkdir, path, keep(options, :message, :parents)
        end

        def delete *files
          build_and_execute_command :delete, *files
        end

        private

        def xml_text doc, xpath
          value = nil
          doc.elements.each(xpath){ |e| value = e.text }
          value
        end

        def xml_attr doc, xpath, name
          value = nil
          doc.elements.each(xpath){ |e| value = e.attributes[name] }
          value
        end

        def extract_revision raw
          raw ? raw.chomp.split(/\n/).last.gsub(/[^\d]/, '').to_i : nil
        end

        def keep hash, *names
          names = ([ :quiet, :verbose ] + names).collect(&:to_s)
          hash.inject({}) do |memo,(k,v)|
            memo[k] = v if names.include? k.to_s
            memo
          end
        end

        # Builds an SVN commands with #build_command and executes it.
        def build_and_execute_command *args
          result = `#{build_command!(*args)}`
          raise StandardError, 'Could not execute SVN command.' if $? != 0
          result
        end

        # Does the magic.
        def build_command! *args
          options = args.extract_options!
          # extract verbose and quiet options
          verbose = options.delete :verbose
          quiet = options.delete :quiet
          # basic command is "BINARY [ARG]...", e.g. "svn checkout path path"
          command_array = [ @binary ] + args
          # any remaining options are assumed to be SVN options
          add_hash_arguments_to_command! command_array, options if options
          # redirect stdout and stderr
          redirect_command_output! command_array, verbose, quiet
          # build final command
          command_array.join(' ')
        end

        # Pushes stream redirections to the end of <tt>command_array</tt>.
        # STDOUT is redirected to <tt>/dev/null</tt> unless <tt>verbosity</tt>
        # is present. STDOUT is redirected to <tt>/dev/null</tt> unless
        # <tt>quiet</tt> is present.
        def redirect_command_output! command_array, verbose, quiet
          command_array << '1>/dev/null' unless verbose
          command_array << '2>/dev/null' if quiet
        end

        # Adds the command line options in <tt>h</tt> to <tt>command_array</tt>.
        # For each key/pair value, the key and value are pushed to the end of the
        # array.
        #
        # If <tt>k</tt> is one character long and is not a hyphen, it is prefixed
        # with one hyphen. If <tt>k</tt> at least two characters long and does not
        # start with a hyphen, it is prefixed with two hyphens. Otherwise, <tt>k</tt>
        # is pushed as is.
        #
        # ==== Examples
        #   a = [ 'svn', 'info' ]
        #   add_hash_arguments_to_command a, :depth => :empty, :r => 1234
        #   # => [ 'svn', 'info', '--depth', :empty, '-r', 1234 ]
        def add_hash_arguments_to_command! command_array, h
          h.each_pair do |k,v|
            if k.to_s.match /^\-/
              command_array << k
            elsif k.to_s.length >= 2
              command_array << "--#{k}"
            else
              command_array << "-#{k}"
            end
            unless v === true # switch, no value required
              command_array << if v.kind_of? String
                %/"#{v}"/
              else
                v
              end
            end
          end
        end
      end
    end
  end
end
