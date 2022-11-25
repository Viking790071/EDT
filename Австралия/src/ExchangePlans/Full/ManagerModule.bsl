#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.DataExchange

// Fills in the settings that affect the exchange plan usage.
// 
// Parameters:
//  Settings - Structure - default exchange plan settings, see DataExchangeServer. 
//                          DefaultExchangePlanSettings details of the function return value.
//
Procedure OnGetSettings(Settings) Export
	
	Settings.Algorithms.OnGetSettingOptionDetails = True;
	
EndProcedure

// Fills in a set of parameters that define the exchange settings option.
// 
// Parameters:
//  OptionDetails - Structure - a default setting option set, see DataExchangeServer.
//                                       DefaultExchangeSettingOptionDetails, details of the return  
//                                       value.
//  SettingID - String - an ID of data exchange settings option.
//  ContextParameters - Structure - see DataExchangeServer. 
//                                       ContextParametersSettingOptionDetailsReceiving details of the function return value.
//
Procedure OnGetSettingOptionDetails(OptionDetails, SettingID, ContextParameters) Export
	
	ExchangeBriefInfo = NStr("en = 'A distributed information base is a hierarchical structure,
                              |consisting of separate information bases of the “1C: Enterprise” system - nodes of a distributed information base, between 
                              |which organized the synchronization of configuration and data. The main feature of distributed infobases
                              |is the transfer of configuration changes to subordinate nodes.'; 
                              |ru = 'Распределенная информационная база - это иерархическая структура,
                              |состоящая из отдельных информационных баз системы ""1С:Предприятие"" - узлов распределенной информационной базы, между 
                              |которыми организована синхронизация конфигурации и данных. Главной особенностью распределенной информационной базы
                              |является передача изменений конфигурации подчиненным узлам.';
                              |pl = 'Rozproszona baza informacyjna ma strukturę hierarchiczną,
                              |która zawiera oddzielne bazy informacyjne węzłów systemu “1C: Enterprise” rozproszonej bazy informacyjnej, między 
                              |która zorganizowała synchronizację konfiguracji i danych. Główną cechą rozproszonych baz informacyjnych
                              |jest przekazanie zmian konfiguracji do podrzędnych węzłów.';
                              |es_ES = 'La base de información distribuida es una estructura jerárquica
                              |, que consiste en bases de información separadas del sistema ""1C: Enterprise"": los nodos de una base de información distribuida, 
                              |entre los que se organiza la sincronización de la configuración y los datos. La característica principal de las bases de información distribuidas 
                              |es la transferencia de los cambios de configuración a los nodos subordinados.';
                              |es_CO = 'La base de información distribuida es una estructura jerárquica
                              |, que consiste en bases de información separadas del sistema ""1C: Enterprise"": los nodos de una base de información distribuida, 
                              |entre los que se organiza la sincronización de la configuración y los datos. La característica principal de las bases de información distribuidas 
                              |es la transferencia de los cambios de configuración a los nodos subordinados.';
                              |tr = 'Dağıtılmış bilgi tabanı hiyerarşik bir yapıya sahip olup,
                              |1C: Enterprise''ın, aralarında yapılandırma ve veri senkronizasyonu yapılan üniteler halindeki 
                              |ayrı bilgi tabanlarından meydana gelir. Dağıtılmış bilgi tabanlarının
                              |ana işlevi yapılandırma değişikliklerini alt ünitelere iletmektir.';
                              |it = 'Una infobase distribuita è una struttura gerarchica
                              | che consiste di infobase separate del sistema ""1C: Enterprise"", nodi di una infobase distribuita, tra i quali
                              | è organizzata la sincronizzazione di configurazione e dati. La caratteristica principale delle infobase distribuite
                              |è il trasferimento di modifiche di configurazione ai nodi subordinati.';
                              |de = 'Eine veröffentlichte Info-Base ist eine hierarchische Struktur,
                              |die aus einzelnen Info-Basen des “1C: Unternehmen” Systems besteht - Knoten der veröffentlichten Info-Base, zwischen
                              |diesen die Synchronisation der Konfiguration und Daten organisiert ist. Die Haupteigenschaft der veröffentlichten Info-Basen
                              |ist die Übertragung von Konfigurationsänderungen zu untergeordneten Knoten.'");
	ExchangeBriefInfo = StrReplace(ExchangeBriefInfo, Chars.LF, "");
	
	OptionDetails.ExchangeBriefInfo   = ExchangeBriefInfo;
	OptionDetails.NewDataExchangeCreationCommandTitle = NStr("en = 'Distributed infobase'; ru = 'Распределенная информационная база';pl = 'Rozproszona baza informacyjna';es_ES = 'Distribución de la base de información';es_CO = 'Distribución de la base de información';tr = 'Dağıtılmış Infobase';it = 'Base informativa distribuita';de = 'Verteilte Info-Base'");
	OptionDetails.InitialImageCreationFormName = "CommonForm.CreateInitialImageWithFiles";
	OptionDetails.NewDataExchangeCreationCommandTitle = NStr("en = 'Remote workplace (DIB full exchange)'; ru = 'Удаленное рабочее место (полный обмен РИБ)';pl = 'Zdalne miejsce pracy (Pełna wymiana rozproszonej bazy informacyjnej)';es_ES = 'Lugar de trabajo remoto (intercambio completo de DIB)';es_CO = 'Lugar de trabajo remoto (intercambio completo de DIB)';tr = 'Uzaktan çalışma alanı (DIB tam değişim)';it = 'Postazione di lavoro remota (Pieno scambio DIB)';de = 'Fernarbeitsplatz (vollständige RIB-Austausch)'");
	OptionDetails.SettingsFileNameForDestination = NStr("en = 'Remote Workplace Sharing Settings (DIB)'; ru = 'Настройки общего доступа к удаленному рабочему месту (РИБ)';pl = 'Ustawienia wspólna zdalnego miejsca pracy (rozproszona baza informacyjna)';es_ES = 'Configuración para compartir el lugar de trabajo remoto (DIB)';es_CO = 'Configuración para compartir el lugar de trabajo remoto (DIB)';tr = 'Uzaktan Çalışma Alanı Paylaşım Ayarları (DIB)';it = 'Impostazioni di Condivisione della Postazione di Lavoro Remota (DIB)';de = 'Fernarbeitsplatz - Mitbenutzungseinstellungen (RIB)'");
	OptionDetails.UsedExchangeMessagesTransports = DataExchangeServer.AllConfigurationExchangeMessagesTransports();
	OptionDetails.UseDataExchangeCreationWizard = True;
	
EndProcedure

// End StandardSubsystems.DataExchange

// StandardSubsystems.BatchObjectsModification

// Returns the object attributes that are not recommended to be edited using batch attribute 
// modification data processor.
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToSkipInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("*");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

#EndRegion

#EndRegion

#EndIf