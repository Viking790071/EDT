#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.ChartsOfAccounts.PrimaryChartOfAccounts, DataLoadSettings, ThisObject, False);
	// End StandardSubsystems.DataImportFromExternalSource
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

#Region DataImportFromExternalSources

&AtClient
Procedure ImportChartOfAccountsFromExternalSource(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
		ShowMessageBox( , NStr("en = 'Data import is complete.'; ru = 'Загрузка данных завершена.';pl = 'Pobieranie danych zakończone.';es_ES = 'Importación de datos se ha finalizado.';es_CO = 'Importación de datos se ha finalizado.';tr = 'Veri içe aktarımı tamamlandı.';it = 'L''importazione dei dati è stata completata.';de = 'Der Datenimport ist abgeschlossen.'"));
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult);
	
EndProcedure

#EndRegion

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	ColorHeaderGLA = StyleColors.HeaderGLAccounts;
	
	// List
	
	ItemAppearance = List.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("TypeOfAccount");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Enums.GLAccountsTypes.Header;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("BackColor", ColorHeaderGLA);
	
EndProcedure


#EndRegion
