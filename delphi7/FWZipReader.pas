////////////////////////////////////////////////////////////////////////////////
//
//  ****************************************************************************
//  * Project   : FWZip
//  * Unit Name : FWZipReader
//  * Purpose   : ����� ������� ��� ���������� ZIP ������
//  * Author    : ��������� (Rouse_) ������
//  * Copyright : � Fangorn Wizards Lab 1998 - 2025.
//  * Version   : 2.0.9
//  * Home Page : http://rouse.drkb.ru
//  * Home Blog : http://alexander-bagel.blogspot.ru
//  ****************************************************************************
//  * Stable Release : http://rouse.drkb.ru/components.php#fwzip
//  * Latest Source  : https://github.com/AlexanderBagel/FWZip
//  ****************************************************************************
//
//  ������������ ���������:
//  ftp://ftp.info-zip.org/pub/infozip/doc/appnote-iz-latest.zip
//  https://zlib.net/zlib-1.2.13.tar.gz
//  http://www.base2ti.com/
//

unit FWZipReader;

{$IFDEF FPC}
  {$MODE Delphi}
  {$H+}
{$ENDIF}

interface

{$I fwzip.inc}

uses
  SysUtils,
  Classes,
  Contnrs,
  Masks,
  DateUtils,
  FWZipConsts,
  FWZipCrc32,
  FWZipCrypt,
  FWZipStream,
  FWZipZLib,
  FWZipUtils;

type
  TFWZipReader = class;

  TExtractResult = (erError, erDone, erNeedPassword, erWrongCRC32, erSkiped);
  TPresentStream = (ssZIP64, ssNTFS);
  TPresentStreams = set of TPresentStream;

  TFWZipReaderItem = class
  private
    FOwner: TFWZipReader;
    FLocalFileHeader: TLocalFileHeader;
    FFileHeader: TCentralDirectoryFileHeaderEx;
    FIsFolder: Boolean;
    FOnProgress: TZipExtractItemEvent;
    FTotalExtracted, FExtractStreamStartSize: Int64;
    FExtractStream: TStream;
    FItemIndex, FTag: Integer;
    FDuplicate: TZipDuplicateEvent;
    FPresentStreams: TPresentStreams;
    function GetLastModDateTime: TDateTime;
    function GetString(const Index: Integer): string;
  protected
    procedure DoProgress(Sender: TObject; ProgressState: TProgressState);
    procedure DecompressorOnProcess(Sender: TObject);
    procedure LoadExData;
    procedure LoadStringValue(var Value: string; nSize: Cardinal;
      CheckEncoding: Boolean);
    procedure LoadLocalFileHeader;
    {%H-}constructor InitFromStream(Owner: TFWZipReader; Index: Integer);
  protected
    property LocalFileHeader: TLocalFileHeader read FLocalFileHeader;
    property CentralDirFileHeader: TCentralDirectoryFileHeader
      read FFileHeader.Header;
    property CentralDirFileHeaderEx: TCentralDirectoryFileHeaderEx read FFileHeader;
    property RelativeOffsetOfLocalHeader: Int64 read
      FFileHeader.RelativeOffsetOfLocalHeader;
    property DiskNumberStart: Integer read FFileHeader.DiskNumberStart;
  public
    function CreateDecompressionStream: TStream;
    function Extract(const Path, Password: string): TExtractResult; overload;
    function Extract(const Path, NewFileName, Password: string): TExtractResult; overload;
    function ExtractToStream(Value: TStream; const Password: string;
      CheckCRC32: Boolean = True): TExtractResult;
    property Attributes: TFileAttributeData read FFileHeader.Attributes;
    property Comment: string index 0 read GetString;
    property ItemIndex: Integer read FItemIndex;
    property IsFolder: Boolean read FIsFolder;
    property FileName: string index 1 read GetString;
    property VersionMadeBy: Word read FFileHeader.Header.VersionMadeBy;
    property VersionNeededToExtract: Word read
      FFileHeader.Header.VersionNeededToExtract;
    property CompressionMethod: Word read FFileHeader.Header.CompressionMethod;
    property LastModDateTime: TDateTime read GetLastModDateTime;
    property LastModFileTime: Word read FFileHeader.Header.LastModFileTimeTime;
    property LastModFileDate: Word read FFileHeader.Header.LastModFileTimeDate;
    property Crc32: Cardinal read FFileHeader.Header.Crc32;
    property CompressedSize: Int64 read FFileHeader.CompressedSize;
    property PresentStreams: TPresentStreams read FPresentStreams;
    property Tag: Integer read FTag write FTag;
    property UncompressedSize: Int64 read FFileHeader.UncompressedSize;
    property OnProgress: TZipExtractItemEvent
      read FOnProgress write FOnProgress;
    property OnDuplicate: TZipDuplicateEvent read FDuplicate write FDuplicate;
  end;

  TFWZipReader = class
  private
    FZIPStream, FFileStream: TStream;
    FLocalFiles: TObjectList;
    FZip64EOFCentralDirectoryRecord: TZip64EOFCentralDirectoryRecord;
    FZip64EOFCentralDirectoryLocator: TZip64EOFCentralDirectoryLocator;
    FEndOfCentralDir: TEndOfCentralDir;
    FEndOfCentralDirComment: AnsiString;
    FOnProgress: TZipProgressEvent;
    FOnNeedPwd: TZipNeedPasswordEvent;
    FTotalSizeCount, FTotalProcessedCount: Int64;
    FPasswordList: TStringList;
    FOnLoadExData: TZipLoadExDataEvent;
    FException: TZipExtractExceptionEvent;
    FDuplicate: TZipDuplicateEvent;
    FStartZipDataOffset, FEndZipDataOffset: Int64;
    FDefaultDuplicateAction: TDuplicateAction;
    function GetItem(Index: Integer): TFWZipReaderItem;
    procedure SetDefaultDuplicateAction(const Value: TDuplicateAction);
  protected
    property ZIPStream: TStream read FZIPStream;
    // Rouse_ 02.10.2012
    // ��������� ���� ��� �������� ��������� ������� ������ � ������ � �������
    property StartZipDataOffset: Int64 read FStartZipDataOffset;
    property EndZipDataOffset: Int64 read FEndZipDataOffset;
  protected
    function IsMultiPartZip: Boolean;
    function Zip64Present: Boolean;
    function SizeOfCentralDirectory: Int64;
    function TotalEntryesCount: Integer;
    procedure LoadStringValue(var Value: AnsiString; nSize: Cardinal);
    procedure LoadEndOfCentralDirectory;
    procedure LoadZIP64Locator;
    procedure LoadZip64EOFCentralDirectoryRecord;
    procedure LoadCentralDirectoryFileHeader;
    procedure ProcessExtractOrCheckAllData(const ExtractMask: string;
      Path: string; CheckMode: Boolean);
    procedure SetStreamPosition(DiskNumber: Integer; Offset: Int64);
  protected
    procedure DoProgress(Sender: TObject;
      const FileName: string; Extracted, TotalSize: Int64;
      ProgressState: TProgressState);
  protected
    property Zip64EOFCentralDirectoryRecord: TZip64EOFCentralDirectoryRecord
      read FZip64EOFCentralDirectoryRecord;
    property Zip64EOFCentralDirectoryLocator: TZip64EOFCentralDirectoryLocator
      read FZip64EOFCentralDirectoryLocator;
    property EndOfCentralDir: TEndOfCentralDir read FEndOfCentralDir;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;

    /// <summary>
    ///  ������� ���� ������ �� �������� �� �����
    /// </summary>
    function Find(const Value: string; out AItem: TFWZipReaderItem;
      IgnoreCase: Boolean = True): Boolean; overload;
    function Find(const Value: string; FromIndex: Integer;
      out AItem: TFWZipReaderItem; IgnoreCase: Boolean = True): Boolean; overload;

    /// <summary>
    ///  ������� ���� ������ �� �������� �� �����
    /// </summary>
    function FindByMask(const Value: string; FromIndex: Integer;
      out AItem: TFWZipReaderItem): Boolean; overload;

    function GetElementIndex(FileName: string): Integer;
    procedure LoadFromFile(const Value: string; SFXOffset: Integer = -1;
      ZipEndOffset: Integer = -1);
    procedure LoadFromStream(Value: TStream; SFXOffset: Integer = -1;
      ZipEndOffset: Integer = -1);
    procedure ExtractAll(const Path: string); overload;
    procedure ExtractAll(const ExtractMask: string; Path: string); overload;
    procedure Check(const ExtractMask: string = '');
    function Count: Integer;
    property DefaultDuplicateAction: TDuplicateAction
      read FDefaultDuplicateAction write SetDefaultDuplicateAction;
    property Item[Index: Integer]: TFWZipReaderItem read GetItem; default;
    property Comment: AnsiString read FEndOfCentralDirComment;
    property PasswordList: TStringList read FPasswordList;
    property OnProgress: TZipProgressEvent read FOnProgress write FOnProgress;
    property OnPassword: TZipNeedPasswordEvent
      read FOnNeedPwd write FOnNeedPwd;
    property OnLoadExData: TZipLoadExDataEvent
      read FOnLoadExData write FOnLoadExData;
    property OnException: TZipExtractExceptionEvent
      read FException write FException;
    property OnDuplicate: TZipDuplicateEvent read FDuplicate write FDuplicate;
  end;

  EWrongPasswordException = class(Exception);
  EZipReaderItem = class(Exception);
  EZipReader = class(Exception);
  EZipReaderRead = class(Exception);

