require 'cinch'

require "net/http"
require "json"

class YouTube
  include Cinch::Plugin
  listen_to :message, :method => :handler

  @@host = 'openelec'
  @@port = 80
  @@path = '/jsonrpc'
  @@user = "xbmc"
  @@pass = 'xbmc'

  @@ask = nil;

  @@videos = []

  def send_xbmc_rpc(msg)
    req = Net::HTTP::Post.new(@@path, initheader = {'Content-Type' => 'application/json'})
    req.basic_auth @@user, @@pass
    req.body = msg
    result = Net::HTTP.new(@@host, @@port).start {|http| http.request(req)}
    if (result.code == "200")
         return JSON.parse(result.body)
    end
    return nil
  end

  def play(y_id)
    msg ={
      "jsonrpc" => "2.0",
      "method" => "Player.open",
      "params" => { 
        "item" => { 
          "file" => "plugin://plugin.video.youtube/?action=play_video&videoid=#{y_id}" 
        }
      },
      "id" => 1
    }.to_json
    return send_xbmc_rpc(msg)
  end

  def pause()
    msg ={
      "jsonrpc" => "2.0",
      "method" => "Player.PlayPause",
      "params" => {
        "playerid" => 1
      },
      "id" => 1
    }.to_json
    send_xbmc_rpc(msg)
  end

  def stop()
    msg ={
      "jsonrpc" => "2.0",
      "method" => "Player.close",
      "params" => {
        "playerid" => 1
      },
      "id" => 1
    }.to_json
    send_xbmc_rpc(msg)
  end

  def progress()
    msg ={
      "jsonrpc" => "2.0",
      "method" => "Player.GetProperties",
      "params" => {
        "playerid"  => 1,
        "properties" => ["percentage"]
      },
      "id" => 1
    }.to_json

    res = send_xbmc_rpc(msg)
    return "%.2f \%" % res["result"]["percentage"]
  end

  def get_item()
    msg ={
      "jsonrpc" => "2.0",
      "method" => "Player.GetItem",
      "params" => {
        "playerid"  => 1,
      },
      "id" => 1
    }.to_json

    res = send_xbmc_rpc(msg)
    return res["result"]["item"]
  end


  def handler(m)
    # asked for some action
    unless (@@ask.nil?)
      if (m.message == 'yes')
        m.reply "Alright, will do!"
        @@ask.call()
        @@ask = nil
      elsif (m.message == 'no')
        m.reply "Ok, I'll forget about it!"
        @@ask = nil
      end
    end
    if m.message == "play"
      if @@videos.length > 1
        y_id = @@videos.pop
        play(y_id)
      end
    end

    if m.message == "pause"
      pause
      m.reply "Type 'pause' again to unpause!"
    end

    if m.message == "stop"
      stop 
      m.reply "Playback stopped!"
    end

    if m.message == "status"
      perc = progress
      item = get_item
      puts item.to_s
      unless perc.nil? or item.nil?
        m.reply "Currently plaing: #{perc} - #{item["label"]} (#{item["type"]})"
      end
    end
    
    res = /http:\/\/www.youtube.com\/watch\?v=([^&]*)/.match(m.message)
    unless (res.nil? or res.length != 2) 
        y_id = res[1]
        m.reply "#{y_id}"

        @@ask  = lambda { play(y_id) }
        m.reply "Shall i play this Video?"
    end
  end
end


bot = Cinch::Bot.new do
  configure do |c|
    c.user = "xbmc_youtube"
    c.server = "irc.teranetworks.de"
    c.port = 6697
    c.channels = ["#test"]
    c.ssl.use = true
    c.plugins.plugins = [YouTube]
  end

#  on :message, "hello" do |m|
#    m.reply "Hello, #{m.user.nick}"
#  end
end

bot.start
