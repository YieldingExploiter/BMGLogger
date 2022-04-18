local NameFunction = function(name, cb)
  return setmetatable({}, {
    __index = function(_, index) return error('Attempt to index function with \'' .. index .. '\'') end;
    __newindex = function(_, index) return error('Attempt to index function with \'' .. index .. '\'') end;
    __call = function(_, ...) return cb(...) end;
    __tostring = function() return '<function ' .. name .. '>' end;
  })
end
local rawError = error;
local error = function(...) return rawError(table.concat({...}, ' ')) end

local Logger = setmetatable({}, {
  __tostring = function(Logger) return string.format('BaseUnconstructedLogger(minimumLogLevel=%d)', Logger.MinimumLogLevel) end;
  __call = function(Logger, ...) return Logger.new(...) end;
});
-- local Logger = {};
Logger.__index = function(self, index)
  return rawget(self, index) or rawget(self, string.lower(index)) or rawget(Logger, index) or
             rawget(Logger, string.lower(index))
end;
Logger.__tostring = function(self)
  return string.format('Logger(name=\'%s\', defaultLevel=%s)', self.LoggerName, self.LogLevel)
end
local LogLevel = {Debug = 0; Info = 1; Warning = 2; Error = 3; Fatal = 4};
Logger.LogLevel = LogLevel;

Logger.MinimumLogLevel = LogLevel.Debug;

local Names = {};
for name, level in pairs(LogLevel) do Names[level] = name; end
for name in pairs(LogLevel) do Names[name] = name; end
local Prints = {
  [LogLevel.Debug] = print;
  [LogLevel.Info] = print;
  [LogLevel.Warning] = warn;
  [LogLevel.Error] = error;
  [LogLevel.Fatal] = error;
}

Logger.LogWithLevel = NameFunction('LogWithLevel(Level, ...)', function(self, Level, ...)
  if typeof(Level) == 'string' then Level = LogLevel[Level] end
  if (Level >= Logger.MinimumLogLevel) then
    (Prints[Level])(string.format('[BMG | %s | %s]', self.LoggerName, tostring(Names[Level])), ...)
  end
end)
Logger.__call = function(self, ...)
  local Level = self.LogLevel;
  return Logger.LogWithLevel(self, Level, ...);
end

local LoggerFromLogLevel = function(Level, CoroutineWrap)
  local Logger = function(self, ...) return Logger.LogWithLevel(self, Level, ...); end
  return NameFunction('Logger (Level ' .. Level .. ')', CoroutineWrap and function(...)
    local Tuple = {...};
    return coroutine.resume(coroutine.create(function() Logger(unpack(Tuple)); end))
  end or Logger);
end;
Logger.debug = LoggerFromLogLevel(LogLevel.Debug);
Logger.log = Logger.debug;
Logger.print = Logger.log;
Logger.info = LoggerFromLogLevel(LogLevel.Info);
Logger.warn = LoggerFromLogLevel(LogLevel.Warning);
Logger.warning = LoggerFromLogLevel(LogLevel.Warning);
Logger.error = LoggerFromLogLevel(LogLevel.Error, true);
Logger.fatal = LoggerFromLogLevel(LogLevel.Fatal);

Logger.ArgumentsToString = NameFunction('ArgsToString', function(funcName, args)
  local argsList;
  for argName, argValue in pairs(args) do
    argsList = (argsList and (argsList .. ', ') or '') .. argName .. '=' ..
                   tostring(typeof(argValue) == 'string' and ('\'' .. argValue .. '\'') or argValue);
  end
  return string.format('%s(%s)', funcName, argsList);
end);

Logger.AssertArguments = NameFunction('AssertArguments', function(self, funcname, args, types, _, _loggerFunc)
  local error = _loggerFunc or error;
  if not types then
    types = args;
    args = funcname;
    funcname = 'unknown(...): ';
  elseif funcname then
    funcname = Logger.ArgumentsToString(funcname, args) .. ': '
  end
  local ArgsAsStr = Logger.ArgumentsToString('AssertArguments',
                                             {['self'] = self; ['funcname'] = funcname; ['args'] = args; ['types'] = types})
  assert(self and funcname and args and types,
         '[BMG | Logger | Fatal] ' .. ArgsAsStr .. ': Expected 3 arguments, got ' .. #{self; funcname; args; types} .. '.');
  if (typeof(args) ~= 'table') then error(ArgsAsStr .. ': Expected argument #2 to be a table, got ' .. typeof(args) .. '.'); end
  if (typeof(types) ~= 'table') then
    error(ArgsAsStr .. ': Expected argument #3 to be a table, got ' .. typeof(args) .. '.');
  end
  for ArgumentIndex, ExpectedTypes in pairs(types) do
    local TypeMatches, Type = 0, typeof(args[ArgumentIndex])
    for _, ExpectedType in pairs(string.split(ExpectedTypes, '|')) do
      if (Type == ExpectedType) then TypeMatches = TypeMatches + 1 end
    end
    if TypeMatches == 0 then
      rawError(string.format('[BMG | %s | Fatal] %sInvalid Argument %s (expected %s, recieved %s)', self.LoggerName,
                             funcname,
                             (typeof(ArgumentIndex) == 'string' and ArgumentIndex or '#' .. tostring(ArgumentIndex)),
                             ExpectedTypes, Type), 2);
    end
  end
end)

Logger.new = NameFunction('LoggerConstructor', function(loggerName, logLevel)
  Logger.AssertArguments({LoggerName = 'Logger'}, 'Logger.new(loggerName, logLevel)', {loggerName; logLevel},
                         {'string'; 'string|number'});
  local self = setmetatable({}, Logger);
  self.LoggerName = loggerName;
  self.LogLevel = (logLevel[logLevel or 'Debug'] or logLevel['Debug']) or logLevel;
  self.new = function() error('Cannot construct from existing Logger') end
  return self;
end);

return Logger;
