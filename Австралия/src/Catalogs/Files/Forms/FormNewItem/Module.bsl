
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	CreateMode = Parameters.CreateMode;
	
	If Parameters.ScanCommandAvailable Then
		If Parameters.ScanCommandAvailable Then
			Items.CreateMode.ChoiceList.Add(3, NStr("ru = 'Со сканера'; en = 'From scanner'; pl = 'Ze skanera';es_ES = 'Desde el escáner';es_CO = 'Desde el escáner';tr = 'Tarayıcıdan';it = 'Dallo scanner';de = 'Vom Scanner'"));
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateFileExecute()
	Close(CreateMode);
EndProcedure

#EndRegion