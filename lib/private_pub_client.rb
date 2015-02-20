require "digest/sha1"
require "net/http"
require "net/https"
require "json"


module PrivatePub
  class Error < StandardError; end

  class << self
    attr_reader :config

    # Resets the configuration to the default (empty hash)
    def reset_config
      @config = {}
    end

    # Loads the  configuration from a given YAML file and environment (such as production)
    def load_config(filename, environment)
      yaml = YAML.load_file(filename)[environment.to_s]
      raise ArgumentError, "The #{environment} environment does not exist in #{filename}" if yaml.nil?
      yaml.each { |k, v| config[k.to_sym] = v }
      config[:ports] = config[:ports].split(' ') if config.key?(:ports)
    end

    # Publish the given data to a specific channel. This ends up sending
    # a Net::HTTP POST request to the Faye server.
    def publish_to(channel, data)
      publish_message(message(channel, data))
    end

    # Sends the given message hash to the Faye server using Net::HTTP.
    def publish_message(message)
      raise Error, "No server specified, ensure private_pub.yml was loaded properly." unless config[:hostname]
      url = URI.parse(server_url)

      form = Net::HTTP::Post.new(url.path.empty? ? '/' : url.path)
      form.set_form_data(:message => message.to_json)

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = url.scheme == "https"
      http.start {|h| h.request(form)}
    end

    # Returns a message hash for sending to Faye
    def message(channel, data)
      message = {:channel => channel, :data => {:channel => channel}, :ext => {:private_pub_token => config[:secret_token]}}
      if data.kind_of? String
        message[:data][:eval] = data
      else
        message[:data][:data] = data
      end
      message
    end


    # Determine if the signature has expired given a timestamp.
    def signature_expired?(timestamp)
      timestamp < ((Time.now.to_f - config[:signature_expiration])*1000).round if config[:signature_expiration]
    end

    # Returns the Faye Rack application.
    # Any options given are passed to the Faye::RackAdapter.
    def faye_client
      Faye::Client.new(server_url)
    end

    # Return server url with random ports
    def server_url
      port = config[:ports].sample
      "#{config[:hostname]}:#{port}#{config[:pathname]}"
    end

  end

  reset_config
end
