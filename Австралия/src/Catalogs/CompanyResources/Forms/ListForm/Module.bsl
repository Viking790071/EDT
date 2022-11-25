#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.CompanyResourceTypes, DataLoadSettingsWCT, ThisObject);
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.CompanyResources, DataLoadSettingsWC, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject,,, "ResourcesList");
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject,, "ListResourcesKinds", "ListResourcesKinds");
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_CompanyResourceTypes" Then
		
		UpdateResourcesList();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure DataImportFromExternalSourcesWCT(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor",
		ThisObject, DataLoadSettingsWCT);
	
	DataLoadSettingsWCT.Insert("TemplateNameWithTemplate",	"LoadFromFile");
	DataLoadSettingsWCT.Insert("SelectionRowDescription",
		New Structure("FullMetadataObjectName, Type", "CompanyResourceTypes", "AppliedImport"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettingsWCT,
		NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSourcesWC(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor",
		ThisObject, DataLoadSettingsWC);
	
	DataLoadSettingsWC.Insert("TemplateNameWithTemplate",	"LoadFromFile");
	DataLoadSettingsWC.Insert("SelectionRowDescription",
		New Structure("FullMetadataObjectName, Type", "CompanyResources", "AppliedImport"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettingsWC,
		NotifyDescription, ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure UpdateResourcesList()
	
	CurRow = Items.ListResourcesKinds.CurrentData;
	
	If CurRow = Undefined
		Or Not CurRow.Property("Ref")
		Or CurRow.Ref = PredefinedValue("Catalog.CompanyResourceTypes.AllResources") Then
		DriveClientServer.DeleteListFilterItem(List, "WorkcenterType");
	Else
		DriveClientServer.SetListFilterItem(List, "WorkcenterType", CurRow.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure ListResourcesKindsOnActivateRow(Item)
	
	UpdateResourcesList();
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	FontPredefined = StyleFonts.FontDialogAndMenu;
	
	// ListResourcesKinds
	
	ItemAppearance = ListResourcesKinds.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Predefined");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= True;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Font", FontPredefined);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Description");
	FieldAppearance.Use = True;
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		ProcessPreparedData(ImportResult);
		
		If ImportResult.DataLoadSettings.FillingObjectFullName = "Catalog.CompanyResourceTypes" Then
			Items.ListResourcesKinds.Refresh();
		ElsIf ImportResult.DataLoadSettings.FillingObjectFullName = "Catalog.CompanyResources" Then
			Items.ResourcesList.Refresh();
		EndIf;
		
		ShowMessageBox(Undefined, NStr("en = 'Data import is complete.'; ru = 'Загрузка данных завершена.';pl = 'Pobieranie danych zakończone.';es_ES = 'Importación de datos se ha finalizado.';es_CO = 'Importación de datos se ha finalizado.';tr = 'Veri içe aktarımı tamamlandı.';it = 'L''importazione dei dati è stata completata.';de = 'Der Datenimport ist abgeschlossen.'"));
		
	ElsIf ImportResult = Undefined Then
		
		Items.ListResourcesKinds.Refresh();
		Items.ResourcesList.Refresh();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult);
	
EndProcedure

#EndRegion
