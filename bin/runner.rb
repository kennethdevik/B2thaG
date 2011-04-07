$: << File.expand_path(File.dirname($PROGRAM_NAME) + "/../lib/b2thag")
require 'client'

puts 'Would you like to add og delete contacts? (enter "add" or "delete")'
action = gets.strip.downcase

if(action == 'add')
  puts 'Enter BEKK username'
  busername = gets.strip
  bpassword = ask("Enter BEKK password: ") { |q| q.echo = false }
end
puts 'Enter Gmail username'
gusername = gets.strip
gpassword = ask("Enter Gmail password: ") { |q| q.echo = false }

b2tha_g = B2thag::Client.new(busername, bpassword, gusername, gpassword)

case action
  when 'add'
    b2tha_g.add_employees_as_contacts_in_gmail
  when 'delete'
    b2tha_g.remove_all_employees_from_gmail
end


