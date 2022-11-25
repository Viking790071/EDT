
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Cancel = False;
	
	TempStorageAddress = "";
	
	GetSecondInfobaseDataExchangeSettingsAtServer(Cancel, TempStorageAddress, CommandParameter);
	
	If Cancel Then
		
		ShowMessageBox(, NStr("ru = 'Возникли ошибки при получении настроек обмена данными.'; en = 'Error retrieving data exchange settings.'; pl = 'Podczas pobierania ustawień wymiany danych zaistniały błędy.';es_ES = 'Se han producido errores al recibir los ajustes de intercambio de datos.';es_CO = 'Se han producido errores al recibir los ajustes de intercambio de datos.';tr = 'Veri alışverişi ayarları alınırken hatalar oluştu.';it = 'Errore di recupero delle impostazioni di scambio dati.';de = 'Beim Empfangen der Kommunikationseinstellungen sind Fehler aufgetreten.'"));
		
	Else
		
		GetFile(TempStorageAddress, NStr("ru = 'Настройки синхронизации данных.xml'; en = 'Synchronization settings.xml'; pl = 'Ustawienia synchronizacji danych.xml';es_ES = 'Ajustes de sincronización de datos.xml';es_CO = 'Ajustes de sincronización de datos.xml';tr = 'Veri senkronizasyonu ayarları.xml';it = 'Impostazioni di sincronizzazione.xml';de = 'Datensynchronisationseinstellungen.xml'"), True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure GetSecondInfobaseDataExchangeSettingsAtServer(Cancel, TempStorageAddress, InfobaseNode)
	
	DataExchangeCreationWizard = DataExchangeServer.ModuleDataExchangeCreationWizard().Create();
	DataExchangeCreationWizard.Initializing(InfobaseNode);
	DataExchangeCreationWizard.ExportWizardParametersToTempStorage(Cancel, TempStorageAddress);
	
EndProcedure

#EndRegion
