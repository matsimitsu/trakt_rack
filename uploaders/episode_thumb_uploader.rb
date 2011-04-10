class EpisodeThumbUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  storage :file

  def store_dir
    "public/uploads/#{model.show_tvdb_id}"
  end

  def filename
    if original_filename
      extension = File.extname(file.file)
      "#{mounted_as}-#{model.show_tvdb_id}-#{model.season_number}-#{model.episode_number}#{extension}"
    end
  end

end
