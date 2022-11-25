
#Region FormEventHandlers

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Company = Object.Company;
	If Object.CounterpartyAndContractPosition = Enums.AttributeStationing.InHeader Then
		Counterparty = Object.Counterparty;
		Contract = Object.Contract;
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ReadCompanyAttributes(PresentationCurrency, Company);
	
	SetVisibleFromUserSettings();
	
	DriveClientServer.SetPictureForComment(Items.GroupPageAdditionalInformation, Object.Comment);
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer (ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.ActualSalesVolume.TabularSections.Inventory,
		DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetContractChoiceParameters();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CounterpartyOnChange(Item)
	
	If Counterparty <> Object.Counterparty Then
		
		Counterparty = Object.Counterparty;
		
		StructureData = GetDataCounterpartyOnChange(Object.Ref,
			Object.Counterparty, Object.Company, PresentationCurrency);
		Object.Contract = StructureData.Contract;
		Contract = Object.Contract;
		
	Else
		
		Object.Contract = Contract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	Contract = Object.Contract;
	
EndProcedure

&AtClient
Procedure DeliveryStartDateOnChange(Item)
	
	If ValueIsFilled(Object.DeliveryStartDate) And ValueIsFilled(Object.DeliveryEndDate)
		And Object.DeliveryStartDate > Object.DeliveryEndDate Then
		Object.DeliveryEndDate = Object.DeliveryStartDate;
	EndIf;
	
EndProcedure

&AtClient
Procedure DeliveryEndDateOnChange(Item)
	
	If ValueIsFilled(Object.DeliveryStartDate) And ValueIsFilled(Object.DeliveryEndDate)
		And Object.DeliveryStartDate > Object.DeliveryEndDate Then
		Object.DeliveryStartDate = Object.DeliveryEndDate;
	EndIf;
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	If Company <> Object.Company Then
		
		Company = Object.Company;
		ReadCompanyAttributes(PresentationCurrency, Company);
		
		If Object.CounterpartyAndContractPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
			Object.Contract = GetContractByDefault(Object.Ref, Counterparty, Company, PresentationCurrency);
			Contract = Object.Contract;
		Else
			For Each CurRowData In Object.Inventory Do
				CurRowData.Contract = GetContractByDefault(Object.Ref, CurRowData.Counterparty, Company, PresentationCurrency);
			EndDo;
			CurRowData = Items.Inventory.CurrentData;
			If CurRowData <> Undefined Then
				Contract = CurRowData.Contract;
			EndIf;
		EndIf;
		
		SetContractChoiceParameters();
		
	Else
		
		Object.Contract = Contract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

#EndRegion

#Region InventoryFormTableItemsEventHandlers

&AtClient
Procedure InventoryOnActivateRow(Item)
	
	If Object.CounterpartyAndContractPosition = PredefinedValue("Enum.AttributeStationing.InTabularSection") Then
		
		CurRowData = Item.CurrentData;
		If CurRowData <> Undefined Then
			Counterparty = CurRowData.Counterparty;
			Contract = CurRowData.Contract;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryCounterpartyOnChange(Item)
	
	CurRowData = Items.Inventory.CurrentData;
	
	If Counterparty <> CurRowData.Counterparty Then
		
		Counterparty = CurRowData.Counterparty;
		
		StructureData = GetDataCounterpartyOnChange(Object.Ref,
			CurRowData.Counterparty, Object.Company, PresentationCurrency);
		CurRowData.Contract = StructureData.Contract;
		Contract = CurRowData.Contract;
		
	Else
		
		CurRowData.Contract = Contract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryContractOnChange(Item)
	
	CurRowData = Items.Inventory.CurrentData;
	Contract = CurRowData.Contract;
	
EndProcedure

&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company"				, Object.Company);
	StructureData.Insert("Products"				, TabularSectionRow.Products);
	StructureData.Insert("Characteristic"		, TabularSectionRow.Characteristic);
	StructureData.Insert("Batch"				, TabularSectionRow.Batch);
	
	StructureData = GetDataProductsOnChange(StructureData, Object.Date);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	
	If TabularSectionRow.Quantity = 0 Then
		TabularSectionRow.Quantity = 1;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryProductsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Item.Parent.CurrentData;
	
	ParametersFormProducts = New Structure;
	
	If ValueIsFilled(Object.Company) Then
		ParametersFormProducts.Insert("FilterBalancesCompany", Object.Company);
	EndIf;
	
	Filter = New Structure("ProductsType", PredefinedValue("Enum.ProductsTypes.Service"));
	ParametersFormProducts.Insert("Filter", Filter);
	
	ChoiceHandler = New NotifyDescription("InventoryProductsStartChoiceEnd", 
		ThisObject, 
		New Structure("CurrentData, Item", CurrentData, Item));
	
	OpenForm("Catalog.Products.ChoiceForm", 
		ParametersFormProducts,
		ThisObject,
		, , , 
		ChoiceHandler, 
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SelectDeliveryPeriod(Command)
	
	Handler = New NotifyDescription("SelectPeriodCompletion", ThisObject);
	
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = New StandardPeriod(Object.DeliveryStartDate, Object.DeliveryEndDate);
	Dialog.Show(Handler);
	
EndProcedure

&AtClient
Procedure DocumentSetup(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("CounterpartyAndContractPositionInActualSalesVolume",
		Object.CounterpartyAndContractPosition);
	ParametersStructure.Insert("WereMadeChanges", False);
	
	InvCount = Object.Inventory.Count();
	If InvCount > 1 Then
		CurrCounterparty = Object.Inventory[0].Counterparty;
		CurrContract = Object.Inventory[0].Contract;
		MultipleValues = False;
		For Index = 1 To InvCount - 1 Do
			If CurrCounterparty <> Object.Inventory[Index].Counterparty
				Or CurrContract <> Object.Inventory[Index].Contract Then
				MultipleValues = True;
				Break;
			EndIf;
		EndDo;
		If MultipleValues Then
			ParametersStructure.Insert("ReadOnly", True);
		EndIf;
	EndIf;
	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure
// End StandardSubsystems.Properties

#EndRegion

#Region Private

&AtClient
Procedure SelectPeriodCompletion(Period, PeriodParameters) Export
	
	If TypeOf(Period) <> Type("StandardPeriod") Then
		Return;
	EndIf;
	
	If ValueIsFilled(Period.StartDate) And ValueIsFilled(Period.EndDate) And Period.StartDate > Period.EndDate Then
		Period.EndDate = Period.StartDate;
	EndIf;
	
	Object.DeliveryStartDate = Period.StartDate;
	Object.DeliveryEndDate = Period.EndDate;
	
EndProcedure

&AtServerNoContext
Function GetDataProductsOnChange(StructureData, ObjectDate = Undefined)
	
	If StructureData.Property("Characteristic")
		And ValueIsFilled(StructureData.Characteristic)
		And Common.ObjectAttributeValue(StructureData.Characteristic, "Owner") <> StructureData.Products Then
		
		StructureData.Characteristic = Catalogs.ProductsCharacteristics.EmptyRef();
		
	EndIf;
	
	If StructureData.Property("Batch")
		And ValueIsFilled(StructureData.Batch)
		And Common.ObjectAttributeValue(StructureData.Batch, "Owner") <> StructureData.Products Then
		
		StructureData.Batch = Catalogs.ProductsBatches.EmptyRef();
		
	EndIf;
	
	ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products, "MeasurementUnit");
	
	StructureData.Insert("MeasurementUnit", ProductsAttributes.MeasurementUnit);
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure InventoryProductsStartChoiceEnd(ResultValue, AdditionalParameters) Export
	
	If ResultValue = Undefined Then
		Return;
	EndIf;
	
	AdditionalParameters.CurrentData.Products = ResultValue;
	
	InventoryProductsOnChange(AdditionalParameters.Item);
	
EndProcedure

&AtServer
Procedure SetVisibleFromUserSettings()
	
	VisibleValue = (Object.CounterpartyAndContractPosition = PredefinedValue("Enum.AttributeStationing.InHeader"));
	
	Items.Counterparty.Visible = VisibleValue;
	Items.Contract.Visible = VisibleValue;
	
	Items.InventoryCounterparty.Visible = Not VisibleValue;
	Items.InventoryContract.Visible = Not VisibleValue;
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	If TypeOf(StructureDocumentSetting) = Type("Structure") And StructureDocumentSetting.WereMadeChanges Then
		
		Object.CounterpartyAndContractPosition = StructureDocumentSetting.CounterpartyAndContractPositionInActualSalesVolume;
		If Object.CounterpartyAndContractPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
			
			If Object.Inventory.Count() > 0 Then
				FirstRow = Object.Inventory[0];
				Object.Counterparty = FirstRow.Counterparty;
				Object.Contract = FirstRow.Contract;
			EndIf;
			
		ElsIf Object.CounterpartyAndContractPosition = PredefinedValue("Enum.AttributeStationing.InTabularSection") Then
			
			For Each InventoryRow In Object.Inventory Do
				InventoryRow.Counterparty = Object.Counterparty;
				InventoryRow.Contract = Object.Contract;
			EndDo;
			Object.Counterparty = Undefined;
			Object.Contract = Undefined;
			
		EndIf;
		
		SetVisibleFromUserSettings();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetContractChoiceParameters()
	
	ChoiceParameter = New ChoiceParameter("Filter.SettlementsCurrency", PresentationCurrency);
	ChoiceParametersArray = New Array;
	ChoiceParametersArray.Add(ChoiceParameter);
	Items.Contract.ChoiceParameters = New FixedArray(ChoiceParametersArray);
	Items.InventoryContract.ChoiceParameters = New FixedArray(ChoiceParametersArray);
	
EndProcedure

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, Currency)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company, Undefined, "", Currency);
	
