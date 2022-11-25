
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	FileCopy = Parameters.File;
	Message = Parameters.Message;
	
	FileCreationMode = 1;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SaveFile(Command)
	
	Close(FileCreationMode);
	
EndProcedure

&AtClient
Procedure OpenDirectory(Command)
	
	FilesOperationsInternalClient.OpenExplorerWithFile(FileCopy);
	
EndProcedure

#EndRegion
