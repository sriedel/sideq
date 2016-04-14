module Sideq
  class Retries
    attr_reader :retry_set

    def initialize
      @retry_set = Sidekiq::RetrySet.new
    end

    def to_s
      retry_set.each_with_object( [ "Retry entries: #{retry_set.size}" ] ) do |job, memo|
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
      retry_set.each_with_object( [] ) do |job, memo|
        next unless job_ids.include?( job.jid )
        memo << job_details( job )
      end.join( "\n\n" )
    end

    def delete_entries( job_ids )
      deleted = 0
      job_ids.each do |job_id|
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

    def kill_entries( job_ids )
      killed = 0
      job_ids.each do |job_id|
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

    def retry_entries( job_ids )
      retried = 0
      job_ids.each do |job_id|
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

    def clear
      puts "Retry Set: Deleted #{retry_set.clear} entries"
    end

    protected
    def job_details( job )
      [ "JobID:         #{job.jid}",
        "Created at:    #{job.created_at.strftime( "%F %T" )}",
        "Enqueued at:   #{job.enqueued_at.strftime( "%F %T")}",
        "Worker class:  #{job.display_class}",
        "Arguments:     #{job.display_args}",
        "Failed at:     #{Time.at( job.item["failed_at"] ).strftime( "%F %T" )}",
        "Retried at:    #{job["retried_at"] ? Time.at( job["retried_at"] ).strftime( "%F %T" ) : "never"}",
        "Retries:       #{job["retry_count"]}",
        "Retry?:        #{job["retry"]}",
        "Error Class:   #{job["error_class"]}",
        "Error Message: #{job["error_message"]}" ].join( "\n" )
    end
  end
end
