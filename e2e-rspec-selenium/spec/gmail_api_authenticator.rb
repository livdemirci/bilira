require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'

class GmailApiAuthenticator
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  APPLICATION_NAME = 'Gmail API Ruby Quickstart'
  CREDENTIALS_PATH = '/home/livde/rubytest/bilira/credentials.json' # Google Cloud Console'dan indirdiğiniz JSON dosyasının yolu
  TOKEN_PATH = '/home/livde/rubytest/bilira/token.yaml'
  SCOPE = Google::Apis::GmailV1::AUTH_GMAIL_READONLY

  def initialize
    @client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
    @token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
    @authorizer = Google::Auth::UserAuthorizer.new(@client_id, SCOPE, @token_store)
    @user_id = 'me'
  end

  def authorize
    credentials = @authorizer.get_credentials(@user_id)
    if credentials.nil?
      url = @authorizer.get_authorization_url(base_url: OOB_URI)
      puts "Aşağıdaki URL'yi ziyaret ederek yetkilendirme yapın:\n#{url}"
      print 'Yetkilendirme kodunu girin: '
      code = "4/1AanRRru-I5dnNlJURdB58fFlOAEb4gxfFrwUb5LafCl70U9j_AInVkWyhK4"
      credentials = @authorizer.get_and_store_credentials_from_code(user_id: @user_id, code: code, base_url: OOB_URI)
    end
    credentials
  end
end
