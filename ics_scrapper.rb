require "nokogiri"
require "open-uri"
require "json"

def get_groups(href)
  if href
    doc = Nokogiri::HTML open("https://www.iso.org#{href}")
    doc.xpath("//td[@data-title='ICS']")
  else
    []
  end
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

  [href, code, desc, notes]
end

def group_hash(code:, desc:, desc_full:, notes: [])
  
  gh = {
    "@context": "https://isoics.org/ics/ns/subgroup.jsonld",
    code:            code,
    fieldcode:       code.match(/^\d+/).to_s,
    description:     desc, 
    descriptionFull: desc_full
  }

  groupcode = code.match(/(?<=^\d{2}\.)\d+/)
  gh[:groupcode] = groupcode.to_s if groupcode

  subgroupcode = code.match(/(?<=^\d{2}\.\d{3}\.)\d+/)
  gh[:subgroupcode] = subgroupcode.to_s if subgroupcode

  gh[:notes] = notes if notes.any?
  gh
end

fields_doc = Nokogiri::HTML open("https://www.iso.org/standards-catalogue/browse-by-ics.html")

# jsonld = {
#   "@context": {
#     code: "https://isoics.org/ics/ns#code",
#     fieldcode: "https://isoics.org/ics/ns#fieldcode",
#     description: "https://isoics.org/ics/ns#description"
#   }
# }
# jsonld["@set"] = []

jsonld = []
fields_doc.xpath("//td[@data-title='ICS']").each do |field|
  group_href, field_code, field_desc = parse_ics field
  puts "Field: #{field_code}"
  groups = get_groups group_href

  if groups.any?
    groups.each do |group|
      subgroup_href, group_code, group_desc, group_notes = parse_ics group
      puts "Group: #{group_code}"
      subgroups = get_groups subgroup_href

      if subgroups.any?
        subgroups.each do |subgroup|
          _href, subgroup_code, subgroup_desc, subgroup_notes = parse_ics subgroup
          puts "Subgroup: #{subgroup_code}"
          desc_full = "#{field_desc}. #{group_desc}. #{subgroup_desc}."
          jsonld << group_hash(code: subgroup_code, desc: subgroup_desc, desc_full: desc_full, notes: subgroup_notes)
        end
      else
        desc_full = "#{field_desc}. #{group_desc}."
        jsonld << group_hash(code: group_code, desc: group_desc, desc_full: desc_full, notes: group_notes)
      end
    end
  else
    jsonld << group_hash(code: field_code, desc: field_desc, desc_full: field_desc)
  end
end

File.open "ics.json", "w" do |f|
  f.write jsonld.to_json
end
