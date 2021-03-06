require 'spec_helper'

RSpec.describe Reel::WebSocket do
  include WebSocketHelpers

  let(:example_message) { "Hello, World!" }
  let(:another_message) { "What's going on?" }

  it "performs websocket handshakes" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)
      client << handshake.to_data

      request = connection.request
      expect(request).to be_websocket

      websocket = request.websocket
      expect(websocket).to be_a Reel::WebSocket

      expect(handshake.errors).to be_empty
    end
  end

  it "raises an error if trying to close a connection upgraded to socket" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)
      client << handshake.to_data

      websocket = connection.request.websocket
      expect(websocket).to be_a Reel::WebSocket
      expect { connection.close }.to raise_error(Reel::StateError)
    end
  end

  it "knows its URL" do
    with_websocket_pair do |_, websocket|
      expect(websocket.url).to eq(example_path)
    end
  end

  it "knows its headers" do
    with_websocket_pair do |_, websocket|
      expect(websocket['Host']).to eq(example_host)
    end
  end

  it "reads frames" do
    with_websocket_pair do |client, websocket|
      client << WebSocket::Message.new(example_message).to_data
      client << WebSocket::Message.new(another_message).to_data

      expect(websocket.read).to eq(example_message)
      expect(websocket.read).to eq(another_message)
    end
  end

  it "writes messages" do
    with_websocket_pair do |client, websocket|
      websocket.write example_message
      websocket.write another_message

      parser = WebSocket::Parser.new

      parser.append client.readpartial(4096) until first_message = parser.next_message
      expect(first_message).to eq(example_message)

      parser.append client.readpartial(4096) until next_message = parser.next_message
      expect(next_message).to eq(another_message)
    end
  end

  it "closes" do
    with_websocket_pair do |_, websocket|
      expect(websocket).not_to be_closed
      websocket.close
      expect(websocket).to be_closed
    end
  end

  it "raises a RequestError when connection used after it was upgraded" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)
      client << handshake.to_data

      remote_host = connection.remote_host

      request = connection.request
      expect(request).to be_websocket
      websocket = request.websocket
      expect(websocket).to be_a Reel::WebSocket

      expect { connection.remote_host }.to raise_error(Reel::StateError)
      expect(websocket.remote_host).to eq(remote_host)
    end
  end

  it "performs websocket handshakes with header key case-insensitivity" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)
      client << case_handshake.to_data

      request = connection.request
      expect(request).to be_websocket

      websocket = request.websocket
      expect(websocket).to be_a Reel::WebSocket

      expect(case_handshake.errors).to be_empty
    end
  end

  def with_websocket_pair
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)
      client << handshake.to_data
      request = connection.request

      expect(request).to be_websocket
      websocket = request.websocket
      expect(websocket).to be_a Reel::WebSocket

      # Discard handshake
      client.readpartial(4096)

      yield client, websocket
    end
  end
end
