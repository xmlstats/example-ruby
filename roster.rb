#!/usr/bin/env ruby

require 'net/http'
require 'openssl'
require 'json'
require_relative 'config'

def main
    # See https://erikberg.com/api/endpoints#requrl and build_url function
    host = 'erikberg.com'
    sport = 'nba'
    endpoint = 'teams'
    id = nil
    format = 'json'
    parameters =  nil

    url = build_url(host, sport, endpoint, id, format, parameters)

    data, xmlstats_remaining, xmlstats_reset = http_get(url)
    teams = JSON.parse(data)
    teams.each { |team|
        # If no more requests are available in current window, wait.
        # Important: make sure your system is using NTP or equivalent, otherwise
        # this will produce incorrect results.
        if xmlstats_remaining == 0
            now = Time.now.strftime('%s').to_i
            delta = xmlstats_reset - now
            printf("Reached rate limit. Waiting %d seconds to make new request\n", delta)
            sleep(delta)
        end
        url = build_url(host, sport, 'roster', team['team_id'], 'json', nil)
        data, xmlstats_remaining, xmlstats_reset = http_get(url)
        roster = JSON.parse(data)

        # Process roster data... In this example, we are just printing each roster
        printf("%s %s Roster\n", roster['team']['first_name'], roster['team']['last_name'])
        roster['players'].each { |player|
            printf("%25s, %-2s %5s %3s lb\n",
                   player['display_name'],
                   player['position'],
                   player['height_formatted'],
                   player['weight_lb']);
        }
    }
end

def http_get(url)
    Net::HTTP.start(url.host, url.port, :use_ssl => true) do |http|
        req = Net::HTTP::Get.new(url.request_uri)
        req['Authorization'] = sprintf("Bearer %s", Config::ACCESS_TOKEN)
        req['User-agent'] = sprintf("xmlstats-exruby/%s (%s)",
                                    Config::USER_AGENT_CONTACT,
                                    Config::VERSION);
        res = http.request(req)
        case res
        when Net::HTTPSuccess then
            data = res.body
            xmlstats_remaining = res['xmlstats-api-remaining'].to_i
            xmlstats_reset = res['xmlstats-api-reset'].to_i
            return data, xmlstats_remaining, xmlstats_reset
        else
            puts "Error retrieving file: #{res.code} #{res.message}"
            puts res.body
            exit(1)
        end
    end
end

def build_url(host, sport, endpoint, id, format, parameters)
    path = '/'
    path += [sport, endpoint, id].compact * '/'
    path += '.' + format
    uri = URI::HTTPS.new('https', nil, host, nil, nil, path, nil, nil, nil)
    if parameters
        uri.query = URI.encode(parameters.map{|k,v| "#{k}=#{v}"}.join('&'))
    end
    return uri
end

main
