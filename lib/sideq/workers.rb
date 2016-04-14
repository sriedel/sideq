module Sideq
  class Workers
    attr_reader :worker_set

    def initialize
      @worker_set = Sidekiq::Workers.new
    end

    def to_s
      ary = [ "Workers: #{worker_set.size}" ]

      worker_set.each do |key, tid, json|
        ary << sprintf( "%15s %15s %20s\n", key, tid, json )
      end

      ary.join( "\n" )
    end
  end
end
