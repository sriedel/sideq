module Sideq
  class Queues
    attr_reader :retry_set, :dead_set

    def initialize
      @retry_set = Sidekiq::RetrySet.new
      @dead_set = Sidekiq::DeadSet.new
    end

    def to_s
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

    def list( queue_name )
      queue = Sidekiq::Queue.new( queue_name )
      queue.each_with_object( [ "Queue entries: #{queue.size}" ] ) do |job, memo|
        memo << sprintf( "%24s - %19s\n  %-77s\n  e: %19s - lat: %19s\n",
                          job.jid,
                          job.created_at.strftime( "%F %T" ),
                          job.display_class,
                          job.enqueued_at.strftime( "%F %T" ),
                          job.latency )
      end.join( "\n" )
    end

    def delete_entries( queue_name, job_ids )
      deleted = 0
      queue = Sidekiq::Queue.new( queue_name )
      job_ids.each do |job_id|
        # TODO: Inefficient in the free(beer) sidekiq version; 
        #       find something more efficient here (sr 2016-04-06)
        job = queue.find_job( job_id )
        if job
          job.delete
          puts "#{job_id}: deleted"
          deleted += 1
        else
          puts "#{job_id}: not found"
        end
      end
      puts "Queue #{queue_name}: Deleted #{deleted} entries"
    end

    def clear( queue_name )
      queue = Sidekiq::Queue.new( queue_name )
      puts "Retry Set: Deleted #{queue.clear.first} entries"
    end
  end
end
