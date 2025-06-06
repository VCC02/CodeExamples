{
    Copyright (C) 2025 VCC
    creation date: 06 Mar 2025
    initial release date: 06 Mar 2025

    author: VCC
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
    OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}


unit SimpleMatCmpWithOpenCLMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  Spin;

type

  { TfrmSimpleMatCmpWithOpenCLMain }

  TfrmSimpleMatCmpWithOpenCLMain = class(TForm)
    btnMatCmp: TButton;
    btnStop: TButton;
    lblYOffset: TLabel;
    lblXOffset: TLabel;
    lblCurrentYOffset: TLabel;
    memLog: TMemo;
    prbXOffset: TProgressBar;
    prbYOffset: TProgressBar;
    spnedtXOffset: TSpinEdit;
    spnedtYOffset: TSpinEdit;
    procedure btnMatCmpClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
  private
    FStop: Boolean;

    procedure AddToLog(s: string);
    procedure StopExecution(AError: Integer; AFuncName: string);
    procedure LogCallResult(AError: Integer; AFuncName, AInfo: string);
  public

  end;

var
  frmSimpleMatCmpWithOpenCLMain: TfrmSimpleMatCmpWithOpenCLMain;

implementation

{$R *.frm}

uses
  ctypes, cl;


//ToDo:
//- move  for i, for j kernel execution calling to a new kernel, which starts the MatCmp kernel instances  (may require OpenCL >= 2.0)

function GetKernelSrc: string;
begin        //int is 32-bit, long is 64-bit
  Result :=
    '__kernel void MatCmp(                      ' + #13#10 +
    '  __global uchar* ABackgroundBmp,          ' + #13#10 +
    '  __global uchar* ASubBmp,                 ' + #13#10 +
    '  __global int* AResultedErrCount,         ' + #13#10 +
    '  const unsigned int ABackgroundWidth,     ' + #13#10 +
    '  const unsigned int ASubBmpWidth,         ' + #13#10 +
    '  const unsigned int AXOffset,             ' + #13#10 +
    '  const unsigned int AYOffset,             ' + #13#10 +
    '  const uchar AColorError)                 ' + #13#10 +
    '{                                          ' + #13#10 +
    '  int YIdx = get_global_id(0);             ' + #13#10 + //goes from 0 to SubBmpHeight - 1
    '  __global uchar const * BGRow = &ABackgroundBmp[(YIdx + AYOffset) * ABackgroundWidth + AXOffset];' + #13#10 + //pointer to the current row, indexed by YIdx
    '  __global uchar const * SubRow = &ASubBmp[YIdx * ASubBmpWidth];' + #13#10 + //pointer to the current row, indexed by YIdx
    '  int ErrCount = 0;                        ' + #13#10 +
    '  for (int x = 0; x < ASubBmpWidth; x++)   ' + #13#10 +
    '  {                                        ' + #13#10 +
    '     short SubPx = SubRow[x];              ' + #13#10 +
    '     short BGPx = BGRow[x];                ' + #13#10 +
    '     if (abs(SubPx - BGPx) > AColorError)  ' + #13#10 +
    '     {                                     ' + #13#10 +
    '       ErrCount++;                         ' + #13#10 +
    '     }  //if                               ' + #13#10 +
    '  }  //for                                 ' + #13#10 +
    '  AResultedErrCount[YIdx] = ErrCount;      ' + #13#10 +
    '}';
end;


function GetKernelSrcRGB(ARGBSize: Byte): string;
var
  RGBSizeStr: string;
