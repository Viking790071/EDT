
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.DataExchange

// Fills in the settings that influence the exchange plan usage.
// 
// Parameters:
//  Settings - Structure - default exchange plan settings, see DataExchangeServer. 
//                          DefaultExchangePlanSettings, details of the function return value.
//
Procedure OnGetSettings(Settings) Export
	
	SourceConfigurationName = Metadata.Name;
		
	Settings.DestinationConfigurationName.Insert(SourceConfigurationName);
	
	Settings.ExchangePlanUsedInSaaS = True;
	
	Settings.Algorithms.OnGetExchangeSettingsOptions   = True;
	Settings.Algorithms.OnGetSettingOptionDetails = True;

EndProcedure

// Fills in a collection of setting options provided for the exchange plan.
// 
// Parameters:
//  ExchangeSettingsOptions - ValueTable - a collection of exchange setting options, see details of 
//                                       return value of the DefaultExchangePlanSettings function of the DataExchangeServer common module.
//  ContextParameters - Structure - see DataExchangeServer.ContextParametersOfSettingsOptionsReceipt,  
//                                       details of the function return value.
//
Procedure OnGetExchangeSettingsOptions(ExchangeSettingsOptions, ContextParameters) Export
	
	SetupOption = ExchangeSettingsOptions.Add();
	SetupOption.SettingID = "";
	SetupOption.CorrespondentInSaaS = False;
	SetupOption.CorrespondentInLocalMode = True;
	
EndProcedure

// Fills in a set of parameters that define an exchange setting option.
// 
// Parameters:
//  OptionDetails - Structure - a default setting option set, see DataExchangeServer.
//                                       DefaultExchangeSettingOptionDetails, details of the return  
//                                       value.
//  SettingID - String - an ID of data exchange setting option.
//  ContextParameters - Structure - see DataExchangeServer. 
//                                       ContextParametersOfSettingOptionDetailsReceipt, details of the function return value.
//
Procedure OnGetSettingOptionDetails(OptionDetails, SettingID, ContextParameters) Export
	
	BriefExchangeInfo = NStr("en = 'Allows you to synchronize data between 1C:Drive and ProManage system.'; ru = 'Позволяет синхронизировать данные между 1C:Drive и системой ProManage.';pl = 'Pozwala Ci synchronizować dane między 1C:Drive i systemem ProManage.';es_ES = 'Le permite sincronizar datos entre 1C:Drive y el sistema ProManage.';es_CO = 'Le permite sincronizar datos entre 1C:Drive y el sistema ProManage.';tr = '1C:Drive ile ProManage sistemi arasında verileri senkronize etmenizi sağlar.';it = 'Permette la sincronizzazione dati tra 1C:Drive e il sistema ProManage.';de = 'Ermöglicht Synchronisierung von Daten zwischen 1C:Drive und ProManage-System.'");
	
	OptionDetails.ExchangeBriefInfo   = BriefExchangeInfo;
	
	OptionDetails.CorrespondentConfigurationName		= Metadata.Name;
	OptionDetails.CorrespondentConfigurationDescription	= NStr("en = 'ProManage'; ru = 'ProManage';pl = 'ProManage';es_ES = 'ProManage';es_CO = 'ProManage';tr = 'ProManage';it = 'ProManage';de = 'ProManage'");
	OptionDetails.SettingsFileNameForDestination		= NStr("en = 'Synchronization settings for ProManage'; ru = 'Настройки синхронизации для ProManage';pl = 'Ustawienia synchronizacji dla ProManage';es_ES = 'Configuraciones de sincronización para ProManage';es_CO = 'Configuraciones de sincronización para ProManage';tr = 'ProManage için senkronizasyon ayarları';it = 'Impostazioni di sincronizzazione per ProManage';de = 'Synchronisationseinstellungen für ProManage'");
	
	CommandTitle = NStr("en = 'ProManage'; ru = 'ProManage';pl = 'ProManage';es_ES = 'ProManage';es_CO = 'ProManage';tr = 'ProManage';it = 'ProManage';de = 'ProManage'");
	OptionDetails.NewDataExchangeCreationCommandTitle = CommandTitle;
		
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
	Result.Add("RegisterChanges");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectsModification

#EndRegion

#EndRegion

#EndIf
