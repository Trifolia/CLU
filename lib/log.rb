require_relative "config"
require "paint"

module Log
  module LogLevel
    FATAL = 0
    ERROR = 1
    WARN = 2
    INFO = 3
    DEBUG = 4

    Strings = {
      FATAL => "FATAL: ",
      ERROR => "ERROR: ",
      WARN => "WARN: ",
      INFO => "INFO: ",
      DEBUG => "DEBUG: ",
    }
  end

  module Color
    FATAL = "FFBF3F"
    ERROR = "0703fc"
    WARN = "ffea00"
    INFO = "09ff00"
    DEBUG = "00fff7"

    Enum = {
      LogLevel::FATAL => FATAL,
      LogLevel::ERROR => ERROR,
      LogLevel::WARN => WARN,
      LogLevel::INFO => INFO,
      LogLevel::DEBUG => DEBUG,
    }
  end

  module Types
    include LogLevel
    ServerStart = INFO
    ServerStop = FATAL
    NetworkInfo = INFO
    GetFileInfo = INFO
    FileInfo = DEBUG
    FileDiffs = DEBUG
    SendingFiles = INFO
    SendingFile = DEBUG
    SendingFileEnd = INFO
  end

  def self.log(message, type)
    const = Object.const_get("Log::LogLevel::#{Config.config["log_level"]}")
    if const >= type
      warn Paint[LogLevel::Strings[type] + message, Color::Enum[type]]
    end
  end
end
