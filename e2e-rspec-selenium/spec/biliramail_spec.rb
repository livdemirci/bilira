load File.dirname(__FILE__) + '/../test_helper.rb'

require 'pry'
require 'google/apis/gmail_v1'
require 'googleauth'
require 'fileutils'
require 'yaml'
require_relative 'gmail_app'
require_relative 'gmail_api_authenticator'

describe "Bilira" do
  include TestHelper

  before(:all) do
    @driver = $driver = Selenium::WebDriver.for(browser_type, browser_options)
    driver.manage().window().resize_to(1920, 1080)
    # driver.manage().window().move_to(30, 78)
    driver.get("https://www.bilira.co/")
  end

  before(:each) do
    sleep 1 # for some webdriver verson, it might not wait page loaded
  end

  after(:all) do
    # driver.quit unless debugging?
  end

  it "Bilira" do
    app = GmailApp.new
    app.delete_all_messages

    bilira_page = BiliraPage.new(driver)

    bilira_page.accept_cookie

    element = driver.find_element(:xpath, '//a[@href="https://kripto.bilira.co/login?utm_source=website&utm_medium=header&utm_campaign=login&utm_content=tr"]')

    # Actions sınıfını başlatın
    # driver.action.context_click(element).perform
    url = element.attribute('href')
    driver.execute_script("window.open(arguments[0], '_blank');", url)

    handles = driver.window_handles

    # İkinci sekmeye geçiş yap (ilk sekme 0 indeksli olduğu için 1. sekmeye geçiş yapıyoruz)
    driver.switch_to.window(handles[1])
    sleep 3

    mail = driver.find_element(:xpath, '//input[@name="email"]')
    mail.send_keys("qatester1532@gmail.com")

    password = driver.find_element(:xpath, '//input[@name="password"]')
    password.send_keys("3ZE9tj7miEJR@Qg")
    sleep 3
    gonder_button = driver.find_element(:xpath, "//*[@class='button g-recaptcha']")
    gonder_button.click

    sleep 3
    # otp kodu girilecek
    otp_gir = driver.find_element(:xpath, "//input[@name='code']")

    # Mail gelene kadar en fazla 30 saniye bekle, her 5 saniyede bir kontrol et
    otp_code = nil
    max_attempts = 6 # 6 deneme x 5 saniye = 30 saniye
    attempts = 0

    while otp_code.nil? && attempts < max_attempts
      puts "Mail kontrol ediliyor... (#{attempts + 1}. deneme)"
      sleep 5
      otp_code = app.read_last_message
      attempts += 1
    end

    expect(otp_code).not_to be_nil
    puts "OTP kodu bulundu: #{otp_code}"

    # Son mesajın içeriğini göster
    puts "\nSon mesajın detayları:"
    app.list_messages

    otp_gir.send_keys(otp_code)
    sleep 5

    gonder_button = driver.find_element(:xpath, '//input[@class="button"]')
    gonder_button.click
    sleep 8

    telefon_ekle_button = driver.find_element(:xpath, '//*[@class="link-button"]')
    telefon_ekle_button.click

    telefon_ekle_gec = driver.find_element(:xpath, '//input[@class="button" and @type="submit"]')
    telefon_ekle_gec.click

    sleep 8

    coin_arama_butonu = nil
    try_for(5, 0.1) do
      coin_arama_butonu = driver.find_element(:xpath, '//*[@aria-keyshortcuts="Meta+K Control+K"]')
    end
    coin_arama_butonu.click

    sleep 3

    coin_ara = driver.find_element(:xpath, '//*[@class="input-search"]')
    coin_ara.send_keys("USDT")

    sleep 3

    coin_sec = driver.find_element(:xpath, '//*[@data-testid="list-item"]//*[@src="https://cdn.bilira.co/symbol/svg/USDT.svg"]')
    coin_sec.click

    sleep 2

    islem_cifti_sec_swap = driver.find_element(:xpath, '//*[@class="tab-card-panel"]//*[@src="https://cdn.bilira.co/symbol/svg/USDT.svg"]')
    islem_cifti_sec_swap.click

    sleep 2

    usdt_swap_sec = driver.find_element(:xpath,
                                        '//*[@class="tab-header-item tab-boxed tab-boxed-sm"][3]')
    usdt_swap_sec.click

    sleep 2

    varlık_ara_click = driver.find_element(:xpath, '//*[@class="input-search"]')
    varlık_ara_click.send_keys("BTC")

    sleep 2

    islem_cifti_secimi = driver.find_element(:xpath, '//*[@class="table-row clickable"]')
    islem_cifti_secimi.click

    sleep 2

    btc_yazisi = driver.find_element(:xpath, '//*[@class="meta-description"]').text
    expect(btc_yazisi).to eq('Bitcoin')

    usdt_yazisi = driver.find_element(:xpath,
                                      '//section[@data-testid="motion-section"]//span[contains(@class, "tw-break-none")]').text
    expect(usdt_yazisi).to eq('USDT')

    rakam = 100
    rakam_gir = driver.find_element(:xpath, '//*[@data-testid="trade-input-inner"]')
    rakam_gir.send_keys(rakam)
    sleep 1

    # 'value' attribute'undan alınan değeri kontrol et
    usdt_rakami = driver.find_element(:xpath, '//*[@data-testid="trade-input-inner"]').attribute('value')
    expect(usdt_rakami.to_s).to eq(rakam.to_s)

    # BTC/USDT oranını al ve sayıya çevir
    btc_usdt_text = driver.find_element(:xpath,
                                        '//*[@data-testid="typography-text" and contains(text(), "1 BTC")]').text
    btc_usdt_value = btc_usdt_text.match(/1 BTC = ([\d.,]+)/)[1].gsub('.', '').gsub(',', '.').to_f

    # Bölme işlemi
    yaklasik_deger = rakam / btc_usdt_value

    # Sonucu değişkene ata (daha fazla hassasiyet için yuvarlama)
    formatted_yaklasik_deger = yaklasik_deger.round(10) # Daha fazla hassasiyet için 10 ondalıklı

    # UI'daki yaklaşık değeri al
    yaklasik_deger_ui = driver.find_element(:xpath,
                                            '//div[@data-testid="block" and @class="flex tw-flex-col gap-sm tw-items-center"]/p[@data-testid="typography-text" and contains(@class, "tw-text-xs")]').text

    # UI'dan alınan metni sayıya dönüştür
    yaklasik_deger_ui = yaklasik_deger_ui.match(/([\d,\.]+)/)[1]
    yaklasik_deger_ui = yaklasik_deger_ui.gsub(',', '.').to_f

    # UI'dan alınan değeri ve hesaplanan değeri karşılaştır
    puts "UI'dan alınan değer: #{yaklasik_deger_ui}"
    puts "Hesaplanan değer: #{formatted_yaklasik_deger}"

    # Toleranslı karşılaştırma: belirli bir hassasiyetle değerleri karşılaştır
    tolerans = 0.0000001 # Hesaplama hassasiyeti için tolerans
    expect(yaklasik_deger_ui).to be_within(tolerans).of(formatted_yaklasik_deger)
  end
end
