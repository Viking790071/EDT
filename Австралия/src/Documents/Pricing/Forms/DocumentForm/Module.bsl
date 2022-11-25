#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If NOT ValueIsFilled(Object.Ref) Then
		
		If Parameters.Property("Date") Then
			Object.Date = Parameters.Date;
			DocumentDate = Object.Date;
		Else
			DocumentDate = CurrentSessionDate();
		EndIf;
		
		If Parameters.Property("PriceKind") Then
			Object.PriceKind = Parameters.PriceKind;
		EndIf;
		
		If Parameters.Property("Author") Then
			Object.Author = Parameters.Author;
		EndIf;
		
		If Parameters.Property("InventoryAddress") Then
			
			TableInventory = GetFromTempStorage(Parameters.InventoryAddress);
			For Each Row In TableInventory Do
				NewRow = Object.Inventory.Add();
				FillPropertyValues(NewRow, Row);
			EndDo;
			
		EndIf;
		
		If Parameters.Property("ProductsArray") Then
			
			If Not ValueIsFilled(Object.PriceKind) Then
				Object.PriceKind = DriveReUse.GetValueOfSetting("MainPriceTypesales");
			EndIf;
			
			Object.PricePeriod = CurrentSessionDate();
			
			For Each Products In Parameters.ProductsArray Do
				
				NewRow = Object.Inventory.Add();
				NewRow.Products = Products;
				NewRow.MeasurementUnit = Common.ObjectAttributeValue(NewRow.Products, "MeasurementUnit")
				
			EndDo;
			
			If ValueIsFilled(Object.PriceKind) Then
				
				DataStructure = New Structure;
				DataStructure.Insert("PriceKind", Object.PriceKind);
				DataStructure.Insert("Date", Object.PricePeriod);
				DataStructure.Insert("DocumentCurrency", Common.ObjectAttributeValue(Object.PriceKind, "PriceCurrency"));
				DataStructure.Insert("Company", DriveReUse.GetUserDefaultCompany());
				DriveServer.GetTabularSectionPricesByPriceKind(DataStructure, Object.Inventory);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.Pricing.TabularSections.Inventory, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	Items.InventoryDataImportFromExternalSources.Visible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If Object.Posted Then
		ProductsArray = ProductsArray();
		Notify("PriceChanged", ProductsArray);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	TabularSectionRow.MeasurementUnit = GetProductsMeasurementUnit(TabularSectionRow.Products);
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function GetProductsMeasurementUnit(Products)
	
	MeasurementUnit = Catalogs.UOMClassifier.EmptyRef();
	
	If ValueIsFilled(Products) Then
		MeasurementUnit = Common.ObjectAttributeValue(Products, "MeasurementUnit");
	EndIf;
	
	Return MeasurementUnit;
	
EndFunction

&AtServer
Function ProductsArray()
	
	ProductsArray = Object.Inventory.Unload().UnloadColumn("Products");
	
	Return ProductsArray;
	
EndFunction

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
	
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	
	AttachableCommands.ExecuteCommand(ThisObject, Context, Object, Result);
	
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	
EndProcedure
// End StandardSubsystems.AttachableCommands

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFile(Command)
	
	DataLoadSettings.Insert("TabularSectionFullName",	"Pricing.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import prices from file'; ru = 'Загрузить цены из файла';pl = 'Importuj ceny z pliku';es_ES = 'Importar precios desde el archivo';es_CO = 'Importar precios desde el archivo';tr = 'Fiyatları dosyadan içe aktar';it = 'Importa prezzi da file';de = 'Preise aus Datei importieren'"));
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	
	Return Fields;
	
EndFunction

#EndRegion

#EndRegion

#EndRegion