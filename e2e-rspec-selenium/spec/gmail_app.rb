require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'

class GmailApp
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  APPLICATION_NAME = 'Gmail API Ruby Quickstart'
  CREDENTIALS_PATH = '/home/livde/rubytest/bilira/credentials.json' # Google Cloud Console'dan indirdiğiniz JSON dosyasının yolu
  TOKEN_PATH = '/home/livde/rubytest/bilira/token.yaml'
  SCOPE = Google::Apis::GmailV1::AUTH_SCOPE

  def initialize
    # Gmail API için kimlik doğrulaması
    @client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
    @token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
    @authorizer = Google::Auth::UserAuthorizer.new(@client_id, SCOPE, @token_store)
    @user_id = 'default'
    credentials = authorize(credentials)

    # Gmail API servisi oluştur
    @gmail_service = Google::Apis::GmailV1::GmailService.new
    @gmail_service.authorization = credentials
  end

  # Yetkilendirme işlemi
  def authorize(credentials)
    credentials = @authorizer.get_credentials(@user_id)
    if credentials.nil?
      url = @authorizer.get_authorization_url(base_url: OOB_URI)
      puts "Aşağıdaki URL'yi ziyaret ederek yetkilendirme yapın:\n#{url}"
      print 'Yetkilendirme kodunu girin: '
      code = "4/1AanRRrv0xOavnFKoHcv1_HfIC0k8BmrWg8rWjBUoE4Y9Hncdgy59fOUJgtA"
      credentials = @authorizer.get_and_store_credentials_from_code(user_id: @user_id, code: code, base_url: OOB_URI)
    end
    credentials
  end

  # Gelen kutusundaki mesajları listele
  def list_messages
    result = @gmail_service.list_user_messages('me', max_results: 10)
    if result.messages.nil? || result.messages.empty?
      puts "Hiç mesaj bulunamadı."
    else
      result.messages.each do |message|
        puts "Mesaj ID: #{message.id}"
      end
    end
  end

  # Tüm mesajları sil
  def delete_all_messages
    result = @gmail_service.list_user_messages('me', max_results: 10)
    if result.messages.nil? || result.messages.empty?
      puts "Hiç mesaj bulunamadı."
    else
      result.messages.each do |message|
        message_id = message.id
        delete_message(message_id)
      end
    end
  end

  # Mesaj silme
  def delete_message(message_id)
    @gmail_service.delete_user_message('me', message_id)
    puts "Mesaj ID #{message_id} silindi."
  end
  
  def read_last_message
    result = @gmail_service.list_user_messages('me', max_results: 1)  # Sadece son mesajı alıyoruz
    if result.messages.nil? || result.messages.empty?
      puts "Hiç mesaj bulunamadı."
    else
      # Son mesajı al
      message_id = result.messages.first.id
      message = @gmail_service.get_user_message('me', message_id)
      
      # Mesaj içeriğini yazdır
      puts "Mesaj Başlığı: #{message.payload.headers.find { |header| header.name == 'Subject' }&.value}"
      puts "Mesaj Gönderen: #{message.payload.headers.find { |header| header.name == 'From' }&.value}"
      puts "Mesaj İçeriği: #{message.snippet}"
    end
  end
end
