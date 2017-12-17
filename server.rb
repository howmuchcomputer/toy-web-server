#!/usr/bin/env ruby
#
# A very simple, deeply insecure, non-spec compliant toy web server, enjoy!
#
# In case you are the type of person that needs to be reminded to breathe:
# DO NOT USE THIS CODE
#

require 'socket'

MAX_CONN     = 0
DEFAULT_PORT = 9000
DEFAULT_ADDR = "127.0.0.1"

def main
  socket = Socket.new(:INET, :STREAM)
  socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
  socket.bind(Addrinfo.tcp(DEFAULT_ADDR, DEFAULT_PORT))
  #
  # set to 0 for demo purposes
  #            
  socket.listen(MAX_CONN)
  #
  # 'conn_sock' is different from 'socket'
  # 'socket' listens for connections then spawns
  # off another socket ( 'conn_sock' ) when a client
  # connects to the server
  #
  conn_sock, addr_info = socket.accept
  conn = Connection.new(conn_sock)
  request = read_request(conn)
  respond_for_request(conn_sock, request)
end

def respond_for_request(conn_sock, request)
  #
  # this is wildly insecure
  # ie - /../../../etc/passwd
  #
  path = Dir.getwd + request.path
  if File.exists?(path)
    #
    # cgi-bin
    #
    if File.executable?(path)
      content = `#{path}`
    else
      content = File.read(path)
    end
    status_code = 200
  else
    content = ""
    status_code = 404
  end
  respond(conn_sock, status_code, content)
end

def read_request(conn)
  request_line = conn.read_line
  method, path, version = request_line.split(" ", 3)
  headers = {}
  loop do
    line = conn.read_line
    break if line.empty?
    key, value = line.split(/:\s*/, 2)
    headers[key] = value
  end
  Request.new(method, path, headers)
end

def respond(conn_sock, status_code, content)
  status_text = {
    200 => "OK",
    404 => "Not Found"
  }.fetch(status_code)
  conn_sock.send("HTTP/1.1 #{status_code} #{status_text}\r\n", 0)
  conn_sock.send("Content-Length: #{content.length}\r\n", 0)
  conn_sock.send("\r\n", 0)
  conn_sock.send(content, 0)
end

Request = Struct.new(:method, :path, :headers)

class Connection
  # 
  # chosen arbitrarily
  #
  PACKET_SIZE = 7

  def initialize(conn_sock)
    @conn_sock = conn_sock
    @buffer = ""
  end

  #
  # it thinks it is talking to a typewriter
  #
  def read_line
    read_until("\r\n")
  end

  def read_until(string)
    until @buffer.include?(string)
      @buffer += @conn_sock.recv(PACKET_SIZE)
    end
    result, @buffer = @buffer.split(string, 2)
    result
  end
end

main
