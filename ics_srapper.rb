require "nokogiri"
require "open-uri"

fields_doc = Nokogiri::HTML open("https://www.iso.org/standards-catalogue/browse-by-ics.html")

fields_doc.xpath("//td[@data-title='ICS']").map do |ics|
  field_link = ics.xpath("a")
  field_href = link.attr("href").value
  field_code = link.text

  field_desc = ics.xpath("../td[@data-title='Field'").text

  
end