require 'gdata'
require 'open-uri'
require 'exceptions'

module GData
  module Client
    class Gcontacts < Contacts
      @username
      @addgroup_xml
      @addcontact_xml

      def initialize
        super
        gmail_xml_path = File.dirname($PROGRAM_NAME) + "/../lib/b2thag/gmailxml/"
        @addgroup_xml = gmail_xml_path + 'addgroup.xml'
        @addcontact_xml = gmail_xml_path + 'addcontact.xml'
      end

      def gclientlogin(username, password, captcha_token = nil,
        captcha_answer = nil, service = nil, account_type = nil)
        @username = username
        clientlogin(username, password, captcha_token, captcha_answer, service, account_type)
      end

      def delete_group(name)
        groups = get_contact_groups(name)
        delete_groups(groups)
      end

      def add_group(name)
        begin
          xml = get_text_from_file(@addgroup_xml)
          xml.gsub!('%groupname%', name)
          post(url_all_groups, xml)
          puts 'OK: Opprettet gruppen %s' % name
        rescue Exception => error
          raise Exceptions::AddGroupError.new 'FEIL: Fikk ikke opprettet gruppen %s (%s)' % [name, error]
        end
      end

      def add_contact(person, groupname)
        begin
          if Time.new.strftime("%Y%m%d").to_f < person['StartDate'].to_f
            raise Exceptions::SkipContactError.new 'SKIP: %s %s har ikke startet enda' % [person['FirstName'], person['LastName']]
          end

          if person['MobilePhone'] == nil || person['MobilePhone'] == ''
            raise Exceptions::SkipContactError.new 'SKIP: Mangler telefonnummer'
          end

          group = get_contact_groups(groupname)
          if group.length != 1
            raise Exceptions::SkipContactError.new 'Gruppen %s finnes ikke' % groupname
          end

          xml = get_text_from_file(@addcontact_xml)
          xml.gsub!('%Email%', CGI.escapeHTML(person['Email']))
          xml.gsub!('%FirstName%', CGI.escapeHTML(person['FirstName']))
          xml.gsub!('%LastName%', CGI.escapeHTML(person['LastName']))
          xml.gsub!('%Id%', person['Id'].to_s)
          xml.gsub!('%MobilePhone%', person['MobilePhone'])
          xml.gsub!('%PostalAddress%', CGI.escapeHTML(person['PostalAddress']))
          xml.gsub!('%PostalNr%', person['PostalNr'])
          xml.gsub!('%StreetAddress%', CGI.escapeHTML(person['StreetAddress']))
          xml.gsub!('%Department%', CGI.escapeHTML(person['Department']))
          xml.gsub!('%InterestGroup%', CGI.escapeHTML(person['InterestGroup']))
          xml.gsub!('%groupurl%', group[0][:id])

          response = post(url_all_contacts, xml)
          response_json =  JSON.parse(response.body)
          print 'OK: Lagt til %s %s.' % [person['FirstName'], person['LastName']]

          open('image.jpg', 'wb') do |file|
            file << open(person['ImageUrl']).read
          end

          photo_url = nil
          response_json['entry']['link'].each do |element|
            if element['type'] != nil && element['type'] == 'image/*'
              photo_url = element['href']
            end
          end

          add_photo(photo_url, response_json['entry']['gd$etag'])
        rescue Exceptions::SkipContactError => error
          print error
        rescue Exceptions::AddPhotoError => error
          print error
        rescue Exceptions::B2thagError
          raise
        rescue Exception => error
          raise Exceptions::AddContactError.new 'FEIL: Ukjent feil ved opprettelse av kontakt (%s)' % error
        ensure
          File.delete('image.jpg') if File.exists?('image.jpg')
          puts ''
        end
      end

      def get_all_contacts
        begin
          JSON.parse(get(url_all_contacts + '&max-results=100000').body)
        rescue Exception => error
          raise Exceptions::GetAllContactsError.new 'FEIL: Uthenting av alle kontakter feilet (%s).' % error
        end
      end

      def delete_all_b2thag_contacts
        begin
          b2thag_contacts = get_all_b2thag_contacts
          raise Exceptions::B2thagError.new 'Fant ingen kontakter som skal slettes' if b2thag_contacts.count == 0
          current_contact_name = nil

          b2thag_contacts.each do |contact|
            current_contact_name = contact['title']['$t']
            delete_contact(contact['id']['$t'], contact['gd$etag'])
            puts 'OK: Slettet %s' % current_contact_name
          end
        rescue Exceptions::B2thagError
          raise
        rescue Exception => error
          if current_contact_name.nil?
            raise Exceptions::DeleteAllB2thagContactsError.new 'FEIL: Avbryter slettingen av alle BEKK kontakter (%s)' % error
          else
            raise Exceptions::DeleteAllB2thagContactsError.new 'FEIL: Avbryter slettingen av alle BEKK kontakter etter at slettingen av %s feilet (%s).' % [current_contact_name, error]
          end
        end
      end

      def exists_group?(groupname)
        get_contact_groups(groupname).length == 1
      end

      private

      def add_photo(photo_url, etag)
        begin
          org_headers = headers.clone
          headers['If-Match'] = etag
          put_file(photo_url, 'image.jpg', 'image/*')
          print ' Bilde lastet opp.'
        rescue Exception => error
          raise Exceptions::AddPhotoError.new 'FEIL: Opplasting av bilde feilet(%s).' % error
        ensure
          @headers = org_headers
        end
      end

      def delete_contact(url, etag)
        @headers['If-Match'] = etag
        delete(url)
      end

      def get_all_b2thag_contacts
        all_contacts = get_all_contacts
        b2thag_contacts = []
        return b2thag_contacts if all_contacts['feed']['entry'].nil?

        all_contacts['feed']['entry'].each do |contact|
          if contact['content'] != nil && contact['content']['$t'] != nil && contact['content']['$t'].include?('BEKKID:')
            b2thag_contacts << contact
          end
        end
        b2thag_contacts
      end

      def get_contact_groups(name)
        begin
        groups = get(url_all_groups).to_xml

        testgroups = []
        groups.elements.each('entry') do |group|
          if group.elements['title'].text == name
            testgroups <<
            {
              :id => group.elements['id'].text,
              :etag => group.attribute('etag').value,
              :name => group.elements['title'].text
            }
          end
        end
        testgroups
        rescue Exception => error
          raise Exceptions::GetContactGroupsError.new 'FEIL: Uthenting av kontaktgrupper feilet (%s)' % error
        end
      end

      def delete_groups(groups)
        begin
        groups.each do |group|
          headers['If-Match'] = group[:etag]
          delete(group[:id])
          puts 'OK: Slettet gruppen %s' % group[:name]
        end
        rescue Exception => error
           raise Exceptions::DeleteGroupsError.new 'FEIL: Sletting av gruppe(r) feilet (%s)' % error
        end
      end

      def get_text_from_file(filename)
        file = File.open(filename, 'r')
        xml = file.read
        file.close
        xml
      end

      def url_all_groups
        'https://www.google.com/m8/feeds/groups/%s/full' % @username
      end

      def url_all_contacts
        'https://www.google.com/m8/feeds/contacts/%s/full?alt=json' % @username
      end
    end
  end
end