EndFunction

&AtServerNoContext
Function GetDataCounterpartyOnChange(Ref, Counterparty, Company, Currency)
	
	ContractByDefault = GetContractByDefault(Ref, Counterparty, Company, Currency);
	
	StructureData = New Structure;
	StructureData.Insert("Contract", ContractByDefault);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Procedure ReadCompanyAttributes(PresentationCurrency, Val CatalogCompany)
	
	PresentationCurrency = Common.ObjectAttributeValue(CatalogCompany, "PresentationCurrency");
	
EndProcedure

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

// StandardSubsystems.Properties

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
	
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileInventory(Command)
	
	DataLoadSettings.Insert("TabularSectionFullName",	"ActualSalesVolume.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import inventory from file'; ru = 'Загрузить номенклатуру из файла';pl = 'Import zapasów z pliku';es_ES = 'Importar el inventario del archivo';es_CO = 'Importar el inventario del archivo';tr = 'Stoku dosyadan içe aktar';it = 'Importare inventario da file';de = 'Bestand aus Datei importieren'"));
	
	DataLoadSettings.Insert("CounterpartyAndContractPositionInTabularSection", 
		(Object.CounterpartyAndContractPosition = PredefinedValue("Enum.AttributeStationing.InTabularSection")));
	DocumentAttributes = New Structure;
	DocumentAttributes.Insert("Company", Company);
	DataLoadSettings.Insert("DocumentAttributes", DocumentAttributes);
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

#EndRegion

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupPageAdditionalInformation, Object.Comment);
	
EndProcedure

#EndRegion