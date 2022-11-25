
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillDocumentsTypesList();
	
EndProcedure

&AtServer
Procedure FillDocumentsTypesList()
	
	DriveServer.FillDocumentsTypesList(Items.DocumentType.ChoiceList);
	
EndProcedure

