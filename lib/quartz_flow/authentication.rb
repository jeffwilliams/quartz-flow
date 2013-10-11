require 'digest'
require 'fileutils'
require 'quartz_flow/randstring'

class AccountInfo
  def initialize(login = nil, password_hash = nil, salt = nil)
    @login = login
    @password_hash = password_hash
    @salt = salt
  end
  attr_accessor :login
  attr_accessor :password_hash
  attr_accessor :salt
end  


class Authentication
  def initialize(password_file)
    @password_file = password_file
    @accounts = {}
    load_password_file(password_file)
  end

  def add_account(login, unhashed_password)
    if @accounts.has_key?login
      raise "The account #{login} already exists"
    end
    raise "Password cannot be empty" if unhashed_password.nil?
    add_account_internal(login, unhashed_password)
  end

  def del_account(login)
    if ! @accounts.has_key?(login)
      raise "The account #{login} does not exist"
    end
    del_account_internal(login)
  end

  # Returns true on success, false if the user cannot be authenticated
  def authenticate(login, password)
    # Reload the password file in case users were added/deleted
    acct = @accounts[login]
    return false if ! acct
    hashed = hash_password(password, acct.salt)
    hashed == acct.password_hash
  end
  
  private
  
  def load_password_file(filename)
    if File.exists? filename
      File.open(filename, "r") do |file|
        @accounts.clear
        file.each_line do |line|
          if line =~ /([^:]+):(.*):(.*)/
            @accounts[$1] = AccountInfo.new($1,$2,$3)
          end
        end
      end
    end
  end

  def add_account_internal(login, unhashed_password)
    salt = RandString.make_random_string(10)
    acct = AccountInfo.new(login, hash_password(unhashed_password, salt), salt)
    File.open(@password_file, "a") do |file|
      file.puts "#{login}:#{acct.password_hash}:#{salt}"
    end
    @accounts[login] = acct
  end

  def hash_password(pass, salt)
    Digest::SHA256.hexdigest(pass + salt)
  end

  def del_account_internal(login)
    tmpfile = "#{@password_file}.new"
    File.open(tmpfile, "w") do |outfile|
      File.open(@password_file, "r") do |infile|
        infile.each_line do |line|
          outfile.print line if line !~ /^#{login}:/
        end
      end
    end
    FileUtils.mv tmpfile, @password_file
  end

end
