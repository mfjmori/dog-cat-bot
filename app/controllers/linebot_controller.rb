class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'flickraw'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def callback
    body = request.body.read
    # 署名の検証を行う
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    # 不正なアクセスの場合、bad requestを返す
    unless client.validate_signature(body, signature)
      head :bad_request
    end

    events = client.parse_events_from(body)

    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        # 送られてきたメッセージがtextだった場合
        when Line::Bot::Event::MessageType::Text
          # messageというハッシュを作る（この中に返信したい内容を入れる）
          main_image_url, thumbnail_image_url = get_main_and_thumbnail_image(event.message['text'])
          message = {
            type: 'image',
            originalContentUrl: main_image_url,
            previewImageUrl: thumbnail_image_url
          }
          # メッセージを返す
          client.reply_message(event['replyToken'], message)
        end
      end
    }

    head :ok
  end

  private
  def get_main_and_thumbnail_image(request_message)
    FlickRaw.api_key = ENV["FLICKR_API_KEY"]
    FlickRaw.shared_secret = ENV["FLICKR_SECRET_KEY"]

    dog = [
      '犬',
      'いぬ',
      'イヌ',
      'inu',
      'dog',
      'puppy',
      'わん',
      'ワン',
      'イッヌ',
      'いっぬ'
    ]

    cat = [
      '猫',
      'ネコ',
      'ねこ',
      'Neko',
      'neko',
      'NEKO',
      'ぬこ',
      'cat',
      'ヌコ',
      'にゃー',
      'ニャー'
    ]

    shiba = [
      '柴犬',
      'しば犬',
      'しばいぬ',
      '柴いぬ',
      'シバ犬',
      '柴いぬ',
      'シバイヌ',
      '柴イヌ',
      'しばけん',
      '柴けん',
      'シバけん',
      'シバケン',
      '柴',
      'しば',
      'シバ',
      'shiba',
      'siba',
      'shibaken',
      'shibainu'
    ]

    # 受けとったメッセージの内容で条件分岐
    if shiba.include?(request_message)
      word = "柴犬"
    elsif dog.include?(request_message)
      word = "dog"
    elsif cat.include?(request_message)
      word = "cat"
    else
      word = "animal"
    end

    # クリエイティブ・コモンズ・ライセンス
    license = "1,2,3,4,5,6"
    # 画像の配列を最大50件取得
    images = flickr.photos.search(text: word, sort: "relevance", license: license, per_page: 50)
    # 画像の件数を取得
    images_num = images.length
    # 画像をランダムに1件取得
    image_num = rand(images_num)
    image = images[image_num]
    # メイン用とサムネイル用の画像urlを取得
    original_image_url = FlickRaw.url image
    main_image_url = original_image_url.gsub(/.jpg/, "_b.jpg")
    thumbnail_image_url = original_image_url.gsub(/.jpg/, "_m.jpg")

    return main_image_url, thumbnail_image_url
  end
end
