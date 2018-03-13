require "nokogiri"
require "open-uri"
require "json"

class WorkersPool
  attr_reader :threads

  def initialize(num_workers:, fields:)
    @num_workers = num_workers
    @fields = fields
    @fields_parsed = 0

    # Initialize file
    # File.open "ics.json", "w" do |f|
    #   f.write [].to_json
    # end

    mutex = Mutex.new

    @queue = Queue.new # SizedQueue.new(@num_workers * 2)
    @threads = @num_workers.times.map do
      Thread.new do
        until (item = @queue.pop) == :END

          # Progress
          @fields_parsed += 1
          print "Parse #{@fields_parsed} of #{@fields} Queue: #{@queue.size} Threads: #{@threads.size}   \r"

          mutex.synchronize do
            add_json_to_file(item.select { |k| [:code, :desc, :desc_full, :notes].include? k })
          end

          groups = self.class.get_groups(item[:href])
          # require "byebug"; byebug if item[:code].size > 2
          if groups.any?
            groups.each do |group|
              g = parse_ics(group)
              g[:desc_full] = (item[:desc_full] || (item[:desc] + ".")) + " " + g[:desc] + "."
              @queue << g
              @fields += 1
            end
          else
            @queue << :END if @queue.size == 0
          end
        end
      end
    end
  end

  def <<(url)
    @queue << url
  end

  def parse_ics(ics)
    link = ics.xpath("a")
    if link.any?
      href = link.attr("href").value
      code = link.text
    else
      href = nil
      code = ics.text
    end
    code = code.match(/[\d\.]+/).to_s
    # Don't scrape deep if it's subgroup
    href = nil if code.size > 6
    desc_doc = ics.xpath("../td[@data-title='Field']")
    desc = desc_doc.children.first.text.gsub("\n", "").strip
    notes = desc_doc.xpath("em").map do |note|
      note_link = note.xpath "a"
      if note_link.any?
        { text: "#{note.children.first.text}{ics-code}", "ics-code": link.text }
      else
        { text: note.text }
      end
    end
    { href: href, code: code, desc: desc, notes: notes }
  end

  def self.get_groups(href)
    if href
      doc = Nokogiri::HTML open("https://www.iso.org#{href}")
      doc.xpath("//td[@data-title='ICS']")
    else
      []
    end
  end

  private
  def add_json_to_file(code:, desc:, desc_full: nil, notes: [])
    gh = {
      code:            code,
      fieldcode:       code.match(/^\d+/).to_s,
      description:     desc
    }

    groupcode = code.match(/(?<=^\d{2}\.)\d+/)
    gh[:groupcode] = groupcode.to_s if groupcode

    subgroupcode = code.match(/(?<=^\d{2}\.\d{3}\.)\d+/)
    gh[:subgroupcode] = subgroupcode.to_s if subgroupcode

    if subgroupcode
      gh["@context"] = "https://isoics.org/ics/ns/subgroup.jsonld"
    elsif groupcode
      gh["@context"] = "https://isoics.org/jsonld/group.jsonld"
    else
      gh["@context"] = "https://isoics.org/jsonld/field.jsonld"
    end

    gh[:descriptionFull] = desc_full if desc_full
    gh[:notes] = notes if notes.any?

    # json = File.read "ics_#{code.gsub(".", "_")}.json"
    File.open "ics/#{code.gsub(".", "_")}.json", "w" do |f|
      f.write JSON.pretty_generate(gh)
    end
  end
end
