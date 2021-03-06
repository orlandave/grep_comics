class DBSaver
  IGNORED_PUBLISHERS = ['DYNAMIC FORCES'].freeze

  def initialize(weekly_list_id)
    @weekly_list_id = weekly_list_id
    @logger = Logger.new "#{Rails.root}/log/db_saver.log"
  end

  #TODO think about what to do with TBD. maybe add another column which flags them for retry later?
  def persist_to_db(comic_hash)
    log "----- Trying to persist comic #{comic_hash.inspect} -----"
    save_new_comic comic_hash if valid_comic? comic_hash
  end

  def find_and_update_comic(comic_hash)
    comic = Comic.find_by diamond_code: comic_hash[:diamond_id]
    comic_params = build_comic_params comic_hash

    comic.assign_attributes comic_params
    if comic.changed?
      comic.save
      log "Updated comic #{comic_hash[:diamond_code]} #{comic_hash[:title]}"
    end
    comic
  end

  private

  def valid_comic?(comic_hash)
    if IGNORED_PUBLISHERS.include? comic_hash[:publisher]
      log "Comic is published by #{comic_hash[:publisher]}, which we ignore"
      return false
    end
    if Comic.find_by diamond_code: comic_hash[:diamond_id]
      log "Comic with diamond_code #{comic_hash[:diamond_id]} already exists"
      return false
    end
    true
  end

  def log(message, msg_type = :info)
    @logger.send(msg_type, message) unless Rails.env == 'test'
  end

  def save_new_comic(comic_hash)
    comic_params = build_comic_params comic_hash
    created_comic = Comic.create comic_params
    log "Persisted comic #{comic_hash[:diamond_code]} #{comic_hash[:title]}"
    created_comic
  end

  def build_comic_params(comic_hash)
    comic_params = map_params_to_model(comic_hash)
    publisher = build_publisher comic_hash
    creators = build_creators comic_hash[:creators]
    cover_params = cover_image_params comic_hash
    comic_params.merge!(publisher: publisher, weekly_list_id: @weekly_list_id)
                .merge!(creators)
                .merge!(cover_params)
  end

  def cover_artists_already_associated(comic, cover_artists)
    comic.cover_artists.map(&:name).include? cover_artists
  end

  def fetch_or_persist_creator(name)
    if creator = Creator.find_by(name: name)
      log "Creator #{name} is already in the db. Fetching..."
      creator
    else
      log "Persisted new creator #{name}"
      Creator.create name: name
    end
  end

  def cover_image_params(comic_hash)
    if comic_hash[:cover_available]
      { remote_cover_thumbnail_url: comic_hash[:cover_image_url], no_cover_available: false }
    else
      { no_cover_available: true }
    end
  end

  def build_creators(creators_hash)
    creators = {}

    creators_hash.each do |creator_type, arr_of_creators|
      creators[creator_type] = arr_of_creators.map do |creator_name|
        fetch_or_persist_creator(creator_name)
      end
    end
    creators
  end

  def build_publisher(comic_hash)
    if publisher = Publisher.find_by(name: comic_hash[:publisher])
      publisher
    else
      Publisher.create name: comic_hash[:publisher]
    end
  end

  def map_params_to_model(comic_hash)
    { diamond_code: comic_hash[:diamond_id],
      title: comic_hash[:title],
      issue_number: comic_hash[:issue_number],
      preview: comic_hash[:preview],
      suggested_price: BigDecimal.new(comic_hash[:suggested_price].gsub /\$/, ''),
      item_type: comic_hash[:type],
      shipping_date: comic_hash[:shipping_date],
      cover_image: comic_hash[:cover_image_url],
      is_variant: comic_hash[:additional_info][:variant_cover],
      reprint_number: comic_hash[:additional_info][:reprint_number]
    }
  end
end
