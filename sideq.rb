#!/usr/bin/env ruby

require 'optparse'
require 'sidekiq'
require 'sidekiq/api'

RACK_ENV = ENV['RACK_ENV'] || "development"

class Parser
  def self.parse(arguments)
    options = { "host" => "localhost",
                "port" => 6379,
                "db"   => 0 }

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options] command [subcommand]\n" <<
                    "\n" <<
                    "Commands and subcommands:\n" <<
                    "stats                    Print sidekiq statistics\n" <<
                    "queue list               List all known queues\n" <<
                    "retry list               List contents of the retry set\n" <<
                    "retry show jid [jid ...] Show details of entrie sin the retry set\n" <<
                    "retry del jid [jid ...]  Delete entries from the retry set\n" <<
                    "retry kill jid [jid ...] Move jobs from the retry set to the dead set\n" <<
                    "retry now jid [jid ...]  Retry jobs in the retry set right now\n" <<
                    "retry clear              Clears all entries in the retry set\n" <<
                    "dead list                List contents of the dead set\n" <<
                    "dead show jid [jid...]   Show details of entries in the dead set\n" <<
                    "dead del jid [jid...]    Delete jobs from the dead set\n" <<
                    "dead now jid [jid...]    Retry jobs from the dead set right now\n" <<
                    "dead clear               Clears all entries of the dead set\n" <<
                    "processes list           Lists all processes known to sidekiq\n" <<
                    "processes quiet          Send the quiet signal to all sidekiq processes\n" <<
                    "processes kill           Send the kill signal to all sidekiq processes\n" <<
                    "processes clean          Clear dead process entries from the process list\n" <<
                    "workers list             List all workers\n"
      opts.separator "\nOptions:\n"

      opts.on("-n redisdb", "--database=redisdb", "Number of the redis database") do |n|
        options["db"] = n.to_i
      end

      opts.on("-h hostname", "--host=hostname", "Hostname of the redis instance") do |n|
        options["host"] = n
      end

      opts.on("-p port", "--port=port", "Portnumber of the redis instance" ) do |n|
        options["port"] = n.to_i
      end

      opts.on( "-u redis_url", "--url", "URL to connect to (redis://host:port/db)" ) do |n|
        options["url"] = n
      end

      opts.on("--help", "Prints this help") do
        puts opts
        exit
      end
    end

    opt_parser.parse!(arguments)
    return options
  end
end

def print_stats
  stats = Sidekiq::Stats.new
  retry_set = Sidekiq::RetrySet.new
  dead_set = Sidekiq::DeadSet.new

  puts "Processed: #{stats.processed}"
  puts "Failed: #{stats.failed}"
  puts "Scheduled size: #{stats.scheduled_size}"
  puts "Retry size: #{stats.retry_size}"
  puts "Dead size: #{stats.dead_size}"
  puts "Enqueued: #{stats.enqueued}"
  puts "Processes: #{stats.processes_size}"
  puts "Workers: #{stats.workers_size}"
  puts "Default queue latency: #{stats.default_queue_latency}"

  puts "Queues: dead:  #{dead_set.size}"
  puts "        retry: #{retry_set.size}"
  stats.queues.each do |(queue_name, queue_size)|
    puts "        #{queue_name}: #{queue_size}"
  end
end

def print_queues
  Sidekiq::Queue.all.each do |queue|
    printf "%30s: %5d (%8.2f s latency) %spaused\n", 
             queue.name,
             queue.size,
             queue.latency,
             queue.paused? ? '' : "not "
  end
  retry_set = Sidekiq::RetrySet.new
  printf "%30s: %5d\n", "retry", retry_set.size
  dead_set = Sidekiq::DeadSet.new
  printf "%30s: %5d\n", "dead", dead_set.size

end

def print_retry
  retry_set = Sidekiq::RetrySet.new
  puts "Retry entries: #{retry_set.size}"
  retry_set.each do |job|
    printf( "%24s - %19s\n  %-22s - %-37s\n  e: %19s - f: %19s\n  retry (%2d) at %-19s Continue retries?: %s\n  %s\n", 
            job.jid,
            job.created_at.strftime( "%F %T" ),
            job.display_class,
            job.item["error_class"],
            job.enqueued_at.strftime( "%F %T" ),
            Time.at( job.item["failed_at"] ).strftime( "%F %T" ),
            job.item["retry_count"],
            job.item["retried_at"] ? Time.at( job.item["retried_at"] ).strftime( "%F %T" ) : "never",
            job.item["retry"],
            "#{job.item["error_class"]}: #{job.item["error_message"][0,77-job.item["error_class"].size]}" )
    puts
  end
