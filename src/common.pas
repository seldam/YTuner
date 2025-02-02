unit common;

// YTuner: Common constants, variables and procedures.

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, IdStack, IdGlobal, StrUtils, crc;

type
  TLogType = (ltNone, ltInfo, ltWarning, ltError, ltDebug);
  TResponseContentType = (ctNone, ctXML, ctPNG, ctJPG, ctGIF, ctTIFF, ctJSON);
  TCacheType = (catNone, catFile, catMemStr);

const
  APP_NAME = 'YTuner';
  APP_VERSION = '1.1.1';
  APP_COPYRIGHT = 'Copyright (c) 2023 Greg P. (https://github.com/coffeegreg)';
  INI_VERSION = '1.1.0';

  YTUNER_USER_AGENT = 'YTuner';
  YTUNER_HOST = 'ytunerhost';

  LOG_TYPE_MSG : array[TLogType] of string = ('','Inf','Wrn','Err','Dbg');

  MSG_FILE_LOAD_ERROR = ' file load error';
  MSG_FILE_SAVE_ERROR = ' file save error';
  MSG_FILE_DELETE_ERROR = ' file delete error';
  MSG_LOADING = 'loading';
  MSG_REMOVING = 'removing';
  MSG_GETTING = 'getting';
  MSG_ERROR = 'error';
  MSG_LOADED = 'loaded';
  MSG_SAVE = 'save';
  MSG_SAVED = 'saved';
  MSG_EMPTY = 'empty';
  MSG_CACHE = 'cache';
  MSG_FILE = 'file';
  MSG_STREAM = 'stream';
  MSG_OBJECTS = 'objects';
  MSG_BOOKMARK = 'bookmark';
  MSG_SUCCESSFULLY_LOADED = 'successfully loaded ';
  MSG_SUCCESSFULLY_SAVED = 'successfully saved ';
  MSG_SUCCESSFULLY_DOWNLOADED = 'successfully downloaded ';
  MSG_ERROR_LOAD = 'load error of';
  MSG_NOT_LOADED = 'not loaded';
  MSG_NOT_FOUND = 'not found';
  MSG_STATIONS = 'stations';

  MSG_RBUUID_CACHE_FILE = 'RB UUIDs cache file';

  INI_CONFIGURATION = 'Configuration';
  INI_RADIOBROWSER = 'RadioBrowser';
  INI_MYSTATIONS = 'MyStations';
  INI_BOOKMARK = 'Bookmark';
  INI_WEBSERVER = 'WebServer';
  INI_DNSSERVER = 'DNSServer';
  INI_MAINTENANCESERVER = 'MaintenanceServer';

  HTTP_HEADER_ACCEPT = 'Accept';
  HTTP_HEADER_USER_AGENT = 'User-Agent';
  HTTP_HEADER_LOCATION = 'Location';
  HTTP_HEADER_SERVER = 'Server';
  HTTP_RESPONSE_CONTENT_TYPE : array[TResponseContentType] of string = ('text/html; charset=utf-8','application/xml','image/png','image/jpeg','image/gif','image/tiff','application/json');

  MY_STATIONS_PREFIX = 'MS';
  RADIOBROWSER_PREFIX = 'RB';
  PATH_MY_STATIONS = 'my_stations';

  PATH_PARAM_ID = 'id';
  PATH_PARAM_MAC = 'mac';
  PATH_PARAM_FAV = 'fav';
  PATH_PARAM_SEARCH = 'search';
  PATH_PARAM_TOKEN = 'token';

  HTTP_CODE_OK = 200;
  HTTP_CODE_FOUND = 302;
  HTTP_CODE_NOT_FOUND = 404;
  HTTP_CODE_UNAVAILABLE = 503;

  DEFAULT_STRING = 'default';
  ESC_CHARS : Array Of AnsiString = ('\t','\n','\r','\b','\f');
  STRIP_CHARS: Array Of AnsiString =  ('!','*','''','(',')',';',':','@','&','=','+','$',',','/','?','%','#','[',']','-','_','.','~',#10,#13,#09);

  PATH_CACHE = 'cache';
  PATH_CONFIG = 'config';

  CACHE_EXT = '.cache';

var
  MyIPAddress: string = DEFAULT_STRING;
  LogType: TLogType = ltError;
  MyAppPath: string;
  UseSSL: boolean = True;
  CachePath: string = DEFAULT_STRING;
  ConfigPath: string = DEFAULT_STRING;

procedure Logging(ALogType: TLogType; ALogMessage: string);
function GetLocalIP(ADefaultIP: string): string;
function CalcFileCRC32(AFileName: string): Cardinal;
function RemoveEscChars(LInputStr: RawByteString): RawByteString;
function HaveCommonElements(AStr: string; AStrArray: array of string): boolean;
function ContainsIn(AStr: string; AStrArray: array of string): boolean;
function StripChars(AInputString: string):string;
function URLEncode(const AStr: String): AnsiString;

implementation

procedure Logging(ALogType: TLogType; ALogMessage: string);
begin
  if ALogType<=LogType then
    begin
      ALogMessage[1]:=UpCase(ALogMessage[1]);
      Writeln(DateTimeToStr(Now)+' : '+LOG_TYPE_MSG[ALogType]+' : '+ALogMessage+'.');
    end;
end;

function GetLocalIP(ADefaultIP: string): string;
var
  IPList: TIdStackLocalAddressList;
  i: integer = 0;

  function IsIP_v4(AIP_v4: string): Boolean;
  var
    i: LongInt;

    function TryStrToByte(const s: String; out i: LongInt): Boolean;
    begin
      Result:=((TryStrToInt(s,i)) and (i>=0) and (i<=255));
    end;

  begin
    Result:=((Length(AIP_v4.Split(['.']))=4)
             and (TryStrToByte(AIP_v4.Split(['.'])[0],i))
             and (TryStrToByte(AIP_v4.Split(['.'])[1],i))
             and (TryStrToByte(AIP_v4.Split(['.'])[2],i))
             and (TryStrToByte(AIP_v4.Split(['.'])[3],i)));
  end;
begin
//  Due to the filtering out of loopback interface IP addresses in the GetLocalAddressList procedure of the Indy library, we add it manually at this moment.
//  For more information look at: https://github.com/IndySockets/Indy/issues/494
//  Be careful! As you can see below, the given loopback IP address is not verified with the list of available IP addresses.
  if IsIP_v4(ADefaultIP) and (ADefaultIP.Split(['.'])[0]='127') then
    Result:=ADefaultIP
  else
    begin
      Result:='';
      try
        IPList := TIdStackLocalAddressList.Create;
        try
          TIdStack.IncUsage;
          try
            GStack.GetLocalAddressList(IPList);
          finally
            TIdStack.DecUsage;
          end;

            if IPList.Count > 0 then
              while (i<=IPList.Count-1) and (Result<>ADefaultIP) do
                begin
                  if IPList[i].IPVersion = Id_IPv4 then
                    begin
                      if Result='' then
                        Result:=IPList[i].IPAddress;
                      if IPList[i].IPAddress = ADefaultIP then
                        Result:=ADefaultIP;
                    end;
                  i:=i+1;
                end
            else
              Logging(ltError, 'No entries on IP List');
        finally
          IPList.Free;
        end;
      except
        On E: Exception do
          Logging(ltError, 'IP error: ' + E.message);
      end;
    end;
end;

function CalcFileCRC32(AFileName: string): Cardinal;
var
  Buffer : TBytes;
begin
  Result:=CRC32(0,nil,0);
  with TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone) do
    try
      SetLength(Buffer, Size);
      Read(Buffer,Size);
      Result:=CRC32(Result,@Buffer[0],Size);
    finally
      Free;
    end;
end;

function RemoveEscChars(LInputStr: RawByteString): RawByteString;
var
  i: integer;
begin
  for i:=Low(ESC_CHARS) to High(ESC_CHARS) do
    Result:=AnsiReplaceStr(LInputStr,ESC_CHARS[i],'');
end;

function HaveCommonElements(AStr: string; AStrArray: array of string): boolean;
var
  LStrEnum,LStrArrayEnum: string;
begin
  Result:=False;
  for LStrEnum in AStr.Split([',','/',';']) do
    for LStrArrayEnum in AStrArray do
      if IsWild(Trim(LStrEnum),LStrArrayEnum,True) then
      begin
        Result:=True;
        Exit;
      end;
end;

function ContainsIn(AStr: string; AStrArray: array of string): boolean;
var
  LStrArrayEnum: string;
begin
  Result:=False;
  for LStrArrayEnum in AStrArray do
    if ContainsText(AStr,LStrArrayEnum) then
      begin
        Result:=True;
        Exit;
      end;
end;

function StripChars(AInputString: string):string;
begin
  Result:=DelSpace1(StringsReplace(AInputString,STRIP_CHARS,(DupeString(' ,',Length(STRIP_CHARS)-1)+' ').Split([',']),[rfReplaceAll]).Trim);
end;

function URLEncode(const AStr: String): AnsiString;
var
  LAnsiChar: AnsiChar;
begin
  Result:='';
  for LAnsiChar in AStr do
    begin
      if ((Ord(LAnsiChar)<65) or (Ord(LAnsiChar)>90))
         and ((Ord(LAnsiChar)<97) or (Ord(LAnsiChar)>122)) then
        Result:=Result+'%'+IntToHex(Ord(LAnsiChar),2)
      else
        Result:=Result+LAnsiChar;
    end;
end;

end.


