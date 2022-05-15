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
    @socket.closed? # || ((Time.now - @last_sent_file).to_i >= 60) # Client probably disconnected
  end

  def tell(*args)
    @socket.send(args.join("\n"), 0)
  end

  def form_message(*args)
    args.map { |a| a.to_s }.join("\t")
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
    @socket.puts form_message("UPS", diff.size) # Send over file count

    # Notify client if there needs to be a hard reset
    if diff.empty?
      @socket.puts "UPQ"
      @socket.close
      return
    end

    unless diff.grep(/(\.dll|\.exe|\.so)/).empty?
      @socket.puts "UPH"
    else
      @socket.puts "UPC"
    end

    begin
      diff.each do |path|
        @last_sent_file = Time.now

        file = Base64.strict_encode64(File.binread("client/#{path}"))
        size = file.length

        Log.log("Sending file: #{path}, length: #{file.length}", Log::Types::SendingFile)
        tell(
          form_message("UPF", path.sub(/\.\//, ""), size)
        )

        io = StringIO.new(file)
        until io.eof?
          puts "Sending file chunk: #{path} (#{io.pos}/#{size})"
          tell(io.read(0xFFFF))
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
