#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.List.ChoiceMode = Parameters.ChoiceMode;
	
	BusinessUnit = Undefined;
	UseBusinessUnitFilter = GetFunctionalOption("PlanCompanyResourcesImporting")
		And Parameters.Property("BusinessUnit", BusinessUnit);
	
	List.Parameters.SetParameterValue("UseBusinessUnitFilter", UseBusinessUnitFilter);
	List.Parameters.SetParameterValue("BusinessUnit", BusinessUnit);
	
	If Not AccessRight("Edit", Metadata.Catalogs.ManufacturingActivities) Then
		Items.FormDataImportFromExternalSources.Visible = False;
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.ManufacturingActivities, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor",
		ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TemplateNameWithTemplate",	"LoadFromFile");
	DataLoadSettings.Insert("SelectionRowDescription",
		New Structure("FullMetadataObjectName, Type", "ManufacturingActivities", "AppliedImport"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings,
		NotifyDescription, ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		ProcessPreparedData(ImportResult);
		Items.List.Refresh();
		ShowMessageBox(Undefined, NStr("en = 'Data import is complete.'; ru = 'Загрузка данных завершена.';pl = 'Pobieranie danych zakończone.';es_ES = 'Importación de datos se ha finalizado.';es_CO = 'Importación de datos se ha finalizado.';tr = 'Veri içe aktarımı tamamlandı.';it = 'L''importazione dei dati è stata completata.';de = 'Der Datenimport ist abgeschlossen.'"));
		
	ElsIf ImportResult = Undefined Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult);
	
EndProcedure

#EndRegion