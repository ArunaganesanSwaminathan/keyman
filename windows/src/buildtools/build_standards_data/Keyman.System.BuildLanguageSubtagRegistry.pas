unit Keyman.System.BuildLanguageSubtagRegistry;

interface

uses
  System.Classes;

type
  TBuildLanguageSubtagRegistry = class
  private
    FSubtagRegistry: TStrings;
  public
    constructor Create(ASubtagRegistryFile: string);
    destructor Destroy; override;
    procedure BuildSuppressScriptRegistry(const DestinationFile: string);
    procedure BuildSubtagRegistry(const DestinationFile: string);
  end;

implementation

uses
  System.SysUtils;

{ TBuildLanguageSubtagRegistry }

procedure TBuildLanguageSubtagRegistry.BuildSubtagRegistry(
  const DestinationFile: string);
var
  FResult: TStringList;
  FLanguages, FScripts, FRegions: TStringList;

  procedure ParseList;
  var
    i, n: Integer;
    line: string;
    code: string;
    value: string;
    FType: string;
    FID: string;
    FDescription: string;
  begin
    FDescription := '';

    for i := 0 to FSubtagRegistry.Count-1 do
    begin
      line := Trim(FSubtagRegistry[i]);
      if line = '%%' then
      begin
        if Pos('..', FID) = 0 then
        begin
          if FType = 'language' then
            FLanguages.Add(FID + '=' + FDescription)
          else if FType = 'script' then
            FScripts.Add(FID + '=' + FDescription)
          else if FType = 'region' then
            FRegions.Add(FID + '=' + FDescription);
        end;
        FType := '';
        FDescription := '';
        Continue;
      end;

      n := Pos(':', line);
      if n = 0 then
        Continue;

      code := Copy(line, 1, n-1);
      value := Trim(Copy(line, n+1, MaxInt));

      if code = 'Type' then
        FType := value
      else if code = 'Subtag' then
        FID := value
      else if (code = 'Description') and (FDescription = '') then
        FDescription := value;
    end;
  end;

  function Escape(s: string): string;
  begin
    Result := s.Replace('''', '''''', [rfReplaceAll]);
  end;

  procedure AddDict(s: TStringList);
  var
    i: Integer;
  begin
    for i := 0 to s.Count - 1 do
      FResult.Add('  dict.Add('''+Escape(s.Names[i])+''', '''+Escape(s.ValueFromIndex[i])+''');');
  end;
begin
  FResult := TStringList.Create;
  FLanguages := TStringList.Create;
  FScripts := TStringList.Create;
  FRegions := TStringList.Create;
  try
    ParseList;
    FResult.Add('unit Keyman.System.Standards.BCP47SubtagRegistry;');
    FResult.Add('');
    FResult.Add('interface');
    FResult.Add('');
    FResult.Add('// File-Date: '+FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    FResult.Add('// Extracted from http://www.iana.org/assignments/language-subtag-registry/language-subtag-registry');
    FResult.Add('// Generated by build_standards_data');
    FResult.Add('');
    FResult.Add('uses');
    FResult.Add('  System.Generics.Collections;');
    FResult.Add('');
    FResult.Add('type');
    FResult.Add('  TBCP47SubtagRegistry = class');
    FResult.Add('  public');
    FResult.Add('    class procedure FillLanguages(dict: TDictionary<string,string>);');
    FResult.Add('    class procedure FillScripts(dict: TDictionary<string,string>);');
    FResult.Add('    class procedure FillRegions(dict: TDictionary<string,string>);');
    FResult.Add('  end;');
    FResult.Add('');
    FResult.Add('implementation');
    FResult.Add('');
    FResult.Add('');
    FResult.Add('{ TBCP47SubtagRegistry }');
    FResult.Add('');
    FResult.Add('class procedure TBCP47SubtagRegistry.FillLanguages(dict: TDictionary<string, string>);');
    FResult.Add('begin');
    AddDict(FLanguages);
    FResult.Add('end;');
    FResult.Add('');
    FResult.Add('class procedure TBCP47SubtagRegistry.FillScripts(dict: TDictionary<string, string>);');
    FResult.Add('begin');
    AddDict(FScripts);
    FResult.Add('end;');
    FResult.Add('');
    FResult.Add('class procedure TBCP47SubtagRegistry.FillRegions(dict: TDictionary<string, string>);');
    FResult.Add('begin');
    AddDict(FRegions);
    FResult.Add('end;');
    FResult.Add('');
    FResult.Add('end.');

    FResult.SaveToFile(DestinationFile, TEncoding.UTF8);
  finally
    FResult.Free;
    FLanguages.Free;
    FScripts.Free;
    FRegions.Free;
  end;
end;

procedure TBuildLanguageSubtagRegistry.BuildSuppressScriptRegistry(const DestinationFile: string);
var
  n: Integer;
  s: string;
  FLangCode: string;
  FirstLine: Boolean;
  FResult: TStringList;
begin
  FResult := TStringList.Create;
  try
    FResult.Add('unit Keyman.System.Standards.BCP47SuppressScriptRegistry;');
    FResult.Add('');
    FResult.Add('interface');
    FResult.Add('');
    FResult.Add('// File-Date: '+FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    FResult.Add('// Extracted from http://www.iana.org/assignments/language-subtag-registry/language-subtag-registry');
    FResult.Add('// Generated by build_standards_data');
    FResult.Add('');
    FResult.Add('const');
    FResult.Add('  SuppressScriptSubtagRegistry: string =');
    n := 0;
    FLangCode := '';
    FirstLine := True;
    while n < FSubtagRegistry.Count-1 do
    begin
      s := Trim(FSubtagRegistry[n]);
      if s = '%%' then
        FLangCode := '';
      if Copy(s,1,Length('Subtag:')) = 'Subtag:' then
        FlangCode := Trim(Copy(s,Length('Subtag:')+1,MaxInt));
      if Copy(s,1,Length('Suppress-Script:')) = 'Suppress-Script:' then
      begin
        if not FirstLine then
          FResult[FResult.Count-1] := FResult[FResult.Count-1] + '#13#10+';
        FirstLine := False;
        FResult.Add('    '''+FLangCode+'='+Trim(Copy(s,Length('Suppress-Script:')+1,MaxInt))+'''');
      end;
      Inc(n);
    end;
    FResult[FResult.Count-1] := FResult[FResult.Count-1] + ';';
    FResult.Add('');
    FResult.Add('implementation');
    FResult.Add('');
    FResult.Add('end.');

    FResult.SaveToFile(DestinationFile, TEncoding.UTF8);
  finally
    FResult.Free;
  end;
end;

constructor TBuildLanguageSubtagRegistry.Create(ASubtagRegistryFile: string);
begin
  FSubtagRegistry := TStringList.Create;
  FSubtagRegistry.LoadFromFile(ASubtagRegistryFile, TEncoding.UTF8);
  FSubtagRegistry.Add('%%');  // Force final entry to be processed
end;

destructor TBuildLanguageSubtagRegistry.Destroy;
begin
  inherited Destroy;
  FreeAndNil(FSubtagRegistry);
end;

end.
