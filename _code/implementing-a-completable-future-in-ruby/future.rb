require 'thread'

class ThreadPool
  def initialize(size)
    @size = size
    @queue = Queue.new
    @pool = (1..size).map { Thread.new(&pop_job_loop) }
  end
  attr_reader :size, :queue, :pool
  private :size, :queue, :pool

  def schedule(*args, &blk)
    queue << [blk, args]
  end

  def shutdown
    size.times { schedule { throw :kill } }
    pool.map(&:join)
  end

  private

  def pop_job_loop
    -> { catch(:kill) { loop { safely { run_job } } } }
  end

  def safely
    yield
  rescue => e
    e
  end

  def run_job
    job, args = queue.pop
    job.call(*args)
  end
end

class Future

end

# Testing

require 'rspec'

RSpec.describe do
end
