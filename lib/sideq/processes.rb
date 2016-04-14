module Sideq
  class Processes
    attr_reader :process_set

    def initialize
      @process_set = Sidekiq::ProcessSet.new
    end

    def to_s
      process_set.each_with_object( ["Processes: #{process_set.size}"] ) do |process, memo|
        memo << process.inspect
      end.join( "\n" )
    end

    def quiet
      size = process_set.size
      process_set.each do |process|
        process.quiet!
      end
      puts "Quieted #{size} processes"
    end

    def kill
      size = process_set.size
      process_set.each do |process|
        process.kill!
      end
      puts "Killed #{size} processes"
    end

    def clean
      cleaned_up = Sidekiq::ProcessSet.cleanup
      puts "Cleaned up #{cleaned_up} processes"
    end
  end
end
