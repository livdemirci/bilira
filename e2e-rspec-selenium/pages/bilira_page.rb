require File.join(File.dirname(__FILE__), "abstract_page.rb")

class BiliraPage < AbstractPage

  def initialize(driver)
    super(driver, "") # <= TEXT UNIQUE TO THIS PAGE
  end

  def accept_cookie
    element = nil
    begin
      try_for(5, 0.1) do
        element = driver.find_element(:xpath, '//*[@data-testid="accept-all-cookies-btn"]')
      end
      element.click if element
    rescue StandardError => e
      puts "Cookie görünmedi: #{e.message}"
    end
  end

end
