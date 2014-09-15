require 'analytics_channel'

Configuration.segmentio = Segment::Analytics.new({
  write_key: Configuration.segmentio_write_key,
  on_error: Proc.new { |status, msg| puts msg }
})

Rumor.register :analytics, AnalyticsChannel.new(Configuration.segmentio)