end

def show_retry_entries
  retry_set = Sidekiq::RetrySet.new
  retry_set.each do |job|
    next unless ARGV.include?( job.jid )

    puts "JobID:         #{job.jid}"
    puts "Created at:    #{job.created_at.strftime( "%F %T" )}"
    puts "Enqueued at:   #{job.enqueued_at.strftime( "%F %T")}"
    puts "Worker class:  #{job.display_class}"
    puts "Arguments:     #{job.display_args}"
    puts "Failed at:     #{Time.at( job.item["failed_at"] ).strftime( "%F %T" )}"
    puts "Retried at:    #{job.item["retried_at"] ? Time.at( job.item["retried_at"] ).strftime( "%F %T" ) : "never"}"
    puts "Retries:       #{job.item["retry_count"]}"
    puts "Retry?:        #{job.item["retry"]}"
    puts "Error Class:   #{job.item["error_class"]}"
    puts "Error Message: #{job.item["error_message"]}"
    puts
  end
end

def delete_retry_entries
  retry_set = Sidekiq::RetrySet.new
  deleted = 0
  ARGV.each do |job_id|
    # TODO: Inefficient in the free(beer) sidekiq version; 
    #       find something more efficient here (sr 2016-04-06)
    job = retry_set.find_job( job_id )
    if job
      job.delete
      puts "#{job_id}: deleted"
      deleted += 1
    else
      puts "#{job_id}: not found"
    end
  end
  puts "Retry Set: Deleted #{deleted} entries"
end

def kill_retry_entries
  retry_set = Sidekiq::RetrySet.new
  killed = 0
  ARGV.each do |job_id|
    # TODO: Inefficient in the free(beer) sidekiq version; 
    #       find something more efficient here (sr 2016-04-06)
    job = retry_set.find_job( job_id )
    if job
      begin
        job.kill
        puts "#{job_id}: moved to dead set"
        killed += 1
      rescue
        puts "#{job_id}: failed - #{$!.message}"
      end
    else
      puts "#{job_id}: not found"
    end
  end

  puts "Retry Set: Moved #{killed} entries to Dead Set"
end

def retry_retry_entries
  retry_set = Sidekiq::RetrySet.new
  retried = 0
  ARGV.each do |job_id|
    # TODO: Inefficient in the free(beer) sidekiq version; 
    #       find something more efficient here (sr 2016-04-06)
    job = retry_set.find_job( job_id )
    if job
      begin
        job.retry
        puts "#{job_id}: retrying"
        retried += 1
      rescue
        puts "#{job_id}: failed - #{$!.message}"
      end
    else
      puts "#{job_id}: not found"
    end
  end

  puts "Retry Set: Retried #{retried} entries"
end

def clear_retry_entries
  retry_set = Sidekiq::RetrySet.new
  size = retry_set.size
  retry_set.clear
  puts "Retry Set: Deleted #{size} entries"
end

def print_dead
  dead_set = Sidekiq::DeadSet.new
  puts "Dead entries: #{dead_set.size}"
  dead_set.each do |job|
    printf( "%24s - %19s\n  %-22s - %-37s\n  e: %19s - f: %19s\n  retry (%2d) at %-19s Continue retries?: %s\n  %s\n", 
            job.jid,
            job.created_at.strftime( "%F %T" ),
            job.display_class,
            job.item["error_class"],
            job.enqueued_at.strftime( "%F %T" ),
            Time.at( job.item["failed_at"] ).strftime( "%F %T" ),
            job.item["retry_count"],
            job.item["retried_at"] ? Time.at( job.item["retried_at"] ).strftime( "%F %T" ) : "never",
            job.item["retry"],
            "#{job.item["error_class"]}: #{job.item["error_message"][0,77-job.item["error_class"].size]}" )
    puts
  end
end