implementation

{ TFWZipReaderItem }

//
//  ����� ��� ������ � ������� �����
// =============================================================================
function TFWZipReaderItem.CreateDecompressionStream: TStream;
var
  RealCompressedSize: Int64;
  ZipItemStream: TFWZipItemStream;
begin
  Result := nil;
  if IsFolder then Exit;

  if FFileHeader.DataOffset = 0 then
    LoadLocalFileHeader;

  // Rouse_ 16.10.2017
  // ���� ������������� �� ������������, ����� �������
  if FFileHeader.Header.GeneralPurposeBitFlag and PBF_CRYPTED <> 0 then
    raise EZipReaderItem.Create('CreateDecompressionStream �� �������������� ��� ������������� ����������');

  FOwner.FZIPStream.Position := FFileHeader.DataOffset;
  RealCompressedSize := FFileHeader.CompressedSize;

  case FFileHeader.Header.CompressionMethod of
    Z_NO_COMPRESSION:
      Result := TFWZipItemItemUnpackedStream.Create(FOwner.FZIPStream,
        FFileHeader.DataOffset, UncompressedSize);
    Z_DEFLATED:
    begin
      ZipItemStream := TFWZipItemStream.Create(FOwner.FZIPStream,
        nil, nil,
        FFileHeader.Header.GeneralPurposeBitFlag and 6,
        RealCompressedSize
        {$IFNDEF USE_AUTOGENERATED_ZLIB_HEADER}
        + 4
        {$ENDIF}
        );
      Result := TZDecompressionStream.Create(
        ZipItemStream, defaultWindowBits, True);
    end;
  end;
end;

//
//  ���������� OnProcess � ������������
// =============================================================================
procedure TFWZipReaderItem.DecompressorOnProcess(Sender: TObject);
begin
  DoProgress(Sender, psInProgress);
end;

//
//  ��������� �������� ������� ������� OnProcess
// =============================================================================
procedure TFWZipReaderItem.DoProgress(Sender: TObject;
  ProgressState: TProgressState);
begin
  if Assigned(FOnProgress) then
    if Sender = nil then
      FOnProgress(Self, FileName, FTotalExtracted,
        UncompressedSize, ProgressState)
    else
    begin
      FTotalExtracted := FExtractStream.Size - FExtractStreamStartSize;
      FOnProgress(Self, FileName, FTotalExtracted,
        UncompressedSize, ProgressState);
    end;
end;

//
//  ������� ������������� ������� ������� ����� � ��������� �����
// =============================================================================
function TFWZipReaderItem.Extract(const Path, Password: string): TExtractResult;
begin
  Result := Extract(Path, '', Password);
end;

//
//  ������� ������������� ������� ������� ����� � ��������� ����
// =============================================================================
function TFWZipReaderItem.Extract(
  const Path, NewFileName, Password: string): TExtractResult;
var
  UnpackedFile: TFileStream;
  FullPath: string;
  FileDate: Integer;
  DuplicateAction: TDuplicateAction;
  ResultFileName: string;
  Attributes: TFileAttributeData;
  NeedOverrideFile: Boolean;
