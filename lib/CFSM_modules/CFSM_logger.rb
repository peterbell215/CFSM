# @author Peter Bell
# Licensed under MIT.  See License file in top level directory.

# Module to provide logging support for the CFSM class.  Broken out for readability.  Included by CFSM class.
class CFSM
  # On the initial load which is assumed to be a `require` in the main Ruby file, we determine the path
  # name. Any paths in the log file will be relative to this home directory to keep the info manageable.
  @caller = caller
  @home_dir = Pathname.new(/(.*):[0-9]+:in `require'/.match(caller[4])[1]).parent
  def self.home_dir
    @home_dir
  end

  # Provide a logger to be used throughout the system.
  File.delete('cfsm.log') if File.exist?('cfsm.log')
  @logger = Logger.new('cfsm.log', 0)

  # We provide a logger to track how the system is performing.  This is really just a frontend for the Logger
  # class.
  def self.logger
    @logger
  end
end