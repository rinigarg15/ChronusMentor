require 'excon'

Excon::Socket.class_eval do
  private

  def connect
    @socket = nil
    exception = nil

    if @data[:proxy]
      family = @data[:proxy][:family] || ::Socket::Constants::AF_UNSPEC
      args = [@data[:proxy][:hostname], @data[:proxy][:port], family, ::Socket::Constants::SOCK_STREAM]
    else
      family = @data[:family] || ::Socket::Constants::AF_UNSPEC
      args = [@data[:hostname], @data[:port], family, ::Socket::Constants::SOCK_STREAM]
    end
    if RUBY_VERSION >= '1.9.2' && defined?(RUBY_ENGINE) && RUBY_ENGINE == 'ruby'
      args << nil << nil << false # no reverse lookup
    end

    # --- OVERRIDE BEGIN ---

    # --- ORIGINAL CODE BEGIN ---
    # addrinfo = ::Socket.getaddrinfo(*args)
    # --- ORIGINAL CODE END ---

    # --- OVERRIDE CODE BEGIN ---
    # Applying a retry here, due to temporary flap issues deployment is failing
    addrinfo = nil
    __chr_attempts = 0
    begin
      addrinfo = ::Socket.getaddrinfo(*args)
    rescue => error
      if __chr_attempts < 5
        __chr_attempts += 1
        sleep 1
        Excon.display_warning("Socket.getaddrinfo(*#{args.inspect}) failed, retrying attempt ##{__chr_attempts}")
        retry
      else
        raise error
      end
    end
    # --- OVERRIDE CODE END ---

    # --- OVERRIDE END ---

    addrinfo.each do |_, port, _, ip, a_family, s_type|
      @remote_ip = ip

      # already succeeded on previous addrinfo
      if @socket
        break
      end

      # nonblocking connect
      begin
        sockaddr = ::Socket.sockaddr_in(port, ip)

        socket = ::Socket.new(a_family, s_type, 0)

        if @data[:reuseaddr]
          socket.setsockopt(::Socket::Constants::SOL_SOCKET, ::Socket::Constants::SO_REUSEADDR, true)
          if defined?(::Socket::Constants::SO_REUSEPORT)
            socket.setsockopt(::Socket::Constants::SOL_SOCKET, ::Socket::Constants::SO_REUSEPORT, true)
          end
        end

        if @nonblock
          socket.connect_nonblock(sockaddr)
        else
          socket.connect(sockaddr)
        end
        @socket = socket
      rescue Errno::EINPROGRESS
        select_with_timeout(socket, :connect_write)
        begin
          socket.connect_nonblock(sockaddr)
          @socket = socket
        rescue Errno::EISCONN
          @socket = socket
        rescue SystemCallError => exception
          socket.close rescue nil
        end
      rescue SystemCallError => exception
        socket.close rescue nil if socket
      end
    end

    # this will be our last encountered exception
    fail exception unless @socket

    if @data[:tcp_nodelay]
      @socket.setsockopt(::Socket::IPPROTO_TCP,
                         ::Socket::TCP_NODELAY,
                         true)
    end
  end
end