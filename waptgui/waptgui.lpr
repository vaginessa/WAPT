program waptgui;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, pl_glscene, pl_luicontrols, uwaptgui, tisstrings,
  waptcommon, tiscommon, tisinifiles, uVisCreateKey
  { you can add units after this };

{$R *.res}

begin
  Application.Title:='wapt-gui';
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TVisWaptGUI, VisWaptGUI);
  Application.Run;
end.

