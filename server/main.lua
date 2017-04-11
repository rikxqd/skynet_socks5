local skynet = require "skynet";

skynet.start(function()	
	-- skynet.newservice("socks5_service", 9876, "acai", "123456")
	skynet.newservice("socks5_service", 9876)
	skynet.exit();	
end)