begin      //int is 32-bit, long is 64-bit
  if not (ARGBSize in [3, 4]) then
  begin
    Result := 'Bad code';
    Exit;
  end;

  RGBSizeStr := IntToStr(ARGBSize);

  Result :=
    '__kernel void MatCmp(                      ' + #13#10 +
    '  __global uchar* ABackgroundBmp,          ' + #13#10 +
    '  __global uchar* ASubBmp,                 ' + #13#10 +
    '  __global int* AResultedErrCount,         ' + #13#10 +
    '  const unsigned int ABackgroundWidth,     ' + #13#10 +
    '  const unsigned int ASubBmpWidth,         ' + #13#10 +
    '  const unsigned int AXOffset,             ' + #13#10 +
    '  const unsigned int AYOffset,             ' + #13#10 +
    '  const uchar AColorError)                 ' + #13#10 +
    '{                                          ' + #13#10 +
    '  int YIdx = get_global_id(0);             ' + #13#10 + //goes from 0 to SubBmpHeight - 1
    '  __global uchar const * BGRow = &ABackgroundBmp[((YIdx + AYOffset) * ABackgroundWidth + AXOffset) * ' + RGBSizeStr + '];' + #13#10 + //pointer to the current row, indexed by YIdx
    '  __global uchar const * SubRow = &ASubBmp[(YIdx * ASubBmpWidth) * ' + RGBSizeStr + '];' + #13#10 + //pointer to the current row, indexed by YIdx
    '  int ErrCount = 0;                             ' + #13#10 +
    '  for (int x = 0; x < ASubBmpWidth; x++)        ' + #13#10 +
    '  {                                             ' + #13#10 +
    '     int x0 = x * ' + RGBSizeStr + ' + 0;                        ' + #13#10 +
    '     int x1 = x * ' + RGBSizeStr + ' + 1;                        ' + #13#10 +
    '     int x2 = x * ' + RGBSizeStr + ' + 2;                        ' + #13#10 +
    '     short SubPxB = SubRow[x0];                 ' + #13#10 +
    '     short BGPxB = BGRow[x0];                   ' + #13#10 +
    '     short SubPxG = SubRow[x1];                 ' + #13#10 +
    '     short BGPxG = BGRow[x1];                   ' + #13#10 +
    '     short SubPxR = SubRow[x2];                 ' + #13#10 +
    '     short BGPxR = BGRow[x2];                   ' + #13#10 +
    '     if ((abs(SubPxR - BGPxR) > AColorError) || ' + #13#10 +
    '         (abs(SubPxG - BGPxG) > AColorError) || ' + #13#10 +
    '         (abs(SubPxB - BGPxB) > AColorError))   ' + #13#10 +
    '     {                                          ' + #13#10 +
    '       ErrCount++;                              ' + #13#10 +
    '     }  //if                                    ' + #13#10 +
    '  }  //for                                      ' + #13#10 +
    '  AResultedErrCount[YIdx] = ErrCount;           ' + #13#10 +
    '}';
end;


const
  CBackgroundBmpWidth = 1920;
  CBackgroundBmpHeight = 1080;
  CSubBmpWidth = 237;
  CSubBmpHeight = 16;


{ TfrmSimpleMatCmpWithOpenCLMain }

procedure TfrmSimpleMatCmpWithOpenCLMain.AddToLog(s: string);
begin
  memLog.Lines.Add(s);
end;


procedure TfrmSimpleMatCmpWithOpenCLMain.StopExecution(AError: Integer; AFuncName: string);
begin
  AddToLog('Error ' + IntToStr(AError) + '(' + clErrorText(AError) + ') at ' + AFuncName);
  raise Exception.Create('Execution stopped.');
end;


procedure TfrmSimpleMatCmpWithOpenCLMain.LogCallResult(AError: Integer; AFuncName, AInfo: string);
begin
  if AError = CL_SUCCESS then
  begin
    if AInfo <> '' then
      AddToLog(AFuncName + '  ' + AInfo);
  end
  else
    StopExecution(AError, AFuncName);
end;


{$DEFINE RGBItem}
//{$DEFINE RGBAlphaItem}


procedure TfrmSimpleMatCmpWithOpenCLMain.btnMatCmpClick(Sender: TObject);
type
  {$IFnDEF RGBItem}
    TArrItem = record  //1-byte px
      Item: Byte;
    end;
  {$ELSE}
    TArrItem = record  //3/4-byte px
      B: Byte;
      G: Byte;
      R: Byte;
      {$IFDEF RGBAlphaItem}
        A: Byte;
      {$ENDIF}
    end;
  {$ENDIF}
