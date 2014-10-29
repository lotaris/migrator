require 'fileutils'
require File.join(File.dirname(__FILE__), 'signals')

module CL

  # Temporary directory that is automatically deleted on success
  # or failure of the script.
  class TemporaryDirectory

    # Returns a new temporary directory created at the specified
    # <tt>path</tt>. Intermediate directories will be created as
    # required. The directory and its contents will automatically
    # be deleted on success or failure of the script.
    def initialize path
      @path = path
      create
      #CL::Signals.do_on_term{ delete }
      #CL::Signals.do_on_success{ delete }
    end

    # Returns the path to this directory.
    def to_s
      @path
    end

    private

    # Creates this temporary directory at the path specified at
    # construction.
    def create
      FileUtils.mkdir_p @path
    end

    # Recursively deletes this temporary directory.
    def delete
      FileUtils.rm_rf @path
    end
  end
end
