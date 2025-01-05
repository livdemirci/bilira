require_relative 'spec/gmail_app'

app = GmailApp.new
puts "\nBağlı Gmail hesabı kontrol ediliyor..."
app.get_user_email

puts "\nSon mesajlar listeleniyor..."
app.list_messages

puts "\nSon mesajın içeriği:"
app.read_last_message