def show_dead_entries
  dead_set = Sidekiq::DeadSet.new
  dead_set.each do |job|
    next unless ARGV.include?( job.jid )

    puts "JobID:         #{job.jid}"
    puts "Created at:    #{job.created_at.strftime( "%F %T" )}"
    puts "Enqueued at:   #{job.enqueued_at.strftime( "%F %T")}"
    puts "Worker class:  #{job.display_class}"
    puts "Arguments:     #{job.display_args}"
    puts "Failed at:     #{Time.at( job.item["failed_at"] ).strftime( "%F %T" )}"
    puts "Retried at:    #{job.item["retried_at"] ? Time.at( job.item["retried_at"] ).strftime( "%F %T" ) : "never"}"
    puts "Retries:       #{job.item["retry_count"]}"
    puts "Retry?:        #{job.item["retry"]}"
    puts "Error Class:   #{job.item["error_class"]}"
    puts "Error Message: #{job.item["error_message"]}"
    puts
  end
end

def delete_dead_entries
  dead_set = Sidekiq::DeadSet.new
  deleted = 0
  ARGV.each do |job_id|
    # TODO: Inefficient in the free(beer) sidekiq version; 
    #       find something more efficient here (sr 2016-04-06)
    job = dead_set.find_job( job_id )
    if job
      job.delete
      puts "#{job_id}: deleted"
      deleted += 1
    else
      puts "#{job_id}: not found"
    end
  end
  puts "Dead Set: Deleted #{deleted} entries"
end

def retry_dead_entries
  dead_set = Sidekiq::DeadSet.new
  retried = 0
  ARGV.each do |job_id|
    # TODO: Inefficient in the free(beer) sidekiq version; 
    #       find something more efficient here (sr 2016-04-06)
    job = dead_set.find_job( job_id )
    if job
      begin
        job.retry
        puts "#{job_id}: retrying"
        retried += 1
      rescue
        puts "#{job_id}: failed - #{$!.message}"
      end
    else
      puts "#{job_id}: not found"
    end
  end

  puts "Dead Set: Retried #{retried} entries"
end

def clear_dead_entries
  dead_set = Sidekiq::DeadSet.new
  size = dead_set.size
  dead_set.clear
  puts "Dead Set: Deleted #{size} entries"
end

def print_processes
  process_set = Sidekiq::ProcessSet.new

  puts "Processes: #{process_set.size}"
  process_set.each do |process|
    STDERR.puts process.inspect
  end
end

def quiet_processes
  process_set = Sidekiq::ProcessSet.new
  size = process_set.size
  process_set.each do |process|
    process.quiet!
  end
  puts "Quieted #{size} processes"
end

def kill_processes
  process_set = Sidekiq::ProcessSet.new
  size = process_set.size
  process_set.each do |process|
    process.kill!
  end
  puts "Killed #{size} processes"
end

def clean_processes
  cleaned_up = Sidekiq::ProcessSet.cleanup
  puts "Cleaned up #{cleaned_up} processes"
end

def print_workers
  workers = Sidekiq::Workers.new
  puts "Workers: #{workers.size}"

  workers.each do |key, tid, json|
    printf "%15s %15s %20s\n", key, tid, json
  end
end

options = Parser.parse( ARGV )

Sidekiq.configure_client do |config|
  url = options["url"] ||"redis://#{options["host"]}:#{options["port"]}/#{options["db"]}"
  config.redis = { :url  => url, :size => 1 }
end

case ARGV.shift
  when "stats" then print_stats

  when "queue" 
    case ARGV.shift
      when "list" then print_queues
      else Parser.parse( %w[ --help ] )
    end

  when "retry" 
    case ARGV.shift
      when "list"  then print_retry
      when "show"  then show_retry_entries
      when "del"   then delete_retry_entries
      when "kill"  then kill_retry_entries
      when "now"   then retry_retry_entries
      when "clear" then clear_retry_entries
      else Parser.parse( %w[ --help ] )
    end

  when "dead"
    case ARGV.shift
      when "list"  then print_dead
      when "show"  then show_dead_entries
      when "del"   then delete_dead_entries
      when "now"   then dead_retry_entries
      when "clear" then clear_dead_entries
      else Parser.parse( %w[ --help ] )
    end

  when "processes"
    case ARGV.shift
      when "list"  then print_processes
      when "quiet" then quiet_processes
      when "kill"  then kill_processes
      when "clean" then clean_processes
      else Parser.parse( %w[ --help ] )
    end

  when "workers"
    case ARGV.shift
      when "list" then print_workers
      else Parser.parse( %w[ --help ] )
    end

  else Parser.parse( %w[ --help ] )
end
