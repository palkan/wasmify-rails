# frozen_string_literal: true

class BasicSocket
  def initialize(...)
    raise NotImplementedError, "Socket is not supported in Wasm"
  end
end

class Socket < BasicSocket
  AF_UNSPEC = 0
  AF_INET = 1
end

class IPSocket < Socket
  def self.getaddress(...)
    raise NotImplementedError, "Socket is not supported in Wasm"
  end
end

class TCPSocket < Socket
end
