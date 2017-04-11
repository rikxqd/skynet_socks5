local Skynet =  require("skynet");
local StartTime = Skynet.starttime();
local Logger = {};

Logger.NOLOG = 0;
Logger.DEBUG = 10;
Logger.INFO = 20;
Logger.WARNING = 30;
Logger.ERROR = 40;
Logger.CRITICAL = 50;
Logger.FATAL = 60;

Logger.LogLevel = Logger.DEBUG;
Logger.StackLevel = 3;
Logger.EnableLogSrc = true;

local function GetLogSrc(level)
    local info = debug.getinfo(level + 1, "Sl");
    local src = info.source;
    return src .. ":" .. info.currentline .. ":";
end

local function LogFormat(level, ...)
    local t = {...};
    local out = nil;
    for _, v in pairs(t) do
        v_str = tostring(v);

        if not out then
            out = v_str;
        else
            out = out .. "\t" .. v_str;
        end
    end
    return out;
end

local function LogTimestamp(timestamp)
    local sec = timestamp / 100;
    local ms  = timestamp % 100;
    local f = os.date("%Y-%m-%d %H:%M:%S", math.floor(StartTime + sec));
    f = string.format("%s.%02d", f, ms);
    return f;
end

local function Log(level, ...)
    if level < Logger.LogLevel then
        return;
    end

    local timestamp = LogTimestamp(Skynet.now());
    local src = Logger.EnableLogSrc and GetLogSrc(Logger.StackLevel) or "";
    local msg = LogFormat(level, ...);
    local log = string.format("[%s %s]%s %s", timestamp, level, src, msg);

    Skynet.error(log);    
end

function Logger.Debug(...)
    Log(Logger.DEBUG, ...);
end
function Logger.Debugf(format, ...)
    Log(Logger.DEBUG, string.format(format, ...));
end

function Logger.Info(...)
    Log(Logger.INFO, ...);
end
function Logger.Infof(format, ...)
    Log(Logger.INFO, string.format(format, ...));
end

function Logger.Warning(...)
    Log(Logger.WARNING, ...);
end
function Logger.Warningf(format, ...)
    Log(Logger.WARNING, string.format(format, ...));
end

function Logger.Error(...)
    Log(Logger.ERROR, ...);
end
function Logger.Errorf(format, ...)
    Log(Logger.ERROR, string.format(format, ...));
end

function Logger.Critical(...)
    Log(Logger.CRITICAL, ...);
end
function Logger.Criticalf(format, ...)
    Log(Logger.CRITICAL, string.format(format, ...));
end

function Logger.Fatal(...)
    Log(Logger.FATAL, ...);
end

function Logger.Fatalf(format, ...)
    Log(Logger.FATAL, string.format(format, ...));
end

function Logger.Assert(v, message)
    if not v then
        Log(Logger.ERROR, "assert:"..tostring(message));
    end
    return assert(v, message);
end

function Logger.SError(message, level)
    level = level and level + 1 or 2
    Log(Logger.CRITICAL, "error:" .. tostring(message));
    error(message, level);
end

return Logger;

