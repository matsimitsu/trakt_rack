class BannerUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  storage :file

  def root
    Sinatra::Application.root
  end

  def store_dir
    "public/uploads/#{model.tvdb_id}"
  end

  def filename
    if original_filename
      extension = File.extname(file.file)
      "#{mounted_as}-#{model.tvdb_id}#{extension}"
    end
  end

end
