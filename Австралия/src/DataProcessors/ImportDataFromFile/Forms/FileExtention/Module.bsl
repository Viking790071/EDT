#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	If FileType = 0 Then 
		Result = "xlsx";
	ElsIf FileType = 1 Then
		Result = "csv";
	ElsIf FileType = 4 Then
		Result = "xls";
	ElsIf FileType = 5 Then
		Result = "ods";
	Else
		Result = "mxl";
	EndIf;
	Close(Result);
EndProcedure

&AtClient
Procedure InstallAddonForFacilitatingWorkWithFiles(Command)
	BeginInstallFileSystemExtension(Undefined);
EndProcedure

#EndRegion








