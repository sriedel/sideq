module Sideq
  class Queue
    attr_reader :queue, :name

    def self.overview
      retry_set = Sidekiq::RetrySet.new
      dead_set = Sidekiq::DeadSet.new

      ary = Sidekiq::Queue.all.each_with_object( [] ) do |queue, memo|
        memo << sprintf( "%-30s %5d (%8.2f s latency), %spaused", 
                        queue.name,
                        queue.size,
                        queue.latency,
                        queue.paused? ? '' : "not " )
      end
      ary << sprintf( "%-30s %5d", "retry", retry_set.size )
      ary << sprintf( "%-30s %5d", "dead", dead_set.size )
      ary.join( "\n" )
    end

    def initialize( name )
      @name = name
      @queue = Sidekiq::Queue.new( name )
    end

    def to_s
      queue.each_with_object( [ "Queue entries: #{queue.size}" ] ) do |job, memo|
        memo << sprintf( "%24s - %19s\n  %-77s\n  e: %19s - lat: %19s\n",
                          job.jid,
                          job.created_at.strftime( "%F %T" ),
                          job.display_class,
                          job.enqueued_at.strftime( "%F %T" ),
                          job.latency )
      end.join( "\n" )
    end

    def details( job_ids )
      queue.each_with_object( [] ) do |job, memo|
        next unless job_ids.include?( job.jid )
        memo << job_details( job )
      end.join( "\n\n" )
    end

    def delete_entries( job_ids )
      deleted = 0
      each_job( job_ids ) do |job|
        job.delete
        puts "#{job_id}: deleted"
        deleted += 1
      end
    end

    def clear
      puts "Queue #{name}: Deleted #{queue.clear.first} entries"
    end

    protected
    def each_job( job_ids )
      job_ids.each do |job_id|
        job = queue.find_job( job_id )
        if job
          begin
            yield( job )
          rescue
            puts "#{job_id}: failed - #{$!.message}"
          end
        else
          puts "#{job_id}: not found"
        end
      end
    end

    def job_details( job )
      [ "JobID:         #{job.jid}",
        "Created at:    #{job.created_at.strftime( "%F %T" )}",
        "Enqueued at:   #{job.enqueued_at.strftime( "%F %T")}",
        "Latency:       #{job.latency}",
        "Worker class:  #{job.display_class}",
        "Arguments:     #{job.display_args}" ].join( "\n" )
    end
  end
end
