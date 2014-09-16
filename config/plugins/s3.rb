CarrierWave.configure do |config|
  config.fog_credentials = {
    :provider               => 'AWS',
    :aws_access_key_id      => Configuration.s3_key_id,
    :aws_secret_access_key  => Configuration.s3_secret_key,
    :region                 => Configuration.s3_region,
  }

  config.fog_directory = Configuration.s3_bucket
  config.fog_public    = false
end
