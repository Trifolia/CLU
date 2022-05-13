require_relative "lib/config"
require_relative "lib/server"

Config.load("config.json")
server = Server.new

server.start
server.run
