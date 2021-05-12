def show_count(resource, field, options = {})
  count = resource.send(field).count
  unless count == 0
    print "#{count} #{field}"
    print '; ' unless options[:last]
  end
end

desc 'List resources!'
task resources: :environment do
  Resource.all.each do |resource|
    # May as well fix counts:
    nodes_count = resource.nodes.count
    if nodes_count != resource.nodes_count
      resource.update_attribute(:nodes_count, nodes_count)
    end
    printf('% 3d', resource.id)
    print ": (#{resource.abbr}) #{resource.name}: "
    print "#{resource.nodes_count} nodes; "
    show_count(resource, :scientific_names, last: true)
    print "\n"
    print "     "
    if (log = resource.import_logs.last)
      print "(#{log.status}) "
      if log.status != 'completed'
        ev = log.import_events.last
        puts "[(#{ev.cat}) #{ev.body}]"
        print "     "
      end
    else
      print "NO IMPORT LOGS. "
    end
    traits = TraitBank::Queries.count_by_resource(resource.id)
    print "#{traits} traits " unless traits.zero?
    show_count(resource, :media)
    show_count(resource, :articles)
    show_count(resource, :links)
    show_count(resource, :vernaculars)
    show_count(resource, :referents, last: true)
    print "\n"
  end
end

namespace :resources do
  task sync: :environment do
    usage = '$ rake resources:sync ABBR=<abbr>'
    abbr = ENV['ABBR']

    raise usage if abbr.nil?
    Resource::RemoteImporter.new(abbr).import
  end
end
