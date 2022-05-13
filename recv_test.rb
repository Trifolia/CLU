require "socket"
require "fileutils"
require "digest"
require "base64"
require "find"
require "json"

prefix = "test"
sock = TCPSocket.open("127.0.0.1", "6685")

puts sock.gets # UPR
hsh = {}
Dir.chdir(prefix)
Find.find(".") do |e|
  next if File.directory?(e)
  hsh[e] = Digest::SHA256.hexdigest File.read(e)
end
sock.puts(JSON.dump(hsh))

puts sock.gets # UPS
puts sock.gets # UPT

reading_file = false
file_contents = ""
path = ""
size = 0

loop do
  chunk = sock.gets

  if /\AUPQ$/ =~ chunk
    break
  elsif /\AUPF\t(.+)\t(.+)$/ =~ chunk
    puts "Reading file is true!" if reading_file
    reading_file = true
    path = $1
    size = $2.to_i
    puts "path: #{path}"
    puts "size: #{size}"
  elsif /\AUPE$/ =~ chunk
    reading_file = false
    puts "Writing file to disk: #{path}"
    if file_contents.length != size
        puts "File is larger than reported size by #{file_contents.length - size}"
    end
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, "w") do |f|
      f.write(Base64.strict_decode64(file_contents))
    end
    file_contents = ""
  elsif reading_file
    puts "Got chunk of #{path} with length of #{chunk.length}"
    file_contents += chunk
  end
end

puts "done"
