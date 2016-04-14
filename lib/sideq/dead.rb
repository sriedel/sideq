module Sideq
  class Dead
    attr_reader :dead_set

    def initialize
      @dead_set = Sidekiq::DeadSet.new
    end

    def to_s
      dead_set.each_with_object( [ "Dead entries: #{dead_set.size}" ] ) do |job, memo|
        memo << sprintf( "%24s - %19s\n  %-22s - %-37s\n  e: %19s - f: %19s\n  retry (%2d) at %-19s Continue retries?: %s\n  %s\n", 
                         job.jid,
                         job.created_at.strftime( "%F %T" ),
                         job.display_class,
                         job["error_class"],
                         job.enqueued_at.strftime( "%F %T" ),
                         Time.at( job["failed_at"] ).strftime( "%F %T" ),
                         job["retry_count"],
                         job["retried_at"] ? Time.at( job["retried_at"] ).strftime( "%F %T" ) : "never",
                         job["retry"],
                         "#{job["error_class"]}: #{job["error_message"][0,77-job["error_class"].size]}" )
      end.join( "\n" )
    end

    def details( job_ids )
      dead_set.each_with_object( [] ) do |job, memo|
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
      puts "Dead Set: Deleted #{deleted} entries"
    end

    def retry_entries( job_ids )
      retried = 0
      each_job( job_ids ) do |job|
        job.retry
        puts "#{job_id}: retrying"
        retried += 1
      end

      puts "Dead Set: Retried #{retried} entries"
    end

    def clear
      puts "Dead Set: Deleted #{dead_set.clear} entries"
    end

    protected
    def each_job( job_ids )
      job_ids.each do |job_id|
        job = dead_set.find_job( job_id )
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
        "Worker class:  #{job.display_class}",
        "Arguments:     #{job.display_args}",
        "Failed at:     #{Time.at( job["failed_at"] ).strftime( "%F %T" )}",
        "Retried at:    #{job["retried_at"] ? Time.at( job["retried_at"] ).strftime( "%F %T" ) : "never"}",
        "Retries:       #{job["retry_count"]}",
        "Retry?:        #{job["retry"]}",
        "Error Class:   #{job["error_class"]}",
        "Error Message: #{job["error_message"]}"
      ].join( "\n" ) 
    end
  end
end
