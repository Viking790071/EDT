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
	
	BriefExchangeInfo = NStr("en = 'Syncs data between 1C:Drive and a website.'; ru = 'Синхронизирует данные между 1C:Drive и веб-сайтом.';pl = 'Synchronizacja danych między 1C:Drive i stroną internetową.';es_ES = 'Sincroniza datos entre 1C:Drive y un sitio web.';es_CO = 'Sincroniza datos entre 1C:Drive y un sitio web.';tr = '1C:Drive ile bir web sitesi arasında verileri senkronize eder.';it = 'Sincronizzazione dati tra 1C:Drive e il sito web.';de = 'Synchronisieren von Daten zwischen 1C:Drive und einer Webseite.'");
	
	OptionDetails.ExchangeBriefInfo   = BriefExchangeInfo;
	
	OptionDetails.CorrespondentConfigurationName		= Metadata.Name;
	OptionDetails.CorrespondentConfigurationDescription	= NStr("en = 'Website'; ru = 'Веб-сайт';pl = 'Strona internetowa';es_ES = 'Sitio web';es_CO = 'Sitio web';tr = 'Web sitesi';it = 'Sito web';de = 'Webseite'");
	OptionDetails.SettingsFileNameForDestination		= NStr("en = 'Website data sync settings'; ru = 'Настройки синхронизации данных веб-сайта';pl = 'Ustawienia synchronizacji danych strony internetowej';es_ES = 'Configuración de sincronización de datos del sitio web';es_CO = 'Configuración de sincronización de datos del sitio web';tr = 'Web sitesi veri senkronizasyon ayarları';it = 'Sito web impostazioni di sincronizzazione dati';de = 'Einstellungen von Synchronisieren der Daten mit Webseite'");
	
	CommandTitle = NStr("en = 'Website'; ru = 'Веб-сайт';pl = 'Strona internetowa';es_ES = 'Sitio web';es_CO = 'Sitio web';tr = 'Web sitesi';it = 'Sito web';de = 'Webseite'");
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

Procedure InitializePerformerRoles() Export
	
	RoleObject = Catalogs.PerformerRoles.Salespersons.GetObject();
	RoleObject.UsedWithoutAddressingObjects = False;
	RoleObject.UsedByAddressingObjects = True;
	RoleObject.MainAddressingObjectTypes = ChartsOfCharacteristicTypes.TaskAddressingObjects.Company;
	RoleObject.Write();
	
EndProcedure

#EndRegion

#EndIf
