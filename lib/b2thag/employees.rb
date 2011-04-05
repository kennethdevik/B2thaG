require 'rest-client'
require 'json'

module B2thag
  class Employees

    def initialize(username, password)
      @username = username.gsub(' ', '%20')
      @password = password
      @url = 'https://%s:%s@intern.bekk.no/api/Employees.svc'
    end

    def all
      response = RestClient.get(@url % [@username, @password])
      JSON.parse(response)
    end

    def single(empid)
      url = (@url + "/%s") % [@username, @password, empid]
      response = RestClient.get(url)
      JSON.parse(response)
    end
  end
end