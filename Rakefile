desc "Generates the sha256 of client files for comparison"
task :generate do
  require "find"
  require "digest"
  require "json"

  raise "Missing client dir!" unless File.directory?("client")
  File.open("paths.json", "w") do |f|
    hsh = {}
    Dir.chdir("client")
    Find.find(".") do |e|
      next if File.directory?(e)
      hsh[e] = Digest::SHA256.hexdigest File.read(e)
    end
    f.write JSON.pretty_generate(hsh)
  end
end
