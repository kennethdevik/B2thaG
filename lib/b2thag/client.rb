require 'employees'
require 'gcontacts'
require 'exceptions'

module B2thag
  class Client
    @bemployees
    @gcontacts

    def initialize(bekk_username, bekk_password, gmail_username, gmail_password)
      @bemployees = B2thag::Employees.new(bekk_username, bekk_password) if bekk_username != nil and bekk_password != nil
      @gcontacts = GData::Client::Gcontacts.new
      @gcontacts.gclientlogin(gmail_username, gmail_password)
    end

    def add_employees_as_contacts_in_gmail
      begin
        @gcontacts.add_group('BEKK') unless @gcontacts.exists_group?('BEKK')
        @bemployees.all.each do |employee|
          @gcontacts.add_contact(employee, 'BEKK')
        end
        puts 'Ferdig med innleggingen av BEKK ansatt i Gmail'
      rescue Exceptions::B2thagError => error
        puts error
      end
    end

    def remove_all_employees_from_gmail
      begin
        @gcontacts.delete_all_b2thag_contacts
        @gcontacts.delete_group('BEKK')
        puts 'Alle BEKK ansatte er fjernet fra Gmail'
      rescue Exceptions::B2thagError => error
        puts error
      end
    end
  end
end
