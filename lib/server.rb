require_relative "log"
require_relative "config"
require_relative "client"
require "socket"

class Server
  def initialize
    Log.log(
      "Server ip: #{Config.config["ip"]}\nServer port: #{Config.config["port"]}",
      Log::Types::NetworkInfo
    )

    @server = TCPServer.new(Config.config["ip"], Config.config["port"])
    @clients = []
  end

  def start
    Log.log("Server starting...", Log::Types::ServerStart)
    Log.log("Server started successfully", Log::Types::ServerStart)
  end

  def run
    begin
      until @shutdown
        begin
          connection = @server.accept_nonblock
        rescue IO::WaitReadable, Errno::EINTR
          @clients.reject! do |client|
            if client.finished
              Log.log("Client disconnected", Log::Types::NetworkInfo)
              true
            end
          end
          retry
        rescue IOError
          break
        end
        Log.log("Client connected", Log::Types::NetworkInfo)
        @clients << Client.new(connection)
        @clients.last.async.start
      end
      shutdown unless @shutdown
    rescue Interrupt
      if @tried_quit
        shutdown
      else
        @tried_quit = true
        Log.log("Press Ctrl + C again to quit.", Log::Types::ServerStop)
        retry
      end
    rescue StandardError => e
      Log.log("#{e.inspect}\n#{e.backtrace.join("\n")}", Log::Types::ServerStop)
      shutdown unless @shutdown
    end
  end

  def shutdown
    @shutdown = true
    Log.log("Shutting down...", Log::Types::ServerStop)

    @server.close rescue nil
    Log.log("Shut down gracefully.", Log::Types::ServerStop)
  end
end
