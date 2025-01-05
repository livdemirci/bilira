require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'base64'
require 'nokogiri'

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
      code = "4/1AanRRruUHIrLU_glSvLIxbjNBIZeXnThWSqV1T88EPce1KK9ZBgsWQROfj4"
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
    result = @gmail_service.list_user_messages('me', q: 'from:support@bilira.co')
    puts "\nSearching for emails from support@bilira.co..."
    puts "Found #{result.messages&.length || 0} messages"
    
    if result.messages && !result.messages.empty?
      message = @gmail_service.get_user_message('me', result.messages[0].id)
      puts "\n=== Bilira'dan Gelen Son Mesaj ==="
      puts "ID: #{message.id}"
      puts "Tarih: #{message.payload.headers.find { |h| h.name == 'Date' }&.value}"
      puts "Kimden: #{message.payload.headers.find { |h| h.name == 'From' }&.value}"
      puts "Konu: #{message.payload.headers.find { |h| h.name == 'Subject' }&.value}"
      
      otp_code = nil
      begin
        # Get the message body
        if message.payload.parts
          # Multipart message - find HTML part
          html_part = message.payload.parts.find { |part| part.mime_type == 'text/html' }
          if html_part && html_part.body.data
            raw_content = html_part.body.data
            puts "\nRaw HTML content:"
            puts raw_content
            
            # Try parsing as HTML first
            begin
              doc = Nokogiri::HTML(raw_content)
              # Look in span and p tags
              doc.css('span, p').each do |node|
                text = node.text.strip
                if text =~ /^\d{6}$/  # Exactly 6 digits
                  otp_code = text
                  puts "\nBulunan OTP Kodu (from HTML element): #{otp_code}"
                  return otp_code
                end
              end
            rescue => e
              puts "HTML parsing failed: #{e.message}"
            end

            # If not found in HTML elements, try plain text search
            raw_content.scan(/(\d{6})/).each do |match|
              potential_otp = match[0]
              if potential_otp.length == 6
                otp_code = potential_otp
                puts "\nBulunan OTP Kodu (from raw text): #{otp_code}"
                return otp_code
              end
            end
            
            # If still not found, try decoding
            begin
              content = Base64.decode64(raw_content)
              puts "\nSuccessfully decoded with decode64"
              
              # Try parsing decoded content as HTML
              begin
                doc = Nokogiri::HTML(content)
                doc.css('span, p').each do |node|
                  text = node.text.strip
                  if text =~ /^\d{6}$/
                    otp_code = text
                    puts "\nBulunan OTP Kodu (from decoded HTML): #{otp_code}"
                    return otp_code
                  end
                end
              rescue => e
                puts "Decoded HTML parsing failed: #{e.message}"
              end
              
              # If still not found, try plain text search in decoded content
              content.scan(/(\d{6})/).each do |match|
                potential_otp = match[0]
                if potential_otp.length == 6
                  otp_code = potential_otp
                  puts "\nBulunan OTP Kodu (from decoded content): #{otp_code}"
                  return otp_code
                end
              end
              
            rescue => e
              puts "decode64 failed: #{e.message}"
            end
          end
        elsif message.payload.body.data
          # Single part message
          raw_content = message.payload.body.data
          puts "\nRaw content:"
          puts raw_content
          
          # Try parsing as HTML first
          begin
            doc = Nokogiri::HTML(raw_content)
            doc.css('span, p').each do |node|
              text = node.text.strip
              if text =~ /^\d{6}$/
                otp_code = text
                puts "\nBulunan OTP Kodu (from HTML element): #{otp_code}"
                return otp_code
              end
            end
          rescue => e
            puts "HTML parsing failed: #{e.message}"
          end
          
          # If not found in HTML, try plain text search
          raw_content.scan(/(\d{6})/).each do |match|
            potential_otp = match[0]
            if potential_otp.length == 6
              otp_code = potential_otp
              puts "\nBulunan OTP Kodu (from raw content): #{otp_code}"
              return otp_code
            end
          end
        end
        
      rescue => e
        puts "Hata oluştu: #{e.message}"
        puts e.backtrace
      end
      
      if otp_code
        delete_message(message.id)
      end
      
      return otp_code
    end
    nil
  end

  def get_user_email
    result = @gmail_service.get_user_profile('me')
    puts "\nGmail Hesabı: #{result.email_address}"
    result.email_address
  end
end
