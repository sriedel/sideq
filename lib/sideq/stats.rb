module Sideq
  class Stats
    attr_reader :stats, :retry_set, :dead_set

    def initialize
      @stats = Sidekiq::Stats.new
      @retry_set = Sidekiq::RetrySet.new
      @dead_set = Sidekiq::DeadSet.new
    end

    def to_s
      stat_ary = [ "Processed: #{stats.processed}",
                   "Failed: #{stats.failed}",
                   "Scheduled size: #{stats.scheduled_size}",
                   "Retry size: #{stats.retry_size}",
                   "Dead size: #{stats.dead_size}",
                   "Enqueued: #{stats.enqueued}",
                   "Processes: #{stats.processes_size}",
                   "Workers: #{stats.workers_size}",
                   "Default queue latency: #{stats.default_queue_latency}",

                   "Queues: dead:  #{dead_set.size}",
                   "        retry: #{retry_set.size}" ]
      stats.queues.each do |(queue_name, queue_size)|
        stat_ary << "        #{queue_name}: #{queue_size}"
      end

      stat_ary.join( "\n" )
    end
  end
end
