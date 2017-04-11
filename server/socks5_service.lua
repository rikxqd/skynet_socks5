local skynet = require "skynet";
local log = require "log";
local socket = require "socket";

local port, username, password = ...

if port then

    skynet.start(function()
        local id = socket.listen("0.0.0.0", port)

        socket.start(id , function(id, addr)
            local agent = skynet.newservice(SERVICE_NAME);
            log.Infof("%s connected, pass it to agent :%08x", addr, agent)
            skynet.send(agent, "lua", id, addr, username, password)
        end)
    end)

else

    local socks5 = require "socks5"
    local socket_adapter = {
        id = nil,
        send = function (self, data)
            local ret;
            if type(data) == "table" then
                for i, v in ipairs(data) do
                    ret = socket.write(self.id, v)
                    if not ret then
                        break
                    end
                end
            else
                ret = socket.write(self.id, data)
            end

            if not ret then
                return nil, "socket.write failed"
            end
            return true
        end,
        receive = function (self, sz)
            local data = socket.read(self.id, sz)
            if not data then
                return nil, "socket.read failed"
            end
            return data
        end,
    }

    local function exit(id, req_id)
        socket.close(id)
        if req_id then
            socket.close(id)
        end
        skynet.exit();  
    end

    local function pipe(recv_id, send_id)
        while true do
            local data = socket.read(recv_id)
            if not data then
                return exit(recv_id, send_id)
            end

            local ret = socket.write(send_id, data)
            if not ret then
                return exit(recv_id, send_id)
            end
        end
    end

    local function main(id, addr, username, password)
        socket.start(id)
        socket_adapter.id = id

        local negotiation, err = socks5.receive_methods(socket_adapter)
        if err then
            log.Infof("receive methods error: %s", err)
            return exit(id)
        end

        if negotiation.ver ~= socks5.VERSION then
            log.Infof("only support version: %s", socks5.VERSION)
            return exit(id)
        end

        local method = socks5.NOAUTH
        if username then
            method = socks5.AUTH
        end

        local ok, err = socks5.send_method(socket_adapter, method)
        if err then
            log.Infof("end method error: %s", err)
            return exit(id)
        end

        if username then
            local auth, err = socks5.receive_auth(socket_adapter)
            if err then
                log.Infof("receive auth error: %s", err)
                return exit(id)
            end

            local status = socks5.FAILURE
            if auth.username == username and auth.password == password then
                status = socks5.SUCCEEDED
            end

            local ok, err = socks5.send_auth_status(socket_adapter, status)
            if err then
                log.Infof("send auth status error: %s", err)
                return exit(id)
            end

            if status == socks5.FAILURE then
                log.Infof("auth failed")
                return exit(id)
            end
        end      

        local requests, err = socks5.receive_requests(socket_adapter)
        if err then
            log.Infof("receive requests: %s", err)
            return exit(id)
        end

        if requests.cmd ~= socks5.CONNECT then
            local ok, err = socks5.send_replies(socket_adapter, socks5.COMMAND_NOT_SUPORTED)
            if err then
                log.Infof("send replies error: %s", err)
                return exit(id)
            end
            
            log.Infof("receive_requests cmd: %s not support", requests.cmd)
            return exit(id)
        end

        local req_id = socket.open(ip or requests.addr, requests.port) 
        if not req_id then
            log.Infof("connect request %s:%s failed.", requests.addr, requests.port)
            socks5.send_replies(socket_adapter, socks5.NETWORK_UNREACHABLE)
            return exit(id)
        end

        local ok, err = socks5.send_replies(socket_adapter, socks5.SUCCEEDED) 
        if err then
            log.Infof("send replies error: %s", err)
            return exit(id, req_id)
        end
            
        log.Infof("%s <-----> %s:%s", addr, requests.addr, requests.port)

        skynet.fork(function ()
            pipe(id, req_id)
        end)
        
        skynet.fork(function ()
            pipe(req_id, id)
        end)
    end

    skynet.start(function()
        skynet.dispatch("lua", function (_, _, id, addr, username, password)
            main(id, addr, username, password)
        end)
    end)
end
