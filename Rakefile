require 'resque'
require 'tempfile'
require 'resque/tasks'
require 'resque/scheduler'
require 'resque_scheduler/tasks'
require 'resque_scheduler'
require 'resque_scheduler/server'
require 'yaml'
require './jobs.rb'

$cfg = YAML.load_file('config.yml')

namespace :resque do
  task :setup do
    Resque.redis            = $cfg['redis']
    Resque.schedule         = YAML.load_file('schedule.yml')
    Resque.logger           = MonoLogger.new($cfg['log_file'])
    Resque.logger.level     = Logger::INFO
  end
end

namespace :kindler do
  task :start => :"resque:setup" do
    begin
      Resque.redis.redis.ping
    rescue Redis::CannotConnectError
      puts "No redis instance running on #{$cfg['redis']}."
      abort
    end
    if !Dir.exists? $cfg['files_path']
      puts "Must create the file path specified in config.yml"
      puts "e.g. `mkdir #{$cfg['file_path']}`"
      abort
    end

    i = 0
    pidfile = $cfg['pid_file']

    queues = ['email', 'fetch_articles', 'fetch_emails']

    bg ="BACKGROUND=yes"

    queues.each do |queue|
      $cfg["#{queue}_workers"].to_i.times do
        q = "QUEUE=#{queue}"
        p = "PIDFILE=#{pidfile + (i+=1).to_s}"
        `#{bg} #{q} #{p} rake resque:work`
      end
    end

    `#{bg} PIDFILE=#{pidfile + (i+=1).to_s} rake resque:scheduler`

    # wait for all workers to start up
    # put their pids into the pidfile
    File.open(pidfile, "w+") do |f|
      (1..i).each do |x|
        pfile_path = pidfile + x.to_s
        while !File.exists?(pfile_path)
          Kernel.sleep(1)
        end

        f.write(IO.read(pfile_path) << "\n")
        File.delete(pfile_path)
      end
    end
  end

  task :stop do
    pidfile = $cfg['pid_file']

    if File.exists? pidfile
      IO.readlines(pidfile).each do |line|
        begin
          Process.kill(9, line.to_i)
        rescue
          next
        end
      end
      File.delete pidfile
    else
      puts "Not running."
    end
    begin
      a_worker = Resque::Worker.all.empty? ? nil : Resque::Worker.all.first
      a_worker.prune_dead_workers if a_worker
    rescue Redis::CannotConnectError
      puts "No redis instance running on #{$cfg['redis']}."
    end
  end
end
