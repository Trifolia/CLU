require "concurrent"
require "json"
require_relative "config"
require_relative "log"
require "base64"
require "stringio"

class Client
  include Concurrent::Async

  def initialize(socket)
    @socket = socket
    @last_sent_file = Time.now
  end

  def finished
    @socket.closed? || ((Time.now - @last_sent_file).to_i >= 60) # Client probably disconnected
  end

  def start
    @socket.puts("UPR") # Request file list
    Log.log("Requesting file list...", Log::Types::GetFileInfo)
    json = JSON.load(@socket.gets)
    Log.log("Received file list.", Log::Types::FileInfo)
    diff = []
    Config::PATHS.each do |path, sha|
      if sha != json[path]
        puts [path, sha, json[path]].join("\t")
        diff << path
      end
    end

    Log.log("Sending files...", Log::Types::SendingFiles)
    @socket.puts("UPS\t#{diff.size}") # Send over file count
    puts "sent file count"

    begin
      diff.each do |path|
        @last_sent_file = Time.now

        file = Base64.strict_encode64(File.binread("client/#{path}"))
        size = file.length

        Log.log("Sending file: #{path}, length: #{file.length}", Log::Types::SendingFile)
        @socket.send("UPF\t#{path.sub(/\.\//, "")}\t#{size}", 0)

        io = StringIO.new(file)
        until io.eof?
          puts "Sending file chunk: #{path} (#{io.pos}/#{size})"
          @socket.send(io.read(0xFFFF), 0)
        end

        @socket.gets # Wait for confirmation
      end

      @socket.puts("UPQ") # Finished file transfer
      Log.log("Finished sending files.", Log::Types::SendingFileEnd)
      @socket.close
    end
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    @socket.close
  end
end
