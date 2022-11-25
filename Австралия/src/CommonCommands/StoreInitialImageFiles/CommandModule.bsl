#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If NOT HasFilesInVolumes() Then
		ShowMessageBox(, NStr("ru = 'Файлы в томах отсутствуют.'; en = 'No files in volumes.'; pl = 'Brak plików w woluminach.';es_ES = 'No hay archivos en los volúmenes.';es_CO = 'No hay archivos en los volúmenes.';tr = 'Ciltlerde dosyalar yok.';it = 'Nessun file dei volumi.';de = 'Keine Dateien in Volumen.'"));
		Return;
	EndIf;
	
	OpenForm("CommonForm.SelectPathToVolumeFilesArchive", , CommandExecuteParameters.Source);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function HasFilesInVolumes()
	
	Return FilesOperationsInternal.HasFilesInVolumes();
	
EndFunction

#EndRegion
