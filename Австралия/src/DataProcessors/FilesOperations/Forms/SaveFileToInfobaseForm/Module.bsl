
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	File = Parameters.FileRef;
	VersionComment = Parameters.VersionComment;
	CreateNewVersion = Parameters.CreateNewVersion;
	Items.CreateNewVersion.Enabled = Parameters.CreateNewVersionAvailability;
	
	If File.StoreVersions Then
		CreateNewVersion = True;
	Else
		CreateNewVersion = False;
		Items.CreateNewVersion.Enabled = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Save(Command)
	
	ReturnStructure = New Structure("VersionComment, CreateNewVersion, ReturnCode",
		VersionComment, CreateNewVersion, DialogReturnCode.OK);
	
	Close(ReturnStructure);
	
	Notify("FilesOperations_NewFIleVersionSaved");
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	ReturnStructure = New Structure("VersionComment, CreateNewVersion, ReturnCode",
		VersionComment, CreateNewVersion, DialogReturnCode.Cancel);
	
	Close(ReturnStructure);
	
EndProcedure

#EndRegion