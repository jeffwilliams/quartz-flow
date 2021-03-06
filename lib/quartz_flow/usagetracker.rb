require 'quartz_flow/model'
require 'date'

class Bucket
  def initialize(label = nil, criteriaData = nil, value = nil)
    @label = label
    @criteriaData = criteriaData
    @value = value
    @absoluteUsageAtStartOfBucket = nil
  end
  attr_accessor :label
  # Data used by BucketChangeCriteria to determine when we need a new bucket. 
  attr_accessor :criteriaData
  # At the time this bucket was created, the value of the absolute usage for all time
  attr_accessor :absoluteUsageAtStartOfBucket
  # The amount of usage for this bucket alone
  attr_accessor :value

  def toHash
    {"label" => @label, "absoluteUsageAtStartOfBucket" => @absoluteUsageAtStartOfBucket, "criteriaData" => @criteriaData, "value" => @value}
  end

  def fromHash(hash)
    @label = hash["label"]
    @absoluteUsageAtStartOfBucket = hash["absoluteUsageAtStartOfBucket"]
    @criteriaData = hash["criteriaData"]
    @value = hash["value"]
  end

  def fromModel(bucket)
    @label = bucket.label
    @absoluteUsageAtStartOfBucket = bucket.absoluteUsage
    # DataMapper's dm-do-adapter 1.2.0 has a bug when using Time fields in ruby 2, so we need to use DateTime when storing.
    @criteriaData = bucket.criteriaData.to_time
    @value = bucket.value
  end

  def toModel
    model = UsageBucket.new
    model.attributes = { 
      :label => @label,
      :absoluteUsage => @absoluteUsageAtStartOfBucket,
      # DataMapper's dm-do-adapter 1.2.0 has a bug when using Time fields in ruby 2, so we need to use DateTime when storing.
      :criteriaData => @criteriaData.to_datetime,
      :value => @value
    }
    model
  end
end

class BucketChangeCriteria
  # Is it now time for a new bucket?
  def newBucket?(currentBucket)
    false
  end

  # Make a new bucket and return it.
  def newBucket
    innerNewBucket 
  end

  def innerNewBucket
    raise "Implement me!"
  end
end

class PeriodicBuckets
  def initialize(criteria, maxBuckets = nil)
    setBucketChangeCriteria(criteria)
    @buckets = []
    @maxBuckets = maxBuckets
    @maxBuckets = 1 if @maxBuckets && @maxBuckets < 1
  end

  # Set the criteria that determines when the current bucket is full
  # and we should make a new empty bucket the current bucket, and that is used
  # to set the label for the new bucket.
  def setBucketChangeCriteria(criteria)
    @bucketChangeCriteria = criteria
  end

  def update(absoluteUsage = nil)
    if @buckets.size == 0
      prev = nil
      @buckets.push @bucketChangeCriteria.newBucket
      setAbsoluteUsage(prev, @buckets.last, absoluteUsage) if absoluteUsage
    else
      prev = @buckets.last
      # Time for a new bucket?
      if @bucketChangeCriteria.newBucket?(@buckets.last)
        @buckets.push @bucketChangeCriteria.newBucket
        setAbsoluteUsage(prev, @buckets.last, absoluteUsage) if absoluteUsage
      end
      @buckets.shift if @maxBuckets && @buckets.size > @maxBuckets
    end

    setValue(@buckets.last, absoluteUsage) if absoluteUsage
  end

  def current(absoluteUsage = nil)
    @buckets.last
  end
  
  def all
    @buckets
  end

  def toHash
    array = []
    @buckets.each do |b|
      array.push b.toHash 
    end
    { "buckets" => array }
  end

  def fromHash(hash)
    @buckets = []
    hash["buckets"].each do |b|
      bucket = Bucket.new(nil, nil, nil)
      bucket.fromHash b
      @buckets.push bucket
    end
  end

  def fromModel(type)
    @buckets = []
    buckets = UsageBucket.all(:type => type, :order => [:index.asc])
    buckets.each do |model|
      bucket = Bucket.new(nil, nil, nil)
      bucket.fromModel model
      @buckets.push bucket
    end
  end
  
  def toModel(type)
    UsageBucket.all(:type => type).destroy!
    index = 0
    @buckets.each do |b|
      model = b.toModel
      model.type = type
      model.index = index
      index += 1
      model.save
    end
  end

  private
  def setAbsoluteUsage(previousBucket, newBucket, absoluteUsage)
    if previousBucket
      newBucket.absoluteUsageAtStartOfBucket = previousBucket.absoluteUsageAtStartOfBucket + previousBucket.value
    else
      newBucket.absoluteUsageAtStartOfBucket = absoluteUsage
    end
  end
  def setValue(newBucket, absoluteUsage)
    newBucket.value = 
      absoluteUsage - 
      newBucket.absoluteUsageAtStartOfBucket
  end
