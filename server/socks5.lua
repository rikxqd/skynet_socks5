local byte = string.byte
local char = string.char
local sub = string.sub

local socks5 = {}

socks5.SUB_AUTH_VERSION = 0x01
socks5.RSV = 0x00
socks5.NOAUTH = 0x00
socks5.GSSAPI = 0x01
socks5.AUTH = 0x02
socks5.IANA = 0x03
socks5.RESERVED = 0x80
socks5.NOMETHODS = 0xFF
socks5.VERSION = 0x05
socks5.IPV4 = 0x01
socks5.DOMAIN_NAME = 0x03
socks5.IPV6 = 0x04
socks5.CONNECT = 0x01
socks5.BIND = 0x02
socks5.UDP = 0x03
socks5.SUCCEEDED = 0x00
socks5.FAILURE = 0x01
socks5.RULESET = 0x02
socks5.NETWORK_UNREACHABLE = 0x03
socks5.HOST_UNREACHABLE = 0x04
socks5.CONNECTION_REFUSED = 0x05
socks5.TTL_EXPIRED = 0x06
socks5.COMMAND_NOT_SUPORTED = 0x07
socks5.ADDRESS_TYPE_NOT_SUPPORTED = 0x08
socks5.UNASSIGNED = 0x09

function socks5.send_method(sock, method)
    --
    --+----+--------+
    --|VER | METHOD |
    --+----+--------+
    --| 1  |   1    |
    --+----+--------+
    --
    
    local data = char(socks5.VERSION, method)

    return sock:send(data)
end

function socks5.receive_methods(sock)
    --
    --   +----+----------+----------+
    --   |VER | NMETHODS | METHODS  |
    --   +----+----------+----------+
    --   | 1  |    1     | 1 to 255 |
    --   +----+----------+----------+
    --
    
    local data, err = sock:receive(2)
    if not data then
        return nil, err
    end

    local ver = byte(data, 1)
    local nmethods = byte(data, 2)

    local methods, err = sock:receive(nmethods)
    if not methods then
        return nil, err
    end

    return {
        ver= ver,
        nmethods = nmethods,
        methods = methods
    }, nil
end

function socks5.send_replies(sock, rep, atyp, addr, port)
    --
    --+----+-----+-------+------+----------+----------+
    --|VER | REP |  RSV  | ATYP | BND.ADDR | BND.PORT |
    --+----+-----+-------+------+----------+----------+
    --| 1  |  1  | X'00' |  1   | Variable |    2     |
    --+----+-----+-------+------+----------+----------+
    --
    
    local data = {}
    data[1] = char(socks5.VERSION)
    data[2] = char(rep)
    data[3] = char(socks5.RSV)

    if atyp then
        data[4] = atyp
        data[5] = addr
        data[6] = port
    else
        data[4] = char(socks5.IPV4)
        data[5] = "\x00\x00\x00\x00"
        data[6] = "\x00\x00"
    end


    return sock:send(data)
end

function socks5.receive_requests(sock)
    --
    -- +----+-----+-------+------+----------+----------+
    -- |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
    -- +----+-----+-------+------+----------+----------+
    -- | 1  |  1  | X'00' |  1   | Variable |    2     |
    -- +----+-----+-------+------+----------+----------+
    --
    
    local data, err = sock:receive(4)
    if not data then
        return nil, err
    end

    local ver = byte(data, 1)
    local cmd = byte(data, 2)
    local rsv = byte(data, 3)
    local atyp = byte(data, 4)

    local dst_len = 0
    if atyp == socks5.IPV4 then
        dst_len = 4
    elseif atyp == socks5.DOMAIN_NAME then
        local data, err = sock:receive(1)
        if not data then
            return nil, err
        end
        dst_len = byte(data, 1)
    elseif atyp == socks5.IPV6 then
        dst_len = 16
    else
        return nil, "unknow atyp " .. atyp
    end

    local data, err = sock:receive(dst_len + 2) -- port
    if err then
        return nil, err
    end

    local dst = sub(data, 1, dst_len)
    local port_2 = byte(data, dst_len + 1)
    local port_1 = byte(data, dst_len + 2)
    local port = port_1 + port_2 * 256

    return {
        ver = ver,
        cmd = cmd,
        rsv = rsv,
        atyp = atyp,
        addr = dst,
        port = port,
    }, nil
end

function socks5.receive_auth(sock)
    --
    --+----+------+----------+------+----------+
    --|VER | ULEN |  UNAME   | PLEN |  PASSWD  |
    --+----+------+----------+------+----------+
    --| 1  |  1   | 1 to 255 |  1   | 1 to 255 |
    --+----+------+----------+------+----------+
    --
    
    local data, err = sock:receive(2)
    if err then
        return nil, err
    end

    local ver = byte(data, 1)
    local ulen = byte(data, 2)

    local data, err = sock:receive(ulen)
    if err then
        return nil, err
    end

    local uname = data

    local data, err = sock:receive(1)
    if err then
        return nil, err
    end

    local plen = byte(data, 1)

    local data, err = sock:receive(plen)
    if err then
        return nil, err
    end

    local passwd = data

    return {
        username = uname,
        password = passwd
    }, nil
end

function socks5.send_auth_status(sock, status)
    --
    --+----+--------+
    --|VER | STATUS |
    --+----+--------+
    --| 1  |   1    |
    --+----+--------+
    --

    local data = {}

    data[1] = char(socks5.SUB_AUTH_VERSION)
    data[2] = char(status)

    return sock:send(data)
end

return socks5
