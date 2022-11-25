
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	FillPropertyValues(
		ThisObject,
		Parameters,
		"ChangeDateInWorkingDirectory,
		|ChangeDateInFileStorage,
		|FullFileNameInWorkingDirectory,
		|SizeInWorkingDirectory,
		|SizeInFileStorage,
		|Message,
		|Title");
		
	TestNewer = " (" + NStr("ru='новее'; en = 'newer'; pl = 'nowsze';es_ES = 'más nuevo';es_CO = 'más nuevo';tr = 'daha yeni';it = 'più nuovo';de = 'neuer'") + ")";
	If ChangeDateInWorkingDirectory > ChangeDateInFileStorage Then
		ChangeDateInWorkingDirectory = String(ChangeDateInWorkingDirectory) + TestNewer;
	Else
		ChangeDateInFileStorage = String(ChangeDateInFileStorage) + TestNewer;
	EndIf;
	
	Items.Message.Height = StrLineCount(Message) + 2;
	
	If Parameters.FileOperation = "PutInFileStorage" Then
		
		Items.FormOpenExistingFile.Visible = False;
		Items.FormGetFromStorage.Visible    = False;
		Items.FormPut.DefaultButton   = True;
		
	ElsIf Parameters.FileOperation = "OpenInWorkingFolder" Then
		
		Items.FormPut.Visible  = False;
		Items.FormDontPutFile.Visible = False;
		Items.FormOpenExistingFile.DefaultButton = True;
	Else
		Raise NStr("ru = 'Неизвестное действие над файлом'; en = 'Unknown file operation'; pl = 'Nieznana operacja na pliku';es_ES = 'Operación desconocida en el archivo';es_CO = 'Operación desconocida en el archivo';tr = 'Dosyada bilinmeyen işlem';it = 'Azione sul file sconosciuta';de = 'Unbekannter Dateioperation'");
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then
		
		Items.FormPut.OnlyInAllActions = True;
		Items.FormGetFromStorage.OnlyInAllActions = True;
		Items.FormDontPutFile.OnlyInAllActions = True;
		Items.Cancel.OnlyInAllActions = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OpenExistingFile(Command)
	
	Close("OpenExistingFile");
	
EndProcedure

&AtClient
Procedure Put(Command)
	
	Close("INTO");
	
EndProcedure

&AtClient
Procedure GetFromApplication(Command)
	
	Close("GetFromStorageAndOpen");
	
EndProcedure

&AtClient
Procedure DontPut(Command)
	
	Close("DontPut");
	
EndProcedure

&AtClient
Procedure OpenDirectory(Command)
	
	FilesOperationsInternalClient.OpenExplorerWithFile(FullFileNameInWorkingDirectory);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close("Cancel");
	
EndProcedure

#EndRegion
