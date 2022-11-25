#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FilesOwnerID = Undefined;
	
	If Parameters.Property("FileOwner") Then
		Record.FileOwner = Parameters.FileOwner;
	EndIf;
	
	If Parameters.Property("FileOwnerType") Then
		Record.FileOwnerType = Parameters.FileOwnerType;
	EndIf;
	
	If Parameters.Property("IsFile") Then
		Record.IsFile = Parameters.IsFile;
	EndIf;
	
	OwnerPresentation = Common.SubjectString(Record.FileOwner);
	
	Title = NStr("ru='Настройка синхронизации файлов:'; en = 'Configure file synchronization:'; pl = 'Dostosowanie synchronizacji plików:';es_ES = 'Ajuste de sincronización de archivos:';es_CO = 'Ajuste de sincronización de archivos:';tr = 'Dosya eşleşmesinin ayarı:';it = 'Configura sincronizzazione file:';de = 'Einrichten der Dateisynchronisation:'")
		+ " " + OwnerPresentation;
	
EndProcedure

#EndRegion