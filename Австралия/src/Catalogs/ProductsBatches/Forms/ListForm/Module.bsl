
&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Owner") Then
		
		Products = Parameters.Filter.Owner;
		
		If Not ValueIsFilled(Products)
			OR Not Products.ProductsType = Enums.ProductsTypes.InventoryItem Then
			
			AutoTitle = False;
			Title = NStr("en = 'Batches are stored for inventories only'; ru = 'Партии хранятся только для запасов';pl = 'Partie są przechowywane tylko dla zapasów';es_ES = 'Lotes se almacenan solo para inventarios';es_CO = 'Lotes se almacenan solo para inventarios';tr = 'Partiler yalnızca stoklar için saklanır';it = 'I lotti sono registrati solo per inventario';de = 'Chargen werden nur für Lagerbestände gespeichert'");
			
			Items.List.ReadOnly = True;
			
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.ProductsBatches, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.SearchAndDeleteDuplicates

&AtClient
Procedure MergeSelected(Command)
	FindAndDeleteDuplicatesDuplicatesClient.MergeSelectedItems(Items.List);
EndProcedure

&AtClient
Procedure ShowUsage(Command)
	FindAndDeleteDuplicatesDuplicatesClient.ShowUsageInstances(Items.List);
EndProcedure

// End StandardSubsystems.SearchAndDeleteDuplicates

// StandardSubsystems.DataImportFromExternalSources

&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TemplateNameWithTemplate",	"LoadFromFile");
	DataLoadSettings.Insert("SelectionRowDescription",	New Structure("FullMetadataObjectName, Type", "ProductsBatches", "AppliedImport"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		ProcessPreparedData(ImportResult);
		Items.List.Refresh();
		ShowMessageBox(,NStr("en = 'Data import is completed.'; ru = 'Загрузка данных завершена.';pl = 'Import danych został zakończony.';es_ES = 'Importación de datos se ha finalizado.';es_CO = 'Importación de datos se ha finalizado.';tr = 'Veri içe aktarımı tamamlandı.';it = 'L''importazione dei dati è stata completata.';de = 'Der Datenimport ist abgeschlossen.'"));
		
	ElsIf ImportResult = Undefined Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult);
	
EndProcedure

// End StandardSubsystems.DataImportFromExternalSource

#EndRegion
