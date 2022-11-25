#Region Private

// Checks whether infobase configuration update in the subordinate node is required.
//
Procedure CheckSubordinateNodeConfigurationUpdateRequired() Export
	
	UpdateRequired = StandardSubsystemsClient.ClientRunParameters().DIBNodeConfigurationUpdateRequired;
	CheckUpdateRequired(UpdateRequired);
	
EndProcedure

// Checks whether infobase configuration update in the subordinate node is required. The check is performed on application startup.
//
Procedure CheckSubordinateNodeConfigurationUpdateRequiredOnStart() Export
	
	UpdateRequired = StandardSubsystemsClient.ClientParametersOnStart().DIBNodeConfigurationUpdateRequired;
	CheckUpdateRequired(UpdateRequired);
	
EndProcedure

Procedure CheckUpdateRequired(DIBNodeConfigurationUpdateRequired)
	
	If DIBNodeConfigurationUpdateRequired Then
		Note = NStr("ru = 'Получено обновление программы из ""%1"".
			|Необходимо установить обновление программы, после чего синхронизация данных будет продолжена.'; 
			|en = 'The application update is received from ""%1"". 
			|You should install the update so that data synchronization continues.'; 
			|pl = 'Aktualizacja aplikacji otrzymana od ""%1"".
			|Konieczne jest zainstalowanie aktualizacji aplikacji, po której synchronizacja danych będzie kontynuowana.';
			|es_ES = 'La actualización de la aplicación se ha recibido desde ""%1"".
			|Instalar la actualización para que la sincronización de datos se continúe.';
			|es_CO = 'La actualización de la aplicación se ha recibido desde ""%1"".
			|Instalar la actualización para que la sincronización de datos se continúe.';
			|tr = 'Bu uygulamanın güncellemesi ""%1""dan alınmaktadır. 
			|Veri senkronizasyonuna devam etmek için güncellemeyi kurmanız gerekmektedir.';
			|it = 'L''aggiornamento dell''applicazione è ricevuto da ""%1"".
			|Dovreste installare l''aggiornamento in modo che la sincronizzazione dati prosegua.';
			|de = 'Die Anwendung wurde von ""%1"" aktualisiert.
			|Sie sollten das Update installieren, damit die Datensynchronisierung fortgesetzt wird.'");
		Note = StringFunctionsClientServer.SubstituteParametersToString(Note, StandardSubsystemsClient.ClientRunParameters().MasterNode);
		ShowUserNotification(NStr("ru = 'Установить обновление'; en = 'Install the update'; pl = 'Instalacja aktualizacji';es_ES = 'Instalar la actualización';es_CO = 'Instalar la actualización';tr = 'Güncellemeyi yükle';it = 'Installare l''aggiornamento';de = 'Update installieren'"), "e1cib/app/DataProcessor.DataExchangeExecution",
			Note, PictureLib.Warning32);
		Notify("DataExchangeCompleted");
	EndIf;
	
	AttachIdleHandler("CheckSubordinateNodeConfigurationUpdateRequired", 60 * 60, True); // once an hour
	
EndProcedure

#EndRegion
