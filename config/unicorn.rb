app_dir = "/app"

working_directory app_dir

pid "#{app_dir}/tmp/unicorn.pid"

stderr_path "#{app_dir}/log/unicorn.stderr.log"
# STDOUT turns out to be pretty useless: it just prints "{:join=>", ", :open=>"(", :close=>")"}" over and over. :|
# NOTE: the default, if missing, is /dev/null ...which we want in this case.
# stdout_path "#{app_dir}/log/unicorn.stdout.log"

worker_processes 9
listen "#{app_dir}/tmp/unicorn.sock", :backlog => 64
timeout 905 # Setting this HIGHER than unicorn, so that we don't reap processes unless we have to.
