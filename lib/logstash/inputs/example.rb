# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "stud/interval"
require "socket" # for Socket.gethostname

# Generate a repeating message.
#
# This plugin is intented only as an example.

class LogStash::Inputs::Example < LogStash::Inputs::Base
  config_name "example"

  # If undefined, Logstash will complain, even if codec is unused.
  default :codec, "plain" 

  # The message string to use in the event.
  config :message, :validate => :string, :default => "Hello World!"

  # Set how frequently messages should be sent.
  #
  # The default, `1`, means send a message every second.
  config :interval, :validate => :number, :default => 1

  # Refresh Token
  config :refresh_token, :validate => :string, :required => :true

  config :client_id, :validate => :string, :required => :true

  config :client_secret, :validate => :string, :required => :true

  config :grant_type, :validate => :string, :required => :true

  public
  def register
    require "ftw"

    # Agent for making a request
    @agent = FTW::Agent.new
    
    # As mentioned in the auth docs
    @content_type = "application/x-www-form-urlencoded"

    # Auth URL for refresh
    @auth_url = "https://www.googleapis.com/oauth2/v3/token"

    @host = Socket.gethostname
  end # def register

  def run(queue)
    Stud.interval(@interval) do
      
      begin
        request_data = Hash.new
        request_data['refresh_token'] = @refresh_token
        request_data['client_id'] = @client_id
        request_data['client_secret'] = @client_secret
        request_data['grant_type'] = @grant_type

        @agent.configuration[FTW::Agent::SSL_VERSION] = "TLSv1.1"
        request = @agent.post(@auth_url)
        request["Content-Type"] = @content_type
        request.body = encode(request_data)


        #request = @agent.get("http://www.google.com/")
        response = @agent.execute(request)
        puts response.body.read
        
        #response = @agent.execute(request)

        #Consume body to let this connection be reused
        rbody = "hello"
        #response.read_body { |c| rbody << c }
        #puts rbody


      rescue Exception => e
        @logger.warn("Unhandled exception", :request => request, :response => response, :exception => e, :stacktrace => e.backtrace)
      end
      event = LogStash::Event.new("message" => @auth_url, "host" => @host)
      
      decorate(event)
      queue << event
    end # loop
  end # def run

  def encode(hash)
    return hash.collect do |key, value|
      CGI.escape(key) + "=" + CGI.escape(value)
    end.join("&")
  end # def encode

end # class LogStash::Inputs::Example