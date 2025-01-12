require 'dotenv/load'
require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'base64'
require 'nokogiri'

class GmailApp
  class TokenExpiredError < StandardError; end

  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  APPLICATION_NAME = 'Gmail API Ruby Quickstart'
  
  # Proje kök dizinini bul
  ROOT_DIR = File.expand_path('../..', __dir__)
  
  # Environment variables ile dosya yolları ve diğer ayarlar
  CREDENTIALS_PATH = File.join(ROOT_DIR, ENV.fetch('CREDENTIALS_PATH'))
  TOKEN_PATH = File.join(ROOT_DIR, ENV.fetch('TOKEN_PATH'))
  SCOPE = Google::Apis::GmailV1::AUTH_SCOPE
  SUPPORT_EMAIL = ENV.fetch('SUPPORT_EMAIL')
  MAX_RETRIES = 3

  def initialize
    setup_service
  end

  # Public metodlar
  def list_messages
    execute_with_token_refresh do
      result = @service.list_user_messages('me', max_results: 10)
      if result.messages.nil? || result.messages.empty?
        puts "Hiç mesaj bulunamadı."
      else
        result.messages.each do |message|
          puts "Mesaj ID: #{message.id}"
        end
      end
    end
  end

  def delete_all_messages
    result = @service.list_user_messages('me')
    if result.messages.nil? || result.messages.empty?
      puts "Hiç mesaj bulunamadı."
      return
    end

    result.messages.each do |message|
      @service.delete_user_message('me', message.id)
      puts "Mesaj ID #{message.id} silindi."
    end
    puts "Tüm mesajlar başarıyla silindi."
  end

  def delete_message(message_id)
    execute_with_token_refresh do
      @service.delete_user_message('me', message_id)
      puts "Mesaj ID #{message_id} silindi."
    end
  end
  
  def read_last_message
    execute_with_token_refresh do
      # Bilira'dan gelen son mesajı al
      result = @service.list_user_messages('me', q: "from:#{GmailApp::SUPPORT_EMAIL}")
      return nil if result.messages.nil? || result.messages.empty?

      # Son mesajın detaylarını al
      message = @service.get_user_message('me', result.messages[0].id)
      
      # HTML içeriğini al
      html_content = if message.payload.parts
        part = message.payload.parts.find { |p| p.mime_type == 'text/html' }
        part&.body&.data
      else
        message.payload.body.data
      end
      
      return nil unless html_content

      # HTML içeriğinden OTP kodunu bul
      doc = Nokogiri::HTML(html_content)
      otp_code = doc.text.match(/(\d{6})/)&.[](1)
      
      # Mesajı sil ve OTP kodunu döndür
      delete_message(message.id) if otp_code
      otp_code
    end
  end

  def get_user_email
    execute_with_token_refresh do
      result = @service.get_user_profile('me')
      puts "\nGmail Hesabı: #{result.email_address}"
      result.email_address
    end
  end

  private

  def setup_service
    @service = Google::Apis::GmailV1::GmailService.new
    @service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize
  end

  def authorize
    client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
    @authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    @user_id = 'default'

    credentials = @authorizer.get_credentials(@user_id)
    if credentials.nil?
      url = @authorizer.get_authorization_url(base_url: OOB_URI)
      puts "Open the following URL in your browser and authorize the application:"
      puts url
      code = get_authorization_code
      credentials = @authorizer.get_and_store_credentials_from_code(
        user_id: @user_id, code: code, base_url: OOB_URI
      )
    end

    credentials
  end

  def refresh_token_if_expired
    return unless @service.authorization.expired?

    begin
      @service.authorization.refresh!
    rescue Google::Auth::TokenRefreshError
      # Token yenilenemezse yeni bir token al
      setup_service
    end
  end

  # API çağrılarını token kontrolü ile sarmalayan yardımcı metod
  def execute_with_token_refresh
    retries = 0
    begin
      refresh_token_if_expired
      yield
    rescue Google::Apis::AuthorizationError, TokenExpiredError => e
      retries += 1
      if retries <= MAX_RETRIES
        setup_service
        retry
      else
        raise e
      end
    end
  end

  def get_authorization_code
    ENV.fetch('GMAIL_AUTH_CODE') { raise 'GMAIL_AUTH_CODE environment variable is not set' }
  end
end