var
  Error, SecondError: Integer;
  BackgroundData: array[0..CBackgroundBmpWidth * CBackgroundBmpHeight - 1] of TArrItem; // Byte;
  SubBmpData: array[0..CSubBmpWidth * CSubBmpHeight - 1] of TArrItem; // Byte;
  DiffCntPerRow: array of LongInt;
  DifferentCount: LongInt;

  KernelSrc: string;

  GlobalSize: csize_t;
  LocalSize: csize_t;
  DeviceID: cl_device_id;
  Context: cl_context;
  CmdQueue: cl_command_queue;
  CLProgram: cl_program;
  CLKernel: cl_kernel;

  i, j, k: Integer;
  BackgroundBmpWidth, BackgroundBmpHeight: Integer;
  SubBmpWidth, SubBmpHeight: Integer;
  XOffset, YOffset: Integer;
  ColorError: Byte;

  BackgroundBufferRef: cl_mem;
  SubBufferRef: cl_mem;
  ResBufferRef: cl_mem;

  DevType: cl_device_type; //GPU
  PlatformIDs: Pcl_platform_id;
  PlatformCount: cl_uint;
  BGIdx: Integer;
  SubIdx: Integer;

  tk: QWord;
  Info: string;
  InfoLen: csize_t;
begin
  FStop := False;

  BackgroundBmpWidth := CBackgroundBmpWidth;
  BackgroundBmpHeight := CBackgroundBmpHeight;
  SubBmpWidth := CSubBmpWidth;
  SubBmpHeight := CSubBmpHeight;

  AddToLog('SizeOf(TArrItem): ' + IntToStr(SizeOf(TArrItem)));

  {$IFnDEF RGBItem}
    KernelSrc := GetKernelSrc1;
  {$ELSE}
    KernelSrc := GetKernelSrcRGB(3 {$IFDEF RGBAlphaItem} + 1 {$ENDIF});
  {$ENDIF}

  Randomize;
  for i := 0 to BackgroundBmpHeight - 1 do
    for j := 0 to BackgroundBmpWidth - 1 do
    begin
      BGIdx := i * BackgroundBmpWidth + j;

      {$IFnDEF RGBItem}
        BackgroundData[BGIdx].Item := Random(256);
      {$ELSE}
        BackgroundData[BGIdx].R := Random(256);
        BackgroundData[BGIdx].G := Random(256);
        BackgroundData[BGIdx].B := Random(256);
        {$IFDEF RGBAlphaItem}
          BackgroundData[BGIdx].A := Random(256);
        {$ENDIF}
      {$ENDIF}
    end;

  XOffset := spnedtXOffset.Value; //180
  YOffset := spnedtYOffset.Value; //117

  for i := 0 to SubBmpHeight - 1 do
    for j := 0 to SubBmpWidth - 1 do
    begin
      BGIdx := (i + YOffset) * BackgroundBmpWidth + j + XOffset;
      SubIdx := i * SubBmpWidth + j;
      SubBmpData[SubIdx] := BackgroundData[BGIdx];

      {$IFDEF RGBAlphaItem}
        SubBmpData[SubIdx].A := BackgroundData[BGIdx].A + 123; // Make sure the alpha channel is different. This proves that only the R, G, B fields are compared at GPU side.
      {$ENDIF}
    end;

  try
    Error := clGetPlatformIDs(0, nil, @PlatformCount);
    LogCallResult(Error, 'clGetPlatformIDs', 'PlatformCount: ' + IntToStr(PlatformCount));

    GetMem(PlatformIDs, PlatformCount * SizeOf(cl_platform_id));
    try
      Error := clGetPlatformIDs(PlatformCount, PlatformIDs, nil);
      LogCallResult(Error, 'clGetPlatformIDs', '');

      DevType := CL_DEVICE_TYPE_GPU;
      DeviceID := nil;
      Error := clGetDeviceIDs(PlatformIDs[0], DevType, 1, @DeviceID, nil);

      LogCallResult(Error, 'clGetDeviceIDs', '');

      Context := clCreateContext(nil, 1, @DeviceID, nil, nil, Error);
      try
        if Context = nil then
          LogCallResult(Error, 'clCreateContext', '');

        CmdQueue := clCreateCommandQueue(Context, DeviceID, 0, Error);
        if CmdQueue = nil then
          LogCallResult(Error, 'clCreateCommandQueue', '');

        CLProgram := clCreateProgramWithSource(Context, 1, PPAnsiChar(@KernelSrc), nil, Error);
        if CLProgram = nil then
          LogCallResult(Error, 'clCreateProgramWithSource', '');

        Error := clBuildProgram(CLProgram, 0, nil, nil, nil, nil);
        //LogCallResult(Error, 'clBuildProgram', 'Kernel code compiled.');

        if Error < CL_SUCCESS then
        begin
          SetLength(Info, 32768);
          SecondError := clGetProgramBuildInfo(CLProgram, DeviceID, CL_PROGRAM_BUILD_LOG, Length(Info), @Info[1], InfoLen);
          SetLength(Info, InfoLen);
          LogCallResult(SecondError, 'clGetProgramBuildInfo', 'Additional build info.');

          Info := StringReplace(Info, #13#10, '|', [rfReplaceAll]);
          Info := StringReplace(Info, #10, '|', [rfReplaceAll]);
          LogCallResult(Error, 'clBuildProgram', 'Kernel code compiled. ' + Info);
        end;

        btnMatCmp.Enabled := False;
        CLKernel := clCreateKernel(CLProgram, 'MatCmp', Error);
        try
          LogCallResult(Error, 'clCreateKernel', 'Kernel allocated.');

          Error := clGetKernelWorkGroupInfo(CLKernel, DeviceID, CL_KERNEL_WORK_GROUP_SIZE, SizeOf(LocalSize), @LocalSize, nil);
          LogCallResult(Error, 'clGetKernelWorkGroupInfo', 'Work group info obtained.');

          BackgroundBufferRef := clCreateBuffer(Context, CL_MEM_READ_ONLY, csize_t(SizeOf(TArrItem) * BackgroundBmpWidth * BackgroundBmpHeight), nil, Error);
          try
            LogCallResult(Error, 'clCreateBuffer', 'Background buffer created.');

            SubBufferRef := clCreateBuffer(Context, CL_MEM_READ_ONLY, csize_t(SizeOf(TArrItem) * SubBmpWidth * SubBmpHeight), nil, Error);
            try
              LogCallResult(Error, 'clCreateBuffer', 'Sub buffer created.');

              ResBufferRef := clCreateBuffer(Context, CL_MEM_WRITE_ONLY, csize_t(SizeOf(LongInt) * SubBmpHeight), nil, Error);
              try
                LogCallResult(Error, 'clCreateBuffer', 'Res buffer created.');

                Error := clEnqueueWriteBuffer(CmdQueue, BackgroundBufferRef, CL_TRUE, 0, csize_t(SizeOf(TArrItem) * BackgroundBmpWidth * BackgroundBmpHeight), @BackgroundData, 0, nil, nil);
                LogCallResult(Error, 'clEnqueueWriteBuffer', 'Background buffer written.');

                Error := clEnqueueWriteBuffer(CmdQueue, SubBufferRef, CL_TRUE, 0, csize_t(SizeOf(TArrItem) * SubBmpWidth * SubBmpHeight), @SubBmpData, 0, nil, nil);
                LogCallResult(Error, 'clEnqueueWriteBuffer', 'Sub buffer written.');

                XOffset := 0;
                YOffset := 0;
                ColorError := 0;

                Error := clSetKernelArg(CLKernel, 0, SizeOf(cl_mem), @BackgroundBufferRef); //sizeof(cl_mem)  is SizeOf(Pointer), which can be 4 or 8
                LogCallResult(Error, 'clSetKernelArg', 'BackgroundBufferRef argument set.');

                Error := clSetKernelArg(CLKernel, 1, SizeOf(cl_mem), @SubBufferRef); //sizeof(cl_mem)  is SizeOf(Pointer), which can be 4 or 8
                LogCallResult(Error, 'clSetKernelArg', 'SubBufferRef argument set.');

                Error := clSetKernelArg(CLKernel, 2, SizeOf(cl_mem), @ResBufferRef); //sizeof(cl_mem)  is SizeOf(Pointer), which can be 4 or 8
                LogCallResult(Error, 'clSetKernelArg', 'ResBufferRef argument set.');

                Error := clSetKernelArg(CLKernel, 3, SizeOf(LongInt), @BackgroundBmpWidth);
                LogCallResult(Error, 'clSetKernelArg', 'ABackgroundWidth argument set.');

                Error := clSetKernelArg(CLKernel, 4, SizeOf(LongInt), @SubBmpWidth);
                LogCallResult(Error, 'clSetKernelArg', 'ASubBmpWidth argument set.');

                Error := clSetKernelArg(CLKernel, 5, SizeOf(LongInt), @XOffset);
                LogCallResult(Error, 'clSetKernelArg', 'XOffset argument set.');

                Error := clSetKernelArg(CLKernel, 6, SizeOf(LongInt), @YOffset);
                LogCallResult(Error, 'clSetKernelArg', 'YOffset argument set.');

                Error := clSetKernelArg(CLKernel, 7, SizeOf(Byte), @ColorError);
                LogCallResult(Error, 'clSetKernelArg', 'ColorError argument set.');

                GlobalSize := SubBmpHeight;
                LogCallResult(Error, 'Matrix comparison', 'Starting...');
                memLog.Repaint;

                prbXOffset.Max := BackgroundBmpWidth - SubBmpWidth - 1;
                prbYOffset.Max := BackgroundBmpHeight - SubBmpHeight - 1;

                SetLength(DiffCntPerRow, GlobalSize);
                tk := GetTickCount64;
                for i := 0 to BackgroundBmpHeight - SubBmpHeight - 1 do
                begin
                  prbYOffset.Position := i;
                  //prbYOffset.Repaint;
                  lblCurrentYOffset.Caption := IntToStr(i);

                  for j := 0 to BackgroundBmpWidth - SubBmpWidth - 1 do
                  begin
                    prbXOffset.Position := j;
                    //prbXOffset.Repaint;

                    XOffset := j;
                    YOffset := i;

                    Error := clSetKernelArg(CLKernel, 5, SizeOf(LongInt), @XOffset);
                    LogCallResult(Error, 'clSetKernelArg', '');

                    Error := clSetKernelArg(CLKernel, 6, SizeOf(LongInt), @YOffset);
                    LogCallResult(Error, 'clSetKernelArg', '');

                    Error := clEnqueueNDRangeKernel(CmdQueue, CLKernel, 1, nil, @GlobalSize, nil, 0, nil, nil);
                    LogCallResult(Error, 'clEnqueueNDRangeKernel', '');

                    Error := clFinish(CmdQueue);
                    LogCallResult(Error, 'clEnqueueNDRangeKernel', '');

                    Error := clEnqueueReadBuffer(CmdQueue, ResBufferRef, CL_TRUE, 0, csize_t(SizeOf(LongInt) * GlobalSize), @DiffCntPerRow[0], 0, nil, nil);
                    LogCallResult(Error, 'clEnqueueReadBuffer', '');

                    DifferentCount := 0;
                    for k := 0 to GlobalSize - 1 do //results len
                      Inc(DifferentCount, DiffCntPerRow[k]);

                    if DifferentCount = 0 then
                    begin
                      AddToLog('Found a match at XOffset = ' + IntToStr(XOffset) + '  YOffset = ' + IntToStr(YOffset) + '  in ' + IntToStr(GetTickCount64 - tk) + 'ms.');
                      Break;
                    end;

                    if FStop then
                      Break;
                  end; //for j

                  if DifferentCount = 0 then
                    Break;

                  if FStop then
                    Break;

                  Application.ProcessMessages;
                end; //for i

                prbXOffset.Position := 0;
                prbYOffset.Position := 0;
              finally
                clReleaseMemObject(ResBufferRef);
              end;
            finally
              clReleaseMemObject(SubBufferRef);
            end;
          finally
            clReleaseMemObject(BackgroundBufferRef);
          end;
        finally  //clCreateKernel
          clReleaseKernel(CLKernel);
          btnMatCmp.Enabled := True;
        end;

        clReleaseProgram(CLProgram);
        clReleaseCommandQueue(CmdQueue);
      finally
        clReleaseContext(Context);
      end;
    finally
      Freemem(PlatformIDs, PlatformCount * SizeOf(cl_platform_id));
    end;
  finally
    AddToLog('Done');
  end;
end;


procedure TfrmSimpleMatCmpWithOpenCLMain.btnStopClick(Sender: TObject);
begin
  FStop := True;
end;

end.