end

class DailyBucketChangeCriteria < BucketChangeCriteria
  def newBucket?(currentBucket)
    now = Time.new
    currentBucket.criteriaData.day != now.day
  end

  def newBucket
    now = Time.new
    Bucket.new(now.strftime("%b %e"), now, 0)
  end

  def criteriaData
    Time.new
  end
end

class MonthlyBucketChangeCriteria < BucketChangeCriteria
  def initialize(resetDay)
    @resetDay = resetDay
  end
  
  def newBucket?(currentBucket)
    Time.new > currentBucket.criteriaData
  end

  def newBucket
    now = Time.new
    # Set the bucket's criteriaData to the date after which we need a new bucket.
    data = criteriaData
    Bucket.new(now.strftime("%b %Y"), data, 0)
  end

  def criteriaData
    now = Time.new
    nextMonth = now.mon % 12 + 1
    year = now.year
    year += 1 if nextMonth == 1
    Time.local(year, nextMonth, @resetDay)
  end
end


# For testing
class MinuteBucketChangeCriteria < BucketChangeCriteria
  def newBucket?(currentBucket)
    now = Time.new
    currentBucket.criteriaData.min != now.min
  end

  def newBucket
    now = Time.new
    Bucket.new(now.strftime("%H:%M"), now, 0)
  end
end

class UsageTracker
  def initialize(monthlyResetDay)
    @buckets = {}
    @buckets[:daily] = PeriodicBuckets.new(DailyBucketChangeCriteria.new,31)
    #@buckets[:minute] = PeriodicBuckets.new(MinuteBucketChangeCriteria.new,3)
    @buckets[:monthly] = PeriodicBuckets.new(MonthlyBucketChangeCriteria.new(monthlyResetDay),2)
    @usageForAllTimeAdjustment = 0
    loadBucketsFromDatastore
  end

  # Update the UsageTracker with more usage. The value passed
  # should be the usage since the torrentflow session was created.
  # If a datastore is not used, then this means stopping and starting the session
  # will cause UsageTracking to only track usage for the session. However
  # if Mongo is used then the usage can be saved and persisted between sessions
  # and internally the value passed here is added to the value loaded from Mongo.
  def update(usageForAllTime)
    usageForAllTime += @usageForAllTimeAdjustment
    @buckets.each do |k,buckets|
      buckets.update usageForAllTime
    end
    saveBucketsToDatastore
  end

  # This method returns the usage in the current bucket for the specified
  # period type (:daily or :monthly). The usage is accurate as of the last 
  # time update() was called.
  # The returned value is a single Bucket object.
  def currentUsage(periodType)
    getBuckets(periodType).current
  end

  # Returns the usage as of the last time update() was called.
  # This method returns all the tracked usage for the specified
  # period type (:daily or :monthly). The usage is accurate as of the last 
  # time update() was called.
  # The returned value is an array of Bucket objects.
  def allUsage(periodType)
    getBuckets(periodType).all
  end

  private
  def getBuckets(type)
    buckets = @buckets[type]
    raise "Unsupported periodType #{periodType.to_s}" if ! buckets
    buckets
  end

  def saveBucketsToDatastore
    @buckets[:daily].toModel(:daily)
    @buckets[:monthly].toModel(:monthly)
  end

  def loadBucketsFromDatastore
    @buckets[:daily].fromModel(:daily)
    @buckets[:monthly].fromModel(:monthly)

    # If we are loading from datastore it means that the absolute usage returned from the current torrent session will not
    # contain the usage that we previously tracked, so we must add the old tracked value to what the torrent
    # session reports.
    if @buckets[:daily].current
      @usageForAllTimeAdjustment = @buckets[:daily].current.absoluteUsageAtStartOfBucket + @buckets[:daily].current.value
    end
  end
end

=begin
  # Testing
  tracker = UsageTracker.new
  
  abs = 200
  while true
    tracker.update(abs)
    
    puts
    puts "Usage for all time: #{abs}"
    puts "Buckets:"
    tracker.allUsage(:minute).each do |b|
      puts "  #{b.label}: #{b.value}"   
    end
    abs += 10
    sleep 10
  end  

=end
