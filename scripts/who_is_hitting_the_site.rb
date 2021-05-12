#!/usr/local/bin/ruby

res = `cat /app/log/unicorn.stderr.log | awk '{print $1;}' | sort | uniq -c | sort -n | tail -n 10`

res.split("\n").each do |line|
  vals = line.split
  from_whom = vals.last.chop # They all end with a comma
  from_whom = '172.17.0.1 (internal to SI)' if from_whom == '172.17.0.1'
  puts "* **#{vals.first} hits** from #{from_whom}"
end
