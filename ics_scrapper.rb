require_relative "workers_pool"

fields = WorkersPool.get_groups("/standards-catalogue/browse-by-ics.html")

num_workers = ARGV[0].to_i
num_workers = 3 if num_workers < 1 || num_workers > 3
workers = WorkersPool.new(num_workers: num_workers, fields: fields.size)

fields.each do |field|
  workers << workers.parse_ics(field)
end

workers.threads.each { |t| t.join }
print "\n"