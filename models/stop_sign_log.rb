class StopSignLog
  include MongoMapper::Document
  key :frame_count, Integer
  key :daylight, Boolean
  key :ran_sign, Boolean
  key :x_velocity, Float
  key :event_at, Time
  key :at_disallowed_time, Boolean
  key :number_stopped_frames, Integer
  key :centroid_data, Array
  key :box_data, Array
  key :stop_id, String
  key :observation_timestamp, Integer
  key :human_votes_car_present, Array
  key :human_votes_car_stop_violated, Array
  key :human_votes_car_wrong_way_violated, Array
  key :ml_row, Array
  key :imgur_url, String
  key :_random, Float
  key :gif_saved, Boolean
  before_save :set_random

  def self.get_random
    ssl = StopSignLog.order(:_random.desc).where(:_random.gte => rand, gif_saved: true).first
    while ssl.nil?
      ssl = StopSignLog.order(:_random.desc).where(:_random.gte => rand, gif_saved: true).first
    end
    ssl
  end

  def set_random
    self._random = rand
  end

  def self.import(import_file = "#{CONFIG["project_dir"]}stop_sign.log")
    File.read(import_file).split("\n").each do |row|
      row = JSON.parse(row)
      ssl = StopSignLog.first_or_create(stop_id: row["stop_id"])
      ssl.frame_count = row["frame_count"]
      ssl.daylight = row["daylight"]
      ssl.ran_sign = row["assessment"][0]
      ssl.x_velocity = row["assessment"][1]
      ssl.event_at = Time.parse(row["assessment"][2])
      ssl.at_disallowed_time = row["assessment"][3]
      ssl.number_stopped_frames = row["assessment"][4]
      ssl.centroid_data = row["drive_data"]
      ssl.box_data = row["drive_data_full"]
      ssl.observation_timestamp = row["time"]
      ssl.human_votes_car_present = []
      ssl.human_votes_car_stop_violated = []
      ssl.human_votes_car_wrong_way_violated = []
      ssl.save!
      x_dist = ssl.centroid_data.collect(&:first)
      x_diff_dist = x_dist.rolling_diff
      y_dist = ssl.centroid_data.collect(&:last)
      y_diff_dist = y_dist.rolling_diff
      areas = ssl.box_data.collect{|x| x[3]*x[4]}
      areas_dist = areas.rolling_diff
      widths = ssl.box_data.collect{|x| x[3]}
      widths_dist = widths.rolling_diff
      heights = ssl.box_data.collect{|x| x[4]}
      heights_dist = heights.rolling_diff
      ssl.ml_row = [
        ssl.at_disallowed_time == true ? 1 : 0,
        ssl.daylight == true ? 1 : 0,
        ssl.number_stopped_frames,
        ssl.frame_count,
        ssl.x_velocity,
        ssl.event_at.days_to_week_start,
        ssl.event_at.hour,
        x_dist.average,
        x_dist.min,
        x_dist.max,
        x_dist.median,
        x_dist.sample_variance,
        x_diff_dist.average,
        x_diff_dist.min,
        x_diff_dist.max,
        x_diff_dist.median,
        x_diff_dist.sample_variance,
        y_dist.average,
        y_dist.min,
        y_dist.max,
        y_dist.median,
        y_dist.sample_variance,
        y_diff_dist.average,
        y_diff_dist.min,
        y_diff_dist.max,
        y_diff_dist.median,
        y_diff_dist.sample_variance,
        areas.average,
        areas.min,
        areas.max,
        areas.median,
        areas.sample_variance,
        areas_dist.average,
        areas_dist.min,
        areas_dist.max,
        areas_dist.median,
        areas_dist.sample_variance,
        widths.average,
        widths.min,
        widths.max,
        widths.median,
        widths.sample_variance,
        widths_dist.average,
        widths_dist.min,
        widths_dist.max,
        widths_dist.median,
        widths_dist.sample_variance,
        heights.average,
        heights.min,
        heights.max,
        heights.median,
        heights.sample_variance,
        heights_dist.average,
        heights_dist.min,
        heights_dist.max,
        heights_dist.median,
        heights_dist.sample_variance
      ]
      ssl.save!
      ssl_filename = "#{ssl.observation_timestamp}_#{ssl.stop_id}.gif"
      gz = `convert -limit memory 250mb -limit map 500mb -delay 3x100 #{CONFIG["project_dir"]}cases/#{ssl_filename.gsub(".gif", ".avi")} #{CONFIG["project_dir"]}public/gif_cases/#{ssl_filename}`
      puts "Convert output:"
      puts gz
      ssl.imgur_url = `python push_to_imgur.py -g #{CONFIG["project_dir"]}public/gif_cases/#{ssl_filename}`
      if ssl.imgur_url.include?("http://i.imgur.com/")
        ssl.gif_saved = true
        `rm #{CONFIG["project_dir"]}public/gif_cases/#{ssl_filename}`
      else
        ssl.gif_saved = false
      end
      ssl.save!
    end
  end
  
  def get_url
    if self.imgur_url.nil? || self.imgur_url.empty?
      "/gif_cases/#{self.observation_timestamp}_#{self.stop_id}.gif"
    else
      self.imgur_url
    end
  end
end

#`ls videos`.split("\n").each do |video|
#  puts video
#  time = video.gsub(".avi", "").to_i
#  `python #{CONFIG["project_dir"]}analyze_video.py --video #{CONFIG["project_dir"]}videos/#{video} --time #{video.gsub(".avi", "")}`
#  op = ObservationPeriod.first_or_create(observation_timestamp: Time.at(time))
#  if `ls #{CONFIG["project_dir"]}`.split("\n").include?("stop_sign.log")
#    StopSignLog.import
#    op.processed = true
#    op.save!
#    `rm #{CONFIG["project_dir"]}stop_sign.log`
#  end
#end
#while true
#sleep(60*60+10)
#  [StopSignLog.where(imgur_url: nil).to_a, StopSignLog.where(imgur_url: "").to_a].flatten.each do |ssl|
#    if ssl.imgur_url.nil? || ssl.imgur_url.empty?
#       ssl_filename = "#{ssl.observation_timestamp}_#{ssl.stop_id}.gif"
#       `convert -limit memory 250mb -limit map 500mb -delay 3x100 #{CONFIG["project_dir"]}cases/#{ssl_filename.gsub(".gif", ".avi")} #{CONFIG["project_dir"]}public/gif_cases/#{ssl_filename}`
#      ssl_filename = "#{ssl.observation_timestamp}_#{ssl.stop_id}.gif"
#      img_path = `python push_to_imgur.py -g public/gif_cases/#{ssl_filename}`.strip
#      ssl.imgur_url = img_path
#      ssl.save!
#    end
#  end
#end