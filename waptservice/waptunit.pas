unit WaptUnit; 

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, IdHTTPServer, DaemonApp, IdCustomHTTPServer,
  IdContext, fphtml, sqlite3conn, sqldb, db;

type

  { TWaptDaemon }

  TWaptDaemon = class(TDaemon)
    IdHTTPServer1: TIdHTTPServer;
    QLstPackages: TSQLQuery;
    QLstPackagesArchitecture: TMemoField;
    QLstPackagesDescription: TMemoField;
    QLstPackagesFilename: TMemoField;
    QLstPackagesMaintainer: TMemoField;
    QLstPackagesMD5sum: TMemoField;
    QLstPackagesPackage: TMemoField;
    QLstPackagesPriority: TMemoField;
    QLstPackagesrepo_url: TMemoField;
    QLstPackagesSection: TMemoField;
    QLstPackagesSize: TMemoField;
    QLstPackagesVersion: TMemoField;
    SQLTrans: TSQLTransaction;
    waptdb: TSQLite3Connection;
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleStart(Sender: TCustomDaemon; var OK: Boolean);
    procedure IdHTTPServer1CommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure waptdbAfterConnect(Sender: TObject);
  private
    { private declarations }
    Function TableHook(Data,FN:String):String;
  public
    { public declarations }
  end; 

var
  WaptDaemon: TWaptDaemon;

implementation
uses Waptcommon,JclSysInfo,StrUtils;

procedure RegisterDaemon;
begin
  RegisterDaemonClass(TWaptDaemon)
end;

Type TFormatHook = Function(Data,FN:String):String of Object;

{ TWaptDaemon }
function DatasetToHTMLtable(ds:TDataset;FormatHook: TFormatHook=Nil):String;
var
    i:integer;
begin
  result := '<table><tr>';
  For i:=0 to ds.FieldCount-1 do
    if ds.Fields[i].Visible then
      Result := Result + '<th>'+ds.Fields[i].DisplayLabel+'</th>';
  result := Result+'</tr>';
  ds.First;
  while not ds.EOF do
  begin
    result := Result + '<tr>';
    For i:=0 to ds.FieldCount-1 do
      if ds.Fields[i].Visible then
      begin
        if Assigned(FormatHook) then
          Result := Result + '<td>'+FormatHook(ds.Fields[i].AsString,ds.Fields[i].FieldName)+'</td>'
        else
          Result := Result + '<td>'+ds.Fields[i].AsString+'</td>';
      end;
    result := Result+'</tr>';
    ds.Next;
  end;
  result:=result+'</table>';
end;

procedure TWaptDaemon.DataModuleStart(Sender: TCustomDaemon; var OK: Boolean);
begin
  Application.Log(etInfo,'c:\wapt\wapt-get upgrade');
end;

procedure TWaptDaemon.DataModuleCreate(Sender: TObject);
begin
  SQLiteLibraryName:=AppendPathDelim(ExtractFilePath(ParamStr(0)))+'DLLs\sqlite3.dll';
  IdHTTPServer1.Active:=True;
end;

procedure TWaptDaemon.IdHTTPServer1CommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
    ExitStatus:Integer;
    CPUInfo:TCpuInfo;
    IP : TStringList;
    Cmd,IPS:String;
    i:integer;
    param,value,lst:String;
begin
  if ARequestInfo.URI='/status' then
  try
    QLstPackages.Close;
    QLstPackages.Open;
    AResponseInfo.ContentText:=DatasetToHTMLtable(QLstPackages,@TableHook);
  finally
    SQLTrans.Commit;
  end
  else
  if ARequestInfo.URI='/upgrade' then
  begin
    Application.Log(etInfo,'c:\wapt\wapt-get upgrade');
    AResponseInfo.ContentText:='Wapt Upgrade launched<br>'+
      RunTask('c:\wapt\wapt-get upgrade',ExitStatus);
  end
  else
  if ARequestInfo.URI='/install' then
  begin
    if not ARequestInfo.AuthExists or (ARequestInfo.AuthUsername <> 'admin') then
    begin
      AResponseInfo.ResponseNo := 401;
      AResponseInfo.ResponseText := 'Authorization required';
      AResponseInfo.ContentType := 'text/html';
      AResponseInfo.ContentText := '<html>Authentication required for Installation operations </html>';
      AResponseInfo.CustomHeaders.Values['WWW-Authenticate'] := 'Basic realm="WAPT-GET Authentication"';
      Exit;
    end;
    if ARequestInfo.Params.Count<=0 then
    begin
      AResponseInfo.ResponseNo := 404;
      AResponseInfo.ContentType := 'text/html';
      AResponseInfo.ContentText := '<html>Please provide a "package" parameter</html>';
      Exit;
    end;
    i:= ARequestInfo.Params.IndexOfName('package');
    cmd := 'c:\wapt\wapt-get install '+ARequestInfo.Params.ValueFromIndex[i];
    Application.Log(etInfo,cmd);
    AResponseInfo.ContentText:='Wapt Install launched<br><pre>'+
      StringsReplace(RunTask(cmd,ExitStatus),[#13#10,#13,#10],['<br>','<br>','<br>'],[rfReplaceAll])+'</pre>';
  end
  else
  begin
    IP := TStringList.Create;
    try
      GetIpAddresses(IP);
      IPS := IP.Text;
    finally
      IP.free;
    end;
    GetCpuInfo(CPUInfo);
    AResponseInfo.ContentText:=(
      '<h1>Etat du systeme</h1>'+
      'URI:'+ARequestInfo.URI+'<br>'+
      'AuthUsername:'+ARequestInfo.AuthUsername+'<br>'+
      'Document:'+ARequestInfo.Document+'<br>'+
      'Params:'+ARequestInfo.Params.Text+'<br>'+
      'User : '+AnsiToUTF8(GetLocalUserName)+'<br>'+
      'Machine: '+GetLocalComputerName+'<br>'+
      'Domaine: '+GetDomainName+'<br>'+
      'Adresses IP:'+IPS+'<br>'+
      'Système: '+GetWindowsVersionString+' '+GetWindowsEditionString+' '+GetWindowsServicePackVersionString+'<br>'+
      'RAM: '+FormatFloat('###0 MB',GetTotalPhysicalMemory/1024/1024)+'<br>'+
      'CPU: '+CPUInfo.CpuName+'<br>'+
      'Charge Mémoire: '+IntToStr(GetMemoryLoad)+'%');
  end;
  AResponseInfo.ContentText := '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">'+
       '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">'+
       '<head><meta http-equiv="Content-Type" content="text/html; charset=utf-8" />'+
       '<title>Wapt-get management</title></head>'+
       '<body>'+AResponseInfo.ContentText+'</body>';
  AResponseInfo.ResponseNo:=200;
end;

procedure TWaptDaemon.waptdbAfterConnect(Sender: TObject);
begin

end;

function TWaptDaemon.TableHook(Data, FN: String): String;
begin
  FN := LowerCase(FN);
  if FN='package' then
    Result:='<a href="/install?package='+Data+'">'+Data+'</a>'
  else
    Result := Data;
end;


{$R *.lfm}


initialization
  RegisterDaemon;

end.

