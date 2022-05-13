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
    Log.log("Received file list: #{json}", Log::Types::FileInfo)
    diff = []
    Config::PATHS.each do |path, sha|
      if sha != json[path]
        diff << path
      end
    end
    Log.log("File list diff: #{diff}", Log::Types::FileDiffs)

    Log.log("Sending files...", Log::Types::SendingFiles)
    @socket.puts("UPS\t#{diff.size}") # Send over file count
    @socket.puts("UPT") # Begin file transfer

    diff.each do |path|
      @last_sent_file = Time.now

      file = Base64.strict_encode64(File.read("client/#{path}"))
      size = 0

      io = StringIO.new(file)
      until io.eof?
        size += io.read(0xFFFF).length
      end

      Log.log("Sending file: #{path}, length: #{file.length}", Log::Types::SendingFile)
      @socket.puts("UPF\t#{path.sub(/\.\//, "")}\t#{size}")

      io.seek 0
      until io.eof?
        Log.log("Sending IO chunk from #{path} at #{io.pos}", Log::Types::SendingFile)
        @socket.puts(io.read(0xFFFF))
      end

      @socket.puts("UPE") # End file transfer
    end

    @socket.puts("UPQ") # Finished file transfer
    Log.log("Finished sending files.", Log::Types::SendingFileEnd)
    @socket.close
  end
end
