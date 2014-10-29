
require 'svn_wc'

=begin
svn_wc installation procedure.

   Install with:
      gem install svn_wc

   You must also install the subversion ruby bindings.

      On Linux with yum:
         yum install subversion-ruby

      On Linux with aptitude:
         apt-get install libsvn-ruby

      On Mac OS X with Mac Ports:
         port install ruby
         port install subversion
         port install subversion-rubybindings

      On Max OS X with RVM:
         rvm use 1.8.7-p334 # not tested with other versions
         wget http://subversion.tigris.org/downloads/subversion-1.6.17.tar.gz # not tested with other versions
         tar -xzf subversion-1.6.17.tar.gz && cd subversion-1.6.17
         ./configure --with-ruby-sitedir=~/.rvm/rubies/ruby-1.8.7-p334/lib/ruby --prefix=~/.rvm/rubies/ruby-1.8.7-p334
         sudo make
         sudo make swig-rb
         sudo make install
         sudo make install-swig-rb
       
      On Windows with Cygwin, install the following packages:
         ruby (tested with 1.8.7)
         subversion (tested with 1.6.17)
         subversion-ruby|
=end

# Subversion client using the SWIG ruby bindings.
#
# ==== Documentation
# See https://github.com/dvwright/svn_wc/
#
# ==== Examples
#   svn_conf = YAML::dump({
#     'svn_user' => 'my_user',
#     'svn_pass' => 'my_pass',
#     'svn_repo_master' => 'http://svn.url',
#     'svn_repo_working_copy' => '/path/to/working/copy'
#   })
#   svn_client = SubversionWithRubyBindings.new YAML::dump(svn_conf), false, false
class SubversionWithRubyBindings < SvnWc::RepoAccess

  # See https://github.com/dvwright/svn_wc/
  def checkout url, path, options = {}
    begin
      svn_session do |ctx|
        ctx.checkout url, path, options[:revision], nil, options[:depth]
      end
    rescue Exception => err
      raise SvnWc::RepoAccessError, err.message
    end
  end

  # See https://github.com/dvwright/svn_wc/
  def copy src_paths, dst_path, msg = '', rev_or_copy_as_child = nil, make_parents = nil, revprop_table = nil
    begin
      svn_session(msg) do |ctx|
        ctx.copy(src_paths, dst_path, rev_or_copy_as_child, make_parents, revprop_table).try :revision
      end
    rescue Exception => err
      raise SvnWc::RepoAccessError, err.message
    end
  end

  # See https://github.com/dvwright/svn_wc/
  def mkdir *paths
    options = paths.extract_options!
    msg = options[:message] || ''
    begin
      svn_session(msg) do |ctx|
        ctx.mkdir *paths
      end
    rescue Exception => err
      raise SvnWc::RepoAccessError, err.message
    end
  end

  # See https://github.com/dvwright/svn_wc/
  def mkdir_p *paths
    options = paths.extract_options!
    msg = options[:message] || ''
    begin
      svn_session(msg) do |ctx|
        ctx.mkdir_p *paths
      end
    rescue Exception => err
      raise SvnWc::RepoAccessError, err.message
    end
  end

  # See https://github.com/dvwright/svn_wc/
  def delete *paths
    options = paths.extract_options!
    msg = options[:message] || ''
    begin
      svn_session(msg) do |ctx|
        ctx.delete *paths
      end
    rescue Exception => err
      raise SvnWc::RepoAccessError, err.message
    end
  end

  def svn_session(commit_msg = String.new) # :nodoc:
    ctx = Svn::Client::Context.new

    # Function for commit messages
    ctx.set_log_msg_func do |items|
      [true, commit_msg]
    end

    # don't fail on non CA signed ssl server
    ctx.add_ssl_server_trust_file_provider

    setup_auth_baton(ctx.auth_baton)
    ctx.add_username_provider

    # username and password
    ctx.add_simple_prompt_provider(0) do |cred, realm, username, may_save|
      cred.username = @svn_user
      cred.password = @svn_pass
      cred.may_save = true
    end

    return ctx unless block_given?

    begin
      yield ctx
      #ensure
      #  warning!?
      #  ctx.destroy
    end
  end
end
