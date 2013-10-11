require 'thread'
require 'singleton'
require 'quartz_flow/randstring'

class Session
  def initialize(sid = nil, login = nil, length = 60*60)
    @sid = sid
    @login = login
    # Make a 1 hr session
    @expiry = Time.new + length
  end
  attr_accessor :sid
  attr_accessor :login
  attr_accessor :expiry

  def expired?
    @expiry < Time.new
  end
end

# Use SessionStore.instance to access the singleton.
class SessionStore
  include Singleton

  def initialize
    @sessions = {}  
    @session_mutex = Mutex.new
    @audit_thread = Thread.new do
      while true
        begin
          sleep 10
          audit_sessions  
        rescue
        end
      end
    end
  end

  # Start a new session for the specified user.
  def start_session(login)
    sid = nil
    while ! sid || @sessions.has_key?(sid)
      sid = RandString.make_random_string(256)
    end
    @session_mutex.synchronize do 
      @sessions[sid] = Session.new(sid, login)
    end
    sid
  end

  def end_session(sid)
    return if ! sid
    @session_mutex.synchronize do
      @sessions.delete sid
    end
  end
  
  def valid_session?(sid)
    rc = false
    return rc if ! sid
    @session_mutex.synchronize do
      session = @sessions[sid]
      if session != nil 
        if !session.expired?
          rc = true
        else
          @sessions.delete sid
        end
      end
    end
    rc
  end

  def audit_sessions
    @sessions.each do |k,session|
      if session.expired?
        @session_mutex.synchronize do
          @sessions.delete k
        end
      end
    end
  end 
end