begin
  Result := erDone;

  // ������ ������� � �������������� ����
  FullPath := PathCanonicalize(Path);
  if Path = '' then
    FullPath := GetCurrentDir;

  // Rouse_ 19.05.2021
  // ���� ����������� �������� ��� ���������������� ����� �� ����
  // ��������� ������� ������ ������ �� ����������� �������� ������ � ����������
  if NewFileName = '' then
    ResultFileName := FFileHeader.FileName
  else
    ResultFileName := NewFileName;

  FullPath := IncludeTrailingPathDelimiter(FullPath) + ResultFileName;
  {$IFDEF MSWINDOWS}
  FullPath := StringReplace(FullPath, ZIP_SLASH, '\', [rfReplaceAll]);
  {$ENDIF}

// BAD CODE
//  // Rouse_ 23.03.2015
//  // ���� ����������� �������� ��� ���������������� ����� �� ����
//  if NewFileName <> '' then
//    FullPath := ExtractFilePath(FullPath) + NewFileName;

  // Rouse_ 20.12.2019
  // ���� ����������� ������ � �������� ������

//  if Length(FullPath) > MAX_PATH then
//    raise EZipReaderItem.CreateFmt(
//      '������� ������ �%d "%s" �� ����� ���� ����������.' + sLineBreak +
//      '����� ����� ���� � ����� ����� �� ������ ��������� 260 ��������',
//      [ItemIndex, FFileHeader.FileName]);

  if IsFolder then
  begin
    ForceDirectoriesEx(FullPath);
    Exit;
  end;

  ForceDirectoriesEx(ExtractFilePath(FullPath));

  // �������� �� ������������� �����
  NeedOverrideFile := FileExists(FullPath);
  if NeedOverrideFile then
  begin

    // ���� ���� ��� ����������, ������ - ��� ���� ������ � ���� ;)
    DuplicateAction := FOwner.DefaultDuplicateAction;
    if Assigned(FDuplicate) then
      FDuplicate(Self, FullPath, DuplicateAction);

    case DuplicateAction of

      // ���������� ����
      daSkip:
      begin
        Result := erSkiped;
        Exit;
      end;

      // ������������
      daOverwrite:
        SetNormalFileAttributes(FullPath);

      daOverwriteOldest:
      begin
        if not GetFileAttributes(FullPath, Attributes)  then
        begin
          Result := erSkiped;
          Exit;
        end;

        if CompareDateTime(LastModDateTime,
          FileTimeToLocalDateTime(Attributes.ftLastWriteTime)) > 0  then
          SetNormalFileAttributes(FullPath)
        else
        begin
          Result := erSkiped;
          Exit;
        end;
      end;

      // ����������� � ������ ������
      daUseNewFilePath:
        // ���� ����������� ������ ����� ����� � �����,
        // �� � ������������� ���������� �� ������ ������������ ���
        if not DirectoryExists(ExtractFilePath(FullPath)) then
        begin
          Result := erSkiped;
          Exit;
        end;

      // �������� ����������
      daAbort:
        Abort;

    end;
  end;

  UnpackedFile := TFileStream.Create(FullPath, fmCreate);
  try
    Result := ExtractToStream(UnpackedFile, Password);
  finally
    UnpackedFile.Free;
  end;

  if Result <> erDone then
  begin
    if not NeedOverrideFile then
      DeleteFile(FullPath);
    Exit;
  end;

  if IsAttributesPresent(FFileHeader.Attributes) then
    SetFileAttributes(FullPath, FFileHeader.Attributes)
  else
  begin
    FileDate :=
      FFileHeader.Header.LastModFileTimeTime +
      FFileHeader.Header.LastModFileTimeDate shl 16;
    FileSetDate(FullPath, FileDate);
  end;
end;

//
//  ������� ������������� ������� ������� ����� � �����
// =============================================================================
function TFWZipReaderItem.ExtractToStream(Value: TStream;
  const Password: string; CheckCRC32: Boolean): TExtractResult;

  function CopyWithProgress(Src, Dst: TStream; Count: Int64;
    Decryptor: TFWZipDecryptor): Cardinal;
  var
    Buff: Pointer;
    Size: Integer;
  begin
    Result := $FFFFFFFF;
    try
      GetMem(Buff, MAXWORD);
      try
        Size := MAXWORD;
        DoProgress(nil, psInitialization);
        while Size = MAXWORD do
        begin
          if Count - FTotalExtracted < MAXWORD then
            Size := Count - FTotalExtracted;
          if Src.Read(Buff^, Size) <> Size then
            raise EZipReaderRead.CreateFmt(
              '������ ������ ������ �������� �%d "%s".', [ItemIndex, FileName]);
          if Decryptor <> nil then
            Decryptor.DecryptBuffer(Buff, Size);
          Result := CRC32Calc(Result, Buff, Size);
          Dst.WriteBuffer(Buff^, Size);
          Inc(FTotalExtracted, Size);
          DoProgress(nil, psInProgress);
        end;
        DoProgress(nil, psFinalization);
      finally
        FreeMem(Buff);
      end;
      Result := Result xor $FFFFFFFF;
    except
      DoProgress(nil, psException);
      raise;
    end;
  end;

  procedure RaiseStrongCrypt;
  begin
    raise EZipReaderItem.CreateFmt(
      '������ ���������� ������ �������� �%d "%s".' + sLineBreak +
      '�� �������������� ����� ����������',
      [ItemIndex, FileName]);
  end;

const
  CompressionMetods: array [0..12] of string = (
    'Store',
    'Shrunk',
    'Reduced1',
    'Reduced2',
    'Reduced3',
    'Reduced4',
    'Imploded',
    'Tokenizing compression algorithm',
    'Deflate',
    'Deflate64',
    'PKWARE Data Compression Library Imploding',
    'PKWARE',
    'BZIP2'
  );
var
  Decompressor: TZDecompressionStream;
  ZipItemStream: TFWZipItemStream;
  Decryptor: TFWZipDecryptor;
  RealCompressedSize: Int64;
  CurrItemCRC32: Cardinal;
  CRC32Stream: TFWZipCRC32Stream;
begin
  Result := erError;
  {$IFNDEF FPC}
    {$IF COMPILERVERSION < 32.0 }
    CurrItemCRC32 := 0; // Tokyo ����� ���������� �������, � ������� �� ������ ����������
    {$IFEND}
  {$ENDIF}
  FTotalExtracted := 0;
  Decryptor := nil;
  try
    if IsFolder then Exit;

    // ������ ��� ���������� ��������� ����� �� LocalFileHeader.
    // ��� ��������� ������� �� ������ ������ ���������� ����������
    // ������ ��������� ������� ����� � �������������� �����������.
    if FFileHeader.DataOffset = 0 then
      LoadLocalFileHeader;

    FOwner.ZIPStream.Position := FFileHeader.DataOffset;
    RealCompressedSize := FFileHeader.CompressedSize;

    // �������� ���������������� AES ������������ �����
    // ��������� ����� ����������
    if FFileHeader.Header.CompressionMethod = Z_AES_COMPRESSION then
      RaiseStrongCrypt;

    // ���� ���� ����������, ���������� ���������������� ���� ��� ����������
    if FFileHeader.Header.GeneralPurposeBitFlag and PBF_CRYPTED <> 0 then
    begin

      if FFileHeader.Header.GeneralPurposeBitFlag and
        PBF_STRONG_CRYPT <> 0 then
        RaiseStrongCrypt;

      if Password = '' then
      begin
        // ������ �� ����� ���� ������
        Result := erNeedPassword;
        Exit;
      end;
      Decryptor := TFWZipDecryptor.Create(AnsiString(Password));
      if not Decryptor.LoadEncryptionHeader(FOwner.FZIPStream,
        FFileHeader.Header.GeneralPurposeBitFlag and PBF_DESCRIPTOR <> 0,
        FFileHeader.Header.Crc32,
        FFileHeader.Header.LastModFileTimeTime +
        FFileHeader.Header.LastModFileTimeDate shl 16) then
      begin
        // ����� ������������� �����
        Result := erNeedPassword;
        Exit;
      end
      else
        // ���� ���� ��������������� ������� - �������� �� ������� �������
        // ������ ��������� ������������� �����
        Dec(RealCompressedSize, EncryptedHeaderSize);
    end;

    case FFileHeader.Header.CompressionMethod of
      Z_NO_COMPRESSION:
      begin
        CurrItemCRC32 :=
          CopyWithProgress(FOwner.FZIPStream, Value,
            UncompressedSize, Decryptor);
        // Rouse_ 11.03.2011
        // � ��������� ��������� �� � ������.
        // C������ ������� �� ����������� ������
        Result := erDone;
      end;
      Z_DEFLATED:
      begin

        // TFWZipItemStream ��������� ��� ��������� ����� FOwner.FZIPStream
        // � TDecompressionStream. ��� ������ �������� � ������������
        // ������ ������ ������������� ZLib ��������� � ������������
        // ������ ��� �������������
        ZipItemStream := TFWZipItemStream.Create(FOwner.FZIPStream,
          nil, Decryptor,
          FFileHeader.Header.GeneralPurposeBitFlag and 6,
          RealCompressedSize
          {$IFNDEF USE_AUTOGENERATED_ZLIB_HEADER}
          + 4 // ������, �� ��� ����� �� ������������,
              // �� ����� ��� ���������� ZInflate ��� ������������� windowBits
              // �������� ��� ������� ������������ 7Zip
          {$ENDIF}
          );
        try
          Decompressor := TZDecompressionStream.Create(
            ZipItemStream, defaultWindowBits);
          try
            Decompressor.OnProgress := DecompressorOnProcess;
            FExtractStreamStartSize := Value.Size;
            FExtractStream := Value;
            // TFWZipCRC32Stream ��������� ��� ��������� �����
            // TDecompressionStream � �������������� �������,
            // � ������� ���������� ���������� ������.
            // ��� ������ ��������� ��� ������������� ����� ������
            // � ���������� �� ����������� �����
            DoProgress(Decompressor, psInitialization);
            CRC32Stream := TFWZipCRC32Stream.Create(Value);
            try
              try
                // Rouse_ 16.06.2022
                // ���� ������ � �������� ������ VCL �� ������� "����� 1"
                if UncompressedSize > 0 then
                  CRC32Stream.CopyFrom(Decompressor, UncompressedSize);
              except
                // EOutOfMemory ������ ��� ����
                on E: EOutOfMemory do
                  raise;

                on E: EReadError do
                  raise EZipReaderRead.CreateFmt(
                    '������ ������ ������ �������� �%d "%s".', [ItemIndex, FileName]);

                // Rouse_ 04.04.2010
                // ����� ��� ����������� ���� EDecompressionError
                // ������� ���������� � �������� ���������� EZLibError
                // on E: EZDecompressionError do
                on E: EZLibError do
                begin
                  if FFileHeader.Header.GeneralPurposeBitFlag and
                    PBF_CRYPTED <> 0 then
                  begin
                    // ������ ����� ��������� ��-�� ���� ��� �������������
                    // ��������������� ������ �������, �� ������ ��� ������ �� ������
                    // ����� ����� ���������, �.�. ���������� ��������
                    // ��� �������� ��������� ����� ������
                    Result := erNeedPassword;
                    Exit;
                  end
                  else
                    DoProgress(Decompressor, psException);
                  raise EZipReaderRead.CreateFmt(string(
                    '������ ���������� ������ �������� �%d "%s".' + sLineBreak) +
                    ExceptionMessage(E), [ItemIndex, FileName]);
                end;

                // Rouse_ 01.11.2013
                // ��� ��������� ���������� ���� ����� �������� � ����� ��������� ���� ������������.
                on E: Exception do
                  raise EZipReaderRead.CreateFmt(string(
                    '������ ���������� ������ �������� �%d "%s".' + sLineBreak) +
                    ExceptionMessage(E), [ItemIndex, FileName]);

              end;
              CurrItemCRC32 := CRC32Stream.CRC32;
            finally
              CRC32Stream.Free;
            end;
            DoProgress(Decompressor, psFinalization);
            Result := erDone;
          finally
            Decompressor.Free;
          end;
        finally
          ZipItemStream.Free;
        end;
      end;
      1..7, 9..12:
        raise EZipReaderItem.CreateFmt(
          '������ ���������� ������ �������� �%d "%s".' + sLineBreak +
          '�� �������������� �������� ������������ "%s"',
          [ItemIndex, FileName, CompressionMetods[CompressionMethod]]);
    else
      raise EZipReaderItem.CreateFmt(
        '������ ���������� ������ �������� �%d "%s".' + sLineBreak +
        '�� �������������� �������� ������������ (%d)',
        [ItemIndex, FileName, FFileHeader.Header.CompressionMethod]);
    end;
    if CurrItemCRC32 <> Crc32 then
      if CheckCRC32 then
        raise EZipReaderItem.CreateFmt(
          '������ ���������� ������ �������� �%d "%s".' + sLineBreak +
          '�������� ����������� �����.',
          [ItemIndex, FileName])
      else
        Result := erWrongCRC32;
  finally
    Decryptor.Free;
  end;
end;

//
// =============================================================================
function TFWZipReaderItem.GetLastModDateTime: TDateTime;
begin
{$IFDEF FPC}
  Result := ComposeDateTime(
    EncodeDate(
      (LastModFileDate shr 9) + 1980,
      (LastModFileDate shr 5) and 15,
      (LastModFileDate and 31)),
    EncodeTime(
      (LastModFileTime shr 11),
      (LastModFileTime shr 5) and 63,
      (LastModFileTime and 31) shl 1,0));
{$ELSE}
  Result := FileDateToDateTime(LastModFileTime + LastModFileDate shl 16);
{$ENDIF}
end;

//
// =============================================================================
function TFWZipReaderItem.GetString(const Index: Integer): string;
begin
  case Index of
    0: Result := FFileHeader.FileComment;
    1: Result := FFileHeader.FileName;
  end;
end;

//
//  ����������� �������� ������.
//  ������������� ������ ���������� �� ������ ������ �� ������
// =============================================================================
constructor TFWZipReaderItem.InitFromStream(Owner: TFWZipReader; Index: Integer);
var
  Len: Integer;
begin
  inherited Create;

  FOwner := Owner;
  FItemIndex := Index;
  ZeroMemory(@FFileHeader, SizeOf(TCentralDirectoryFileHeaderEx));

  if Owner.ZIPStream.Read(FFileHeader.Header,
    SizeOf(TCentralDirectoryFileHeader)) <> SizeOf(TCentralDirectoryFileHeader) then
    raise EZipReaderRead.CreateFmt(
      '����������� ������ TCentralDirectoryFileHeader �������� �%d', [ItemIndex]);

  if FFileHeader.Header.CentralFileHeaderSignature <>
    CENTRAL_FILE_HEADER_SIGNATURE then
    raise EZipReaderItem.CreateFmt(
      '������ ������ ��������� TCentralDirectoryFileHeader �������� �%d', [ItemIndex]);

  LoadStringValue(FFileHeader.FileName, FFileHeader.Header.FilenameLength, True);

  FIsFolder := FFileHeader.Header.ExternalFileAttributes and faDirectory <> 0;

  // Rouse_ 31.08.2015
  // ���� ���������� UTF8 �� FilenameLength ��� ������ � ������ � �� � ��������
  // ������� ������ �����:
  //if FFileHeader.Header.FilenameLength > 0 then
  //  FIsFolder := FIsFolder or
  //    (FFileHeader.FileName[FFileHeader.Header.FilenameLength] = ZIP_SLASH);
  // ����� ��� ���:
  Len := Length(FFileHeader.FileName);
  if Len > 0 then
    FIsFolder := FIsFolder or
      (FFileHeader.FileName[Len] = ZIP_SLASH);

  // ��������� 4 ��������� ����� ���� ���������� � -1 ��-�� ������������
  // � �� �������� �������� ����� ����������� � ����� ����������� ������.
  // ���������� �� ������� ��������.
  // � ������ ���� �����-���� �� ���������� ��������� � -1,
  // ��� �������� ���������� ��� ������ ��������� LoadExData.
  FFileHeader.UncompressedSize := FFileHeader.Header.UncompressedSize;
  FFileHeader.CompressedSize := FFileHeader.Header.CompressedSize;
  FFileHeader.RelativeOffsetOfLocalHeader :=
    FFileHeader.Header.RelativeOffsetOfLocalHeader;
  FFileHeader.DiskNumberStart := FFileHeader.Header.DiskNumberStart;

  LoadExData;

  LoadStringValue(FFileHeader.FileComment,
    FFileHeader.Header.FileCommentLength, False);

  // ����� ���������� ����������� � ����������� ���������
  // ���������� �� ���������
  FFileHeader.Attributes.dwFileAttributes :=
    FFileHeader.Header.ExternalFileAttributes;
  FFileHeader.Attributes.nFileSizeHigh :=
    Cardinal(FFileHeader.UncompressedSize shr 32);
  FFileHeader.Attributes.nFileSizeLow :=
    FFileHeader.UncompressedSize and MAXDWORD;
end;

//
//  ��������� ���������� �������������� ������ � ��������
// =============================================================================
procedure TFWZipReaderItem.LoadExData;
var
  Buff, EOFBuff: Pointer;
  BuffCount: Integer;
  HeaderID, BlockSize: Word;

  function GetOffset(Value: Integer): Pointer;
  begin
    Result := UIntToPtr(PtrToUInt(EOFBuff) - NativeUInt(Value));
  end;

var
  ExDataStream: TMemoryStream;
begin
  if FFileHeader.Header.ExtraFieldLength = 0 then Exit;
  GetMem(Buff, FFileHeader.Header.ExtraFieldLength);
  try
    BuffCount := FFileHeader.Header.ExtraFieldLength;

    if FOwner.ZIPStream.Read(Buff^, BuffCount) <> BuffCount then
      raise EZipReaderRead.CreateFmt(
        '����������� ������ ���� ExtraField �������� �%d "%s"', [ItemIndex, FileName]);

    EOFBuff := UIntToPtr(PtrToUInt(Buff) + NativeUInt(BuffCount));
    while BuffCount > 0 do
    begin
      HeaderID := PWord(GetOffset(BuffCount))^;
      Dec(BuffCount, 2);
      BlockSize := PWord(GetOffset(BuffCount))^;
      Dec(BuffCount, 2);
      case HeaderID of
        SUPPORTED_EXDATA_ZIP64:
        begin

          {
         -ZIP64 Extended Information Extra Field (0x0001):
          ===============================================

          The following is the layout of the ZIP64 extended
          information "extra" block. If one of the size or
          offset fields in the Local or Central directory
          record is too small to hold the required data,
          a ZIP64 extended information record is created.
          The order of the fields in the ZIP64 extended
          information record is fixed, but the fields will
          only appear if the corresponding Local or Central
          directory record field is set to 0xFFFF or 0xFFFFFFFF.

          Note: all fields stored in Intel low-byte/high-byte order.

          Value      Size       Description
          -----      ----       -----------
  (ZIP64) 0x0001     2 bytes    Tag for this "extra" block type
          Size       2 bytes    Size of this "extra" block
          Original
          Size       8 bytes    Original uncompressed file size
          Compressed
          Size       8 bytes    Size of compressed data
          Relative Header
          Offset     8 bytes    Offset of local header record
          Disk Start
          Number     4 bytes    Number of the disk on which
                                this file starts

          This entry in the Local header must include BOTH original
          and compressed file sizes.
          }

          if FFileHeader.UncompressedSize = MAXDWORD then
          begin
            if BuffCount < 8 then Break;
            FFileHeader.UncompressedSize := PInt64(GetOffset(BuffCount))^;
            Dec(BuffCount, 8);
            Dec(BlockSize, 8);
          end;
          if FFileHeader.CompressedSize = MAXDWORD then
          begin
            if BuffCount < 8 then Break;
            FFileHeader.CompressedSize := PInt64(GetOffset(BuffCount))^;
            Dec(BuffCount, 8);
            Dec(BlockSize, 8);
          end;
          if FFileHeader.RelativeOffsetOfLocalHeader = MAXDWORD then
          begin
            if BuffCount < 8 then Break;
            FFileHeader.RelativeOffsetOfLocalHeader := PInt64(GetOffset(BuffCount))^;
            Dec(BuffCount, 8);
            Dec(BlockSize, 8);
          end;
          if FFileHeader.DiskNumberStart = MAXWORD then
          begin
            if BuffCount < 4 then Break;
            FFileHeader.DiskNumberStart := PCardinal(GetOffset(BuffCount))^;
            Dec(BuffCount, 4);
            Dec(BlockSize, 4);
          end;
          Dec(BuffCount, BlockSize);
          Include(FPresentStreams, ssZIP64);
        end;

        SUPPORTED_EXDATA_NTFSTIME:
        begin

          {
         -PKWARE Win95/WinNT Extra Field (0x000a):
          =======================================

          The following description covers PKWARE's "NTFS" attributes
          "extra" block, introduced with the release of PKZIP 2.50 for
          Windows. (Last Revision 20001118)

          (Note: At this time the Mtime, Atime and Ctime values may
          be used on any WIN32 system.)
         [Info-ZIP note: In the current implementations, this field has
          a fixed total data size of 32 bytes and is only stored as local
          extra field.]

          Value         Size        Description
          -----         ----        -----------
  (NTFS)  0x000a        Short       Tag for this "extra" block type
          TSize         Short       Total Data Size for this block
          Reserved      Long        for future use
          Tag1          Short       NTFS attribute tag value #1
          Size1         Short       Size of attribute #1, in bytes
          (var.)        SubSize1    Attribute #1 data
          .
          .
          .
          TagN          Short       NTFS attribute tag value #N
          SizeN         Short       Size of attribute #N, in bytes
          (var.)        SubSizeN    Attribute #N data

          For NTFS, values for Tag1 through TagN are as follows:
          (currently only one set of attributes is defined for NTFS)

          Tag        Size       Description
          -----      ----       -----------
          0x0001     2 bytes    Tag for attribute #1
          Size1      2 bytes    Size of attribute #1, in bytes (24)
          Mtime      8 bytes    64-bit NTFS file last modification time
          Atime      8 bytes    64-bit NTFS file last access time
          Ctime      8 bytes    64-bit NTFS file creation time

          The total length for this block is 28 bytes, resulting in a
          fixed size value of 32 for the TSize field of the NTFS block.

          The NTFS filetimes are 64-bit unsigned integers, stored in Intel
          (least significant byte first) byte order. They determine the
          number of 1.0E-07 seconds (1/10th microseconds!) past WinNT "epoch",
          which is "01-Jan-1601 00:00:00 UTC".
          }

          // ��������� ����������� ���� � ������ ����������:
          // this field has a fixed total data size of 32 bytes

          // ���� ������ ������� ������ 32 ���� - �� ������� �� ���������
          if BuffCount < 32 then Break;

          // ���� �� �� �� ����� 32 ������,
          // �� ������ ���������� ��� � �������� � ��������� ������
          if BlockSize <> 32 then
          begin
            Dec(BuffCount, BlockSize);
            Continue;
          end;

          // ���������� ���� Reserved
          Dec(BuffCount, 4);

          // ��������� ���� Tag
          if PWord(GetOffset(BuffCount))^ <> 1 then
          begin
            Dec(BuffCount, BlockSize);
            Continue;
          end;
          Dec(BuffCount, 2);

          // ��������� ������ ����� ������
          if PWord(GetOffset(BuffCount))^ <> SizeOf(TNTFSFileTime) then
          begin
            Dec(BuffCount, BlockSize);
            Continue;
          end;
          Dec(BuffCount, 2);

          // ������ ���� ������
          FFileHeader.Attributes.ftLastWriteTime := PFileTime(GetOffset(BuffCount))^;
          Dec(BuffCount, SizeOf(TFileTime));
          FFileHeader.Attributes.ftLastAccessTime := PFileTime(GetOffset(BuffCount))^;
          Dec(BuffCount, SizeOf(TFileTime));
          FFileHeader.Attributes.ftCreationTime := PFileTime(GetOffset(BuffCount))^;
          Dec(BuffCount, SizeOf(TFileTime));
          Include(FPresentStreams, ssNTFS);
       end;
      else
        if Assigned(FOwner.OnLoadExData) then
        begin
          ExDataStream := TMemoryStream.Create;
          try
            ExDataStream.WriteBuffer(GetOffset(BuffCount)^, BlockSize);
            ExDataStream.Position := 0;
            FOwner.OnLoadExData(Self, FItemIndex, HeaderID, ExDataStream);
          finally
            ExDataStream.Free;
          end;
        end;
        Dec(BuffCount, BlockSize);
      end;
    end;
  finally
    FreeMem(Buff);
  end;
end;

//
//  ��������� ���������� � ��������� ���������� ��������� LocalFileHeader
//  ������ ��������� �������� ���������� �������� ������� �� ������
//  ������������� ����� ������.
// =============================================================================
procedure TFWZipReaderItem.LoadLocalFileHeader;
begin
  // Rouse_ 02.10.2012
  // ��� ������ ��������� ������ �� ������ ������ StartZipDataOffset
  FOwner.SetStreamPosition(FFileHeader.DiskNumberStart,
    FFileHeader.RelativeOffsetOfLocalHeader + FOwner.StartZipDataOffset);

  if FOwner.ZIPStream.Read(FLocalFileHeader,
    SizeOf(TLocalFileHeader)) <> SizeOf(TLocalFileHeader) then
    raise EZipReaderRead.CreateFmt(
      '������������ ������ TLocalFileHeader �������� �%d "%s"', [ItemIndex, FileName]);

  if FLocalFileHeader.LocalFileHeaderSignature <>
    LOCAL_FILE_HEADER_SIGNATURE then
    raise EZipReaderItem.CreateFmt(
      '������ ������ TLocalFileHeader �������� �%d "%s"', [ItemIndex, FileName]);

  FFileHeader.DataOffset := FOwner.ZIPStream.Position +
    FLocalFileHeader.FilenameLength + FLocalFileHeader.ExtraFieldLength;
end;

//
//  ��������� ���������� ��������� �������� � ��������� ��� � Ansi ������
// =============================================================================
procedure TFWZipReaderItem.LoadStringValue(var Value: string;
  nSize: Cardinal; CheckEncoding: Boolean);
var
  aString: AnsiString;
begin
  if Integer(nSize) > 0 then
  begin
    {$IFDEF FPC}
    aString := '';
    {$ENDIF}
    SetLength(aString, nSize);

    if FOwner.ZIPStream.Read(aString[1], nSize) <> Integer(nSize) then
      raise EZipReaderRead.CreateFmt(
        '������ ������ ��������� ������ �������� �%d "%s"', [ItemIndex, FileName]);

    // Rouse_ 13.06.2013
    // 11 ��� �������� �� UTF8 ���������
    if FFileHeader.Header.GeneralPurposeBitFlag and PBF_UTF8 = PBF_UTF8 then
    begin
      {$IFDEF UNICODE}
      Value := string(UTF8ToUnicodeString(aString))
      {$ELSE}
      Value := string(UTF8Decode(aString));
      // � ����������� ������� Delphi ��������� ������� ����� ������������� � ����� �������
      if CheckEncoding then
        Value := StringReplace(Value, '?', '_', [rfReplaceAll]);
      {$ENDIF}
    end
    else
      Value := string(ConvertFromOemString(aString));
  end;
end;

{ TFWZipReader }

//
//  ��������� ���������� �������� ������ � ������ ����� ����� � ������
//  ������ ���������������, �� �� �����������
// =============================================================================
procedure TFWZipReader.Check(const ExtractMask: string);
begin
  ProcessExtractOrCheckAllData(ExtractMask, '', True);
end;

//
//  ��������� ������� ������ � �������� ����� ������
// =============================================================================
procedure TFWZipReader.Clear;
begin
  ZeroMemory(@FZip64EOFCentralDirectoryRecord,
    SizeOf(TZip64EOFCentralDirectoryRecord));
  ZeroMemory(@FZip64EOFCentralDirectoryLocator,
    SizeOf(TZip64EOFCentralDirectoryLocator));
  ZeroMemory(@FEndOfCentralDir, SizeOf(TEndOfCentralDir));
  FLocalFiles.Clear;
  FreeAndNil(FFileStream);
end;

//
//  ������� ���������� ���������� ��������� ��������� ������
// =============================================================================
function TFWZipReader.Count: Integer;
begin
  Result := FLocalFiles.Count;
end;

// =============================================================================
constructor TFWZipReader.Create;
begin
  inherited;
  FLocalFiles := TObjectList.Create;
  FPasswordList := TStringList.Create;
  FPasswordList.Duplicates := dupIgnore;
  FPasswordList.Sorted := True;
  DefaultDuplicateAction := daSkip;
end;

// =============================================================================
destructor TFWZipReader.Destroy;
begin
  FPasswordList.Free;
  FLocalFiles.Free;
  FFileStream.Free;
  inherited;
end;

//
//  ��������� �������� ���������� OnProgress
// =============================================================================
procedure TFWZipReader.DoProgress(Sender: TObject; const FileName: string;
  Extracted, TotalSize: Int64; ProgressState: TProgressState);
var
  Percent, TotalPercent: Byte;
  Cancel: Boolean;
begin
  if Assigned(FOnProgress) then
  begin
    if TotalSize = 0 then
      if ProgressState in [psStart, psInitialization] then
        Percent := 0
      else
        Percent := 100
    else
      if ProgressState = psEnd then
        Percent := 100
      else
        Percent := Round(Extracted / (TotalSize / 100));
    if FTotalSizeCount = 0 then
      TotalPercent := 100
    else
      TotalPercent :=
        Round((FTotalProcessedCount + Extracted) / (FTotalSizeCount / 100));
    Cancel := False;
    FOnProgress(Self, FileName, Percent, TotalPercent, Cancel, ProgressState);
    if Cancel then Abort;
  end;
end;

//
//  ��������� ���������� �������������� ���������� ������ � ��������� �����
//  � ������ ����� ����� � ������
// =============================================================================
procedure TFWZipReader.ExtractAll(const ExtractMask: string; Path: string);
begin
  ProcessExtractOrCheckAllData(ExtractMask, Path, False);
end;

//
//  ������� ���� ������� ������ �� ����� ������� � ������������� �������
// =============================================================================
function TFWZipReader.Find(const Value: string; FromIndex: Integer;
  out AItem: TFWZipReaderItem; IgnoreCase: Boolean): Boolean;
var
  I: Integer;
  AItemText: string;
begin
  Result := False;
  AItem := nil;
  for I := FromIndex to Count - 1 do
  begin
    AItemText := Item[I].FileName;
    if IgnoreCase then
      Result := AnsiSameText(Value, AItemText)
    else
      Result := AnsiSameStr(Value, AItemText);
    if Result then
    begin
      AItem := Item[I];
      Break;
    end;
  end;
end;

//
//  ������� ���� ������� ������ �� ����� �� ������� ���������
// =============================================================================
function TFWZipReader.Find(const Value: string; out AItem: TFWZipReaderItem;
  IgnoreCase: Boolean): Boolean;
begin
  Result := Find(Value, 0, AItem, IgnoreCase);
end;

//
//  ������� ���� ������� ������ �� ����� ������� � ������������� �������
// =============================================================================
function TFWZipReader.FindByMask(const Value: string; FromIndex: Integer;
  out AItem: TFWZipReaderItem): Boolean;
var
  I: Integer;
begin
  Result := False;
  AItem := nil;
  for I := FromIndex to Count - 1 do
  begin
    Result := MatchesMask(Item[I].FileName, Value);
    if Result then
    begin
      AItem := Item[I];
      Break;
    end;
  end;
end;

//
//  ��������� ���������� �������������� ���������� ������ � ��������� �����
// =============================================================================
procedure TFWZipReader.ExtractAll(const Path: string);
begin
  ExtractAll('', Path);
end;

//
//  ������� ���������� ������ �������� �� ��� �����
// =============================================================================
function TFWZipReader.GetElementIndex(FileName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  FileName := StringReplace(FileName, '\', ZIP_SLASH, [rfReplaceAll]);
  for I := 0 to Count - 1 do
    if {%H-}AnsiCompareText(Item[I].FileName, FileName) = 0 then
    begin
      Result := I;
      Break;
    end;
end;

//
//  ������� ���������� ������� ������ �� ��� �������
// =============================================================================
function TFWZipReader.GetItem(Index: Integer): TFWZipReaderItem;
begin
  Result := TFWZipReaderItem(FLocalFiles[Index]);
end;

//
//  ������� ��� ������������ ������ ������ � ������������ ��������
// =============================================================================
function TFWZipReader.IsMultiPartZip: Boolean;
begin
  Result := FZIPStream is TFWAbstractMultiStream;
end;

//
//  ��������� ���������� ����������� ���������� ������
// =============================================================================
procedure TFWZipReader.LoadCentralDirectoryFileHeader;
var
  EndOfLoadCentralDirectory: Int64;
begin
  EndOfLoadCentralDirectory := FZIPStream.Position + SizeOfCentralDirectory;
  while FZIPStream.Position < EndOfLoadCentralDirectory do
    FLocalFiles.Add(TFWZipReaderItem.InitFromStream(Self, Count));

  // Rouse_ 01.11.2013
  // ���������� ����� ��������� ������ � ������ ���� ���������� ���-�� ���������
  // ������ ��� ������� ���������.
  // ��� ������� ��� ���� ����� � ������� ���-�� ��������� 95188,
  // (���������� �� ���������� ��������� � ����� ������������ ZIP64),
  // �� ZIP64 �� ������������� � ���� TotalNumberOfEntries ������� �������� 29652
  // ���������� ��� � ��������� 95188 - $10000

  // ������� ������ ������ �������:
  //if Count <> TotalEntryesCount then
  //����� ��� ���:
  if Count < TotalEntryesCount then

    raise EZipReader.CreateFmt(
      '������ ������ ����������� ����������. ' + sLineBreak +
      '����������� ���������� ��������� (%d) �� ������������� ����������� (%d).',
      [Count, TotalEntryesCount]);
end;

//
//  ��������� �������� ���������� ��������� EndOfCentralDirectory
//  ������ ��������� �������� ������ �� ������ CentralDirectory
// =============================================================================
procedure TFWZipReader.LoadEndOfCentralDirectory;
var
  Zip64LocatorOffset: Int64;
begin
  // �������� ������������ � ������ ������� 64-������ ��������
  // TZip64EOFCentralDirectoryLocator ���� ����� ����� EndOfCentralDirectory.
  // ���������� ������ �� �������������� ������� ������ ���������.
  Zip64LocatorOffset := FZIPStream.Position -
    SizeOf(TZip64EOFCentralDirectoryLocator);

  if FZIPStream.Read(FEndOfCentralDir, SizeOf(TEndOfCentralDir)) <>
    SizeOf(TEndOfCentralDir) then
    raise EZipReader.Create('����������� ������ ��������� TEndOfCentralDir.');

  if (FEndOfCentralDir.NumberOfThisDisk <> 0) and not IsMultiPartZip then
    raise EZipReader.Create('�������� ����������� ������� ������ ������������ ����� TFWAbstractMultiStream.');

  if FEndOfCentralDir.EndOfCentralDirSignature <>
    END_OF_CENTRAL_DIR_SIGNATURE then
    raise EZipReader.Create('������ ������ ��������� TEndOfCentralDir.');

  LoadStringValue(FEndOfCentralDirComment,
    FEndOfCentralDir.ZipfileCommentLength);

  {
      6)  If one of the fields in the end of central directory
          record is too small to hold required data, the field
          should be set to -1 (0xFFFF or 0xFFFFFFFF) and the
          Zip64 format record should be created.
  }

  if (FEndOfCentralDir.NumberOfThisDisk = MAXWORD) or
    (FEndOfCentralDir.DiskNumberStart = MAXWORD) or
    (FEndOfCentralDir.TotalNumberOfEntriesOnThisDisk = MAXWORD) or
    (FEndOfCentralDir.TotalNumberOfEntries = MAXWORD) or
    (FEndOfCentralDir.SizeOfTheCentralDirectory = MAXDWORD) or
    (FEndOfCentralDir.RelativeOffsetOfCentralDirectory = MAXDWORD) then
  begin
    // ���� �� ������� �� �������� �������� ������
    // �������� ������������ �� ���������� �������� ����� Zip64Locator
    FZIPStream.Position := Zip64LocatorOffset + StartZipDataOffset;
    LoadZIP64Locator;
  end
  else
    // Rouse_ 02.10.2012
    // ��� ������ ��������� ������ �� ������ ������ StartZipDataOffset
    SetStreamPosition(FEndOfCentralDir.DiskNumberStart,
      FEndOfCentralDir.RelativeOffsetOfCentralDirectory + StartZipDataOffset);
end;

//
//  ��������� ��������� ����� �� ���������� ����
// =============================================================================
procedure TFWZipReader.LoadFromFile(const Value: string;
  SFXOffset, ZipEndOffset: Integer);
begin
  // Rouse_ 20.02.2012
  // ���� TFileStream �� �������� FFileStream ����� ��������� ��� �� ����������� TFileStream,
  // ��������� ��� ���������� ������ LoadFromFile,
  // ��� �������� � ������ � ����������� ��� ���������� FFileStream
  // ������� v1ctar �� �������� ����
  //FFileStream.Free;
  FreeAndNil(FFileStream);
  FFileStream := TFileStream.Create(PathCanonicalize(Value), fmOpenRead or fmShareDenyWrite);
  LoadFromStream(FFileStream, SFXOffset, ZipEndOffset);
end;

//
//  ��������� ��������� ����� �� ����������� ������
// =============================================================================
procedure TFWZipReader.LoadFromStream(Value: TStream;
  SFXOffset, ZipEndOffset: Integer);
var
  Buff: Pointer;
  I, BuffSize, SignOffset: Integer;
  Offset, EndOfCentralDirectoryOffset: Int64;
  Cursor: PByte;
begin
  FLocalFiles.Clear;
  FZIPStream := Value;

  // Rouse_ 02.10.2012
  // ������ ����� ����������� ������� �� ������������ ������ � ������ � �������
  // SFXOffset ��������� �� ������ ������
  // ZipEndOffset ��������� �� ������� ����� ������� �� ������������ �����
  // ��������� EndOfCentralDir

  // �� ���� ���������� �� �������������� ��� MultyPart �������
  if IsMultiPartZip then
  begin
    SFXOffset := -1;
    ZipEndOffset := -1;
  end;

  if SFXOffset < 0 then
    FStartZipDataOffset := 0
  else
    FStartZipDataOffset := SFXOffset;

  if ZipEndOffset < 0 then
    FEndZipDataOffset := Value.Size
  else
    FEndZipDataOffset := ZipEndOffset;

  // ���� ��������� EndOfCentralDir
  BuffSize := $FFFF;

  // Rouse_ 13.03.2015
  // ���� ����� ������, �� END_OF_CENTRAL_DIR_SIGNATURE ����� �������������
  // �� �������� �������, ����� ���� ���� - ��� ���� ���������� ��������
  // ������� ���� ���������� ������� ������� ����� �� ����, � ������������� ��������
  EndOfCentralDirectoryOffset := -1;
  //EndOfCentralDirectoryOffset := 0;

  Offset := EndZipDataOffset;
  SignOffset := 0;
  GetMem(Buff, BuffSize);
  try
    while Offset > StartZipDataOffset do
    begin
      {%H-}Dec(Offset, BuffSize - SignOffset);
      if Offset < StartZipDataOffset then
      begin
        Inc(BuffSize, Offset - StartZipDataOffset);
        Offset := StartZipDataOffset;
      end;
      Value.Position := Offset;

      if Value.Read(Buff^, BuffSize) <> BuffSize then
        raise EZipReaderRead.Create('������ ������ ������ ��� ������ END_OF_CENTRAL_DIR_SIGNATURE');

      // Rouse_ 14.02.2013
      // ���� � ������ ����� ������������� ZIP �����,
      // �� ���� ������� ���� ��� ������ END_OF_CENTRAL_DIR_SIGNATURE ��
      // ��������� � ����, � �� � ������ ������

      {
      Cursor := Buff;
      for I := 0 to BuffSize - 1 do
      begin
        if PCardinal(Cursor)^ = END_OF_CENTRAL_DIR_SIGNATURE then
        begin
          EndOfCentralDirectoryOffset := Offset + I;
          Break;
        end
        else
          Inc(Cursor);
      }

      // ������� ��������� END_OF_CENTRAL_DIR_SIGNATURE ����� ������ ��� ���
      Cursor := PByte(PAnsiChar(Buff) + BuffSize - 5);
      for I := BuffSize - 5 downto 0 do
      begin
        if PCardinal(Cursor)^ = END_OF_CENTRAL_DIR_SIGNATURE then
        begin
          EndOfCentralDirectoryOffset := Offset + I;
          Break;
        end
        else
          Dec(Cursor);
      end;

      if EndOfCentralDirectoryOffset >= 0 then
        Break;

      // Rouse_ 14.02.2013
      // ��������� ����� ������������� �� ������� ����� ����� ��������
      // ������� ����� ������� ��������� ��������� ������ ��������
      SignOffset := 4;

    end;
  finally
    FreeMem(Buff);
  end;
  if EndOfCentralDirectoryOffset < 0 then
    raise EZipReader.Create('�� ������� ��������� END_OF_CENTRAL_DIR_SIGNATURE.');

  // ���������� ���� ��������� EndOfCentralDirectory
  // ��� ������������� ����� �������� ������ �� 64 ������ ��������
  Value.Position := EndOfCentralDirectoryOffset;
  LoadEndOfCentralDirectory;

  // ������ ��������� ������ ��������� �� ������ ��������� CentralDirectory
  // ���������� �� ����
  LoadCentralDirectoryFileHeader;
end;

//
//  ��������� ���������� ��������� �������� � ��������� ��� � Ansi ������
// =============================================================================
procedure TFWZipReader.LoadStringValue(var Value: AnsiString; nSize: Cardinal);
begin
  if Integer(nSize) > 0 then
  begin
    SetLength(Value, nSize);

    if FZIPStream.Read(Value[1], nSize) <> Integer(nSize) then
      raise EZipReaderRead.Create('������ ������ ���������� � ������');

    Value := ConvertFromOemString(Value);
  end;
end;

//
//  ��������� ��������� ���������� ��������� Zip64EOFCentralDirectoryRecord
//  ������ ��������� �������� ������ �� CentralDirectory
// =============================================================================
procedure TFWZipReader.LoadZip64EOFCentralDirectoryRecord;
begin
  FZIPStream.ReadBuffer(FZip64EOFCentralDirectoryRecord,
    SizeOf(TZip64EOFCentralDirectoryRecord));

  if not Zip64Present then
    raise EZipReader.Create(
      '������ ������ ��������� TZip64EOFCentralDirectoryRecord');

  // Rouse_ 02.10.2012
  // ��� ������ ��������� ������ �� ������ ������ StartZipDataOffset
  SetStreamPosition(FZip64EOFCentralDirectoryRecord.DiskNumberStart,
    FZip64EOFCentralDirectoryRecord.RelativeOffsetOfCentralDirectory +
    StartZipDataOffset);
end;

//
//  ��������� ��������� ���������� ��������� ZIP64Locator
//  ������ ��������� �������� ������ �� Zip64EOFCentralDirectoryRecord
// =============================================================================
procedure TFWZipReader.LoadZIP64Locator;
begin
  FZIPStream.ReadBuffer(FZip64EOFCentralDirectoryLocator,
    SizeOf(TZip64EOFCentralDirectoryLocator));

  if FZip64EOFCentralDirectoryLocator.Signature <>
    ZIP64_END_OF_CENTRAL_DIR_LOCATOR_SIGNATURE then
    raise EZipReader.Create(
      '������ ������ ��������� TZip64EOFCentralDirectoryLocator');

  // ������ ��������� ������ ������ �� TZip64EOFCentralDirectoryRecord
  // � ������� � ��������� ����������� ����������
  SetStreamPosition(FZip64EOFCentralDirectoryLocator.DiskNumberStart,
    FZip64EOFCentralDirectoryLocator.RelativeOffset + StartZipDataOffset);

  LoadZip64EOFCentralDirectoryRecord;
end;

//
//  ��������� ���������� ���������� ��� �������� ������ � ������ ����� ����� � ������
//  ��� �������� ������ ������ ���������������, �� �� �����������
// =============================================================================
procedure TFWZipReader.ProcessExtractOrCheckAllData(const ExtractMask: string;
  Path: string; CheckMode: Boolean);
var
  I, A: Integer;
  OldExtractEvent: TZipExtractItemEvent;
  OldDuplicateEvent: TZipDuplicateEvent;
  CurrentItem: TFWZipReaderItem;
  ExtractResult: TExtractResult;
  CancelExtract, Handled: Boolean;
  Password, ZipExtractMask: string;
  ExtractList: TList;
  FakeStream: TFakeStream;
begin
  FTotalSizeCount := 0;
  FTotalProcessedCount := 0;
  ZipExtractMask := StringReplace(ExtractMask, '\', ZIP_SLASH, [rfReplaceAll]);
  ExtractList := TList.Create;
  try
    // ���������� ����� ������ ��� ����������
    for I := 0 to Count - 1 do
      if ExtractMask = '' then
      begin
        ExtractList.Add(UIntToPtr(I));
        Inc(FTotalSizeCount, Item[I].UncompressedSize);
      end
      else
        if MatchesMask(Item[I].FileName, ZipExtractMask) then
        begin
          ExtractList.Add(UIntToPtr(I));
          Inc(FTotalSizeCount, Item[I].UncompressedSize);
        end;

    if not CheckMode then
    begin
      // ������ ������� � �������������� ����
      Path := PathCanonicalize(Path);
      if Path = '' then
        Path := GetCurrentDir;

      // �������� ������ �� ����� �� �����?
      if GetDiskFreeAvailable(PChar(Path)) <= FTotalSizeCount then
        raise EZipReader.CreateFmt('������������ ����� �� ����� "%s".' + sLineBreak +
          '���������� ���������� %s.',
          [Path{$IFDEF MSWINDOWS}[1]{$ENDIF},
          FileSizeToStr(FTotalSizeCount)]);
    end;

    FakeStream := TFakeStream.Create;
    try
      for I := 0 to ExtractList.Count - 1 do
      begin
        FakeStream.Size := 0;
        CurrentItem := Item[Integer(PtrToUInt(ExtractList[I]))];
        DoProgress(Self, CurrentItem.FileName, 0, CurrentItem.UncompressedSize, psStart);
        OldExtractEvent := CurrentItem.OnProgress;
        try
          CurrentItem.OnProgress := DoProgress;
          OldDuplicateEvent := CurrentItem.OnDuplicate;
          try
            CurrentItem.OnDuplicate := OnDuplicate;
            // ������� ������� ����
            try
              if CheckMode then
                ExtractResult := CurrentItem.ExtractToStream(FakeStream, '')
              else
                ExtractResult := CurrentItem.Extract(Path, '');
              if ExtractResult = erNeedPassword then
              begin
                // ���� ��������� ������� ��-�� ���� ��� ���� ����������,
                // ������� ������������ ��� ��������� ������ ��������� �������
                for A := 0 to FPasswordList.Count - 1 do
                begin
                  if CheckMode then
                    ExtractResult := CurrentItem.ExtractToStream(FakeStream, FPasswordList[A])
                  else
                    ExtractResult := CurrentItem.Extract(Path, FPasswordList[A]);
                  if ExtractResult in [erDone, erSkiped] then Break;
                end;
                // ���� �� ����������, ����������� ������ � ������������
                if ExtractResult = erNeedPassword then
                  if Assigned(FOnNeedPwd) then
                  begin
                    CancelExtract := False;
                    while ExtractResult = erNeedPassword do
                    begin
                      Password := '';
                      FOnNeedPwd(Self, CurrentItem.FileName,
                        Password, CancelExtract);
                      if CancelExtract then Exit;
                      if Password <> '' then
                      begin
                        FPasswordList.Add(Password);
                        if CheckMode then
                          ExtractResult := CurrentItem.ExtractToStream(FakeStream, Password)
                        else
                          ExtractResult := CurrentItem.Extract(Path, Password);
                      end;
                    end;
                  end
                  else
                    raise EWrongPasswordException.CreateFmt(
                      '������ ���������� ������ �������� �%d "%s".' + sLineBreak +
                      '�������� ������.', [CurrentItem.ItemIndex, CurrentItem.FileName]);
              end;
            except

              // ������������ ������� ���������� ������
              on E: EAbort do
                Exit;

              // �� �� ��������� �� ���������� ��-�� ���������� �� ����� �����?
              // ����� ������� � ���������� ���������� ��������� �������
              on E: Exception do
              begin
                Handled := False;
                if Assigned(FException) then
                  FException(Self, E, Integer(PtrToUInt(ExtractList[I])), Handled);
                if not Handled then
                  // Rouse_ 20.02.2012
                  // ������� �������������� ����������
                  // ������� v1ctar �� �������� ����
                  //raise E;
                  raise;
              end;
            end;
            Inc(FTotalProcessedCount, CurrentItem.UncompressedSize);
          finally
            CurrentItem.OnDuplicate := OldDuplicateEvent;
          end;
        finally
          CurrentItem.OnProgress := OldExtractEvent;
          DoProgress(Self, CurrentItem.FileName, 0,
            CurrentItem.UncompressedSize, psEnd);
        end;
      end;

    finally
      FakeStream.Free;
    end;

  finally
    ExtractList.Free;
  end;
end;

procedure TFWZipReader.SetDefaultDuplicateAction(const Value: TDuplicateAction);
begin
  if Value = daUseNewFilePath then
    raise EZipReader.Create(
      '�������� daUseNewFilePath ����� ��������� ������ � ����������� ������� OnDuplicate.');
  FDefaultDuplicateAction := Value;
end;

procedure TFWZipReader.SetStreamPosition(DiskNumber: Integer; Offset: Int64);
begin
  if IsMultiPartZip then
    TFWAbstractMultiStream(FZIPStream).Seek(DiskNumber, Offset)
  else
    FZIPStream.Position := Offset;
end;

//
//  ������� ���������� ������ ����������� ����������
// =============================================================================
function TFWZipReader.SizeOfCentralDirectory: Int64;
begin
  if Zip64Present then
    Result := FZip64EOFCentralDirectoryRecord.SizeOfTheCentralDirectory
  else
    Result := FEndOfCentralDir.SizeOfTheCentralDirectory;
end;

//
//  ������� ���������� ���������� ��������� ������
// =============================================================================
function TFWZipReader.TotalEntryesCount: Integer;
begin
  if Zip64Present then
    Result := FZip64EOFCentralDirectoryRecord.TotalNumberOfEntries
  else
    Result := FEndOfCentralDir.TotalNumberOfEntries;
end;

//
//  ��������������� �������,
//  ��������� �� ������ ����� ������ ����� �������� ��������
// =============================================================================
function TFWZipReader.Zip64Present: Boolean;
begin
  Result := FZip64EOFCentralDirectoryRecord.Zip64EndOfCentralDirSignature =
    ZIP64_END_OF_CENTRAL_DIR_SIGNATURE
end;

end.
