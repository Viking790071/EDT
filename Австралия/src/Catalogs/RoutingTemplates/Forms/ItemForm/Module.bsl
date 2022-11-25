#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.RoutingTemplates.TabularSections.Operations,
		DataLoadSettings,
		ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource

	Items.OperationsDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
		
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	ProductionPlanningClientServer.CheckTableOfRouting(Object.Operations, Cancel, , "Routing");
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region OperationsFormTableItemsEventHandlers

&AtClient
Procedure OperationsActivityNumberOnChange(Item)
	
	Row = Item.Parent.CurrentData;
	Row.NextActivityNumber = Row.ActivityNumber + 1;
	
EndProcedure

&AtClient
Procedure OperationsOnActivateRow(Item)
	
	Row = Item.CurrentData;
	If Row = Undefined Then
		Return;
	EndIf;
	
	If Row.ActivityNumber <> 0 Then
		Return;
	EndIf;
	
	For Each Operation In Object.Operations Do
		If Operation.ActivityNumber > Row.ActivityNumber Then
			Row.ActivityNumber = Operation.ActivityNumber;
		EndIf;
	EndDo;
	Row.ActivityNumber = Row.ActivityNumber + 1;
	
	For Each Operation In Object.Operations Do
		If Operation.ActivityNumber = Row.ActivityNumber - 1
			And Operation.NextActivityNumber = 0 Then
			Operation.NextActivityNumber = Row.ActivityNumber;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SortOperations(Command)
	
	Object.Operations.Sort("ActivityNumber");
	
EndProcedure

#EndRegion

#Region Private

#Region DataImportFromExternalSources

&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"RoutingTemplates.Operations");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import products from file'; ru = 'Загрузка запасов из файла';pl = 'Importuj produkty z pliku';es_ES = 'Importar los productos del archivo';es_CO = 'Importar los productos del archivo';tr = 'Ürünleri dosyadan içe aktar';it = 'Importazione articoli da file';de = 'Produkte aus Datei importieren'"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
		
EndProcedure

#EndRegion

#EndRegion
