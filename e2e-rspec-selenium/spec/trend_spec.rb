load File.dirname(__FILE__) + '/../test_helper.rb'
load File.expand_path('../gmail_app.rb', __FILE__)

require 'pry'
require_relative 'gmail_app'
require_relative 'gmail_api_authenticator'

describe "Trendyol" do
  include TestHelper

  before(:all) do
    @driver = $driver = Selenium::WebDriver.for(browser_type, browser_options)
    driver.manage().window().resize_to(1920, 1080)
    # Bildirimleri otomatik kabul et

    driver.get("https://www.trendyol.com/")
  end

  before(:each) do
    sleep 1 # for some webdriver verson, it might not wait page loaded
  end

  after(:all) do
    # driver.quit unless debugging?
  end

  it "Trendyol Arama işlevselliği" do
    driver.find_element(:id, "onetrust-accept-btn-handler").click

    driver.find_element(:css, "[data-testid='suggestion']").click
    driver.find_element(:css, "[data-testid='suggestion']").send_keys("Kablosuz Kulaklık")
    driver.find_element(:css, "[data-testid='search-icon']").click

    # Arama sonuçlarının yüklenmesini bekle
    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    search_results_title = wait.until { driver.find_element(:xpath, "//*[@class='srch-rslt-title']/..//h1") }
    text = search_results_title.text

    # Arama sonuçlarin kulaklik kelimesini iceriyormu
    expect(text).to eq('Kablosuz Kulaklık')

    # Arama sonuçları boş olmamalı
    search_results = driver.find_elements(:xpath, "//*[@class='product-desc-sub-text']")
    expect(search_results.length).to be > 0

    # ilk ürünün adında kulaklık kelimesi aranacak
    first_product_title = search_results.first.find_element(:xpath, "//*[@class='product-desc-sub-text']").text.downcase
    expect(first_product_title).to include("kulaklık")

    # Ürün secimi yapmadan önce hangi penceredeyiz
    @current_window = driver.window_handles.first

    # Ürün Seçimi:
    # Rastgele bir ürün seçiliyor
    random_product = driver.find_elements(:xpath, "//*[@class='prdct-desc-cntnr-ttl']").sample

    # JavaScript kullanarak seçilen ürüne kaydırma
    driver.execute_script("arguments[0].scrollIntoView({ behavior: 'smooth', block: 'center' });", random_product)
    sleep 4

    # Ürün başlığını almadan önce wait ekleyelim
    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    wait.until { random_product.displayed? }

    # Metni alıyoruz ve instance variable'a atıyoruz
    random_product_text = random_product.text.split.first
    puts "Seçilen ürün: #{random_product_text}"

    # Seçilen ürüne tıklıyoruz
    random_product.click

    # Ürün seçildikten sonra yeni pencerenin acilmasini bekleyelim
    wait = Selenium::WebDriver::Wait.new(timeout: 10)
    wait.until { driver.window_handles.size > 1 }

    # Yeni sekmeye geçiyoruz
    driver.window_handles.each do |handle|
      if handle != @current_window
        driver.switch_to.window handle
        break
      end
    end

    # Kargo uyarisini kapat

    element = nil
    try_for(5, 0.1) do
      element = driver.find_element(:xpath, "//*[@class='onboarding-popover__default-renderer-primary-button']").click
    end
    sleep 3
    # Ürünün adı, fiyatı ve stok durumu gibi bilgilerin doğru bir şekilde görüntülendiğini doğrulayın.

    # Yeni sekmede acilan ürünün title sectigimiz ürünle aynı olmalı
    # bütün ürün özellikleri göstere tikla
    driver.find_element(:xpath, "//*[@class='button-all-features']").click

    random_product_title = driver.find_element(:xpath, "//*[@class='detail-name-container']").text
    keyword = random_product_title.split.first
    puts "keyword: #{keyword.inspect}"

    expect(random_product_text).to include(keyword)

    # Fiyat ve stok durumu gösterilmeli
    # tüm ürün özelliklerini göstere kaydir
    element = driver.find_element(:xpath, "//*[@class='button-all-features']")
    driver.execute_script("arguments[0].scrollIntoView(true);", element)
    sleep 2
    price = driver.find_element(:xpath, "//*[@class='sticky-product-desc']/..//*[@class='prc-dsc']").text

    # Fiyatın 'TL' içerdiğini ve sonrasında sayılar olduğunu doğrulamak için
    expect(price).to include("TL") # Fiyatın 'TL' içermesini bekliyoruz

    # Sayı kısmını almak ve kontrol etmek
    price_number = price.gsub("TL", "").strip # 'TL'yi çıkarıp boşlukları temizliyoruz

    # Rakamların bulunmasını bekliyoruz
    expect(price_number).to match(/\d+/) # Sayılar bulunmalı

    # stok kontrol edilecek
    driver.find_element(:xpath, "//*[@class='product-button-container']/..//*[@class='buy-now-button']").displayed?

    # 3. Sepete Ekleme:
    # • Seçilen ürünü sepete ekleyin.
    # • Ürünün sepette doğru bilgilerle göründüğünü doğrulayın.

    # sepete ekle butonuna tıklayın
    driver.find_element(:xpath,
                        "//*[@class='product-button-container']/..//*[@class='add-to-basket-button-text']").click

    sleep 2
    # sepete git butonuna tıklayın
    driver.find_element(:xpath,
                        "//*[@class='go-to-basket-text']").click

    # ürün alabileceğin ek hizmetleri kacirma butonuna tıklayın

    element = nil
    try_for(3, 1) do
      element = driver.find_element(:xpath,
                                    "//*[@class='pb-info-tooltip center pb-basket-item-add-vas-label-onboarding-tooltip']/..//button").click
    end

    # Ürünün sepete eklenip eklenmedigini kontrol etmek ürün adıyla doğrula
    sepet_ürün_adı = driver.find_element(:xpath, "//*[@class='pb-basket-item-details']//*[@class='pb-item']/span").text
    sepet_ürün_adı = sepet_ürün_adı.split(' ').first.strip
    puts "Seçilen ürün: #{sepet_ürün_adı}"
    expect(sepet_ürün_adı).to eq(random_product_text)

    # Ürünün fiyatinin sepette doğru göründüğünü doğrulayın.
    sepet_ürün_fiyat = driver.find_element(:xpath, "//*[@class='pb-basket-item-price']").text
    puts "sepet_ürün_fiyat: #{sepet_ürün_fiyat}"
    expect(sepet_ürün_fiyat).to eq(price)

    # Sepetteki ürünü sil
    driver.find_element(:xpath, "//*[@class='checkout-saving-remove-button']").click
    sleep 2

    # 4. Sepet Fiyat Doğrulaması:
    # • Sepete birden fazla ürün ekleyin.
    # • Sepetteki toplam fiyatın, ürünlerin bireysel fiyatlarının toplamına eşit olduğunu doğrulayın.
    #

    # İlk olarak, tüm elementleri buluyoruz
    # XPath ile tüm elementleri alıyoruz

    driver.switch_to.window(@current_window)
    elements = driver.find_elements(:xpath, '//*[@class="prc-box-dscntd"]')

    # İlk dört elementin text'ini alıyoruz ve rakam olarak işliyoruz
    first_four_prices = elements.first(4).map do |element|
      text = element.text.strip # Text'i temizle
      # Ondalık virgülü noktaya çevirip sayıya dönüştürüyoruz
      text.gsub(/[^\d,]/, '').gsub(',', '.').to_f
    end.compact # Boş değerleri kaldır

    # Fiyatların toplamını hesaplıyoruz
    total_price_all_products = first_four_prices.sum

    # Sonuçları yazdırıyoruz
    puts "Toplam fiyat: #{total_price_all_products}"

    # İlk dört ürünü sepete ekliyoruz
    # XPath ile tüm "add-to-basket-button" butonlarını alıyoruz
    buttons = driver.find_elements(:xpath, '//*[@class="add-to-basket-button"]')
    first_button = buttons.first
    sleep 5

    driver.execute_script("arguments[0].scrollIntoView({ behavior: 'smooth', block: 'center' });", first_button)
    sleep 2
    # İlk dört butona tıklıyoruz
    buttons.first(4).each_with_index do |button, index|
      button.click
      sleep 0.5
    end

    # Birden fazla ürünle sepete git butonua tıkliyoruz
    driver.find_element(:xpath, '//*[@class="go-to-basket-text"]').click

    # İlk <strong> etiketini buluyoruz
    basket_total_price = driver.find_elements(:xpath, "//*[@class='pb-summary-box-prices']//strong")

    # İlk öğenin text'ini alıyoruz ve sayıya çeviriyoruz
    first_basket_total_price = basket_total_price[0].text
    # "2.676 TL" formatındaki stringi sayıya çeviriyoruz
    first_basket_total_price_number = first_basket_total_price.gsub('.', '').gsub(' TL', '').to_f

    puts "Sepetteki toplam fiyat: #{first_basket_total_price_number}"
    puts "Hesaplanan toplam fiyat: #{total_price_all_products}"

    tolerance = total_price_all_products % 1 # Ondalıklı kısmı alır
    expect(first_basket_total_price_number).to be_within(tolerance).of(total_price_all_products)

    # 5. Sepetten Ürün Çıkarma:
    # • Sepetten bir ürünü kaldırın.
    # • Kaldırılan ürünün artık sepette listelenmediğini ve toplam fiyatın doğru şekilde güncellendiğini doğrulayın.
    #
    #
   
    # Ürün silinmeden önce fiyatini al
    sepetteki_ilk_ürünün_fiyatı = driver.find_elements(:xpath, "//*[@class='pb-basket-item-price']").first.text
    # Metni işleyerek sadece rakam kısmını al
    sepetteki_ilk_ürünün_fiyatı = sepetteki_ilk_ürünün_fiyatı.gsub(/[^\d,]/, '').gsub(',', '.').to_f

    puts "Sepetteki ilk ürünün fiyatı: #{sepetteki_ilk_ürünün_fiyatı}"

    cihaz = driver.find_elements(:xpath, "//*[@class='pb-basket-item-details']//p[@class='pb-item' and @title]").first

    puts "cihaz: #{cihaz.text}"

    driver.find_elements(:xpath, "//*[@class='i-trash']").first.click

    driver.navigate.refresh
    cihaz2 = driver.find_elements(:xpath, "//*[@class='pb-basket-item-details']//p[@class='pb-item' and @title]").first

    puts "cihaz2: #{cihaz2.text}"

    expect(cihaz2).not_to eq(cihaz)

    # ürün silindikten sonra kontrol et

    total_price_all_products -= sepetteki_ilk_ürünün_fiyatı

    puts "Toplam fiyat: #{total_price_all_products}"
    basket_total_price = driver.find_elements(:xpath, "//*[@class='pb-summary-box-prices']//strong")

    first_basket_total_price = basket_total_price[0].text
    # "2.676 TL" formatındaki stringi sayıya çeviriyoruz
    first_basket_total_price_number = first_basket_total_price.gsub('.', '').gsub(' TL', '').to_f

    puts "Sepetteki toplam fiyat: #{first_basket_total_price_number}"
    puts "Hesaplanan toplam fiyat: #{total_price_all_products}"

    tolerance = total_price_all_products % 1 # Ondalıklı kısmı alır
    expect(first_basket_total_price_number).to be_within(tolerance).of(total_price_all_products)

  end
end
