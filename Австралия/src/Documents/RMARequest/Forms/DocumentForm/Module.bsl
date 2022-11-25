#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	SetWarrantyPeriod(Object.Equipment);
	
	SetInvoiceDate(Object.Invoice);
	
	SetSerialNumberEnable();
	SetCharacteristicEnable();
	
	// Setting contract visible.
	SetContractVisible();
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
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
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
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

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CompanyOnChange(Item)
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	
	ProcessContractChange();
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
		
		CounterpartyData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company);
		
		Object.Contract			= CounterpartyData.Contract;
		Object.ContactPerson	= CounterpartyData.ContactPerson;
		
		ProcessContractChange();
		
		If Not ValueIsFilled(Object.Location) Then
			
			DeliveryData = GetDeliveryData(Object.Counterparty);
			
			If DeliveryData.ShippingAddress <> Undefined Then
				Object.Location = DeliveryData.ShippingAddress;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

&AtClient
Procedure InvoiceOnChange(Item)
	
	SetInvoiceDate(Object.Invoice);
	
	SetInWarrantyAttribute();
	
EndProcedure

&AtClient
Procedure EquipmentOnChange(Item)
	
	SetWarrantyPeriod(Object.Equipment);
	SetInWarrantyAttribute();
	SetSerialNumberEnable();
	SetCharacteristicEnable();
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure InvoiceStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	StructureFilter = New Structure();
	StructureFilter.Insert("Company", Object.Company);
	
	FilterArray = New Array;
	FilterArray.Add(Object.Counterparty);
	FilterArray.Add(PredefinedValue("Catalog.Counterparties.EmptyRef"));
	
	StructureFilter.Insert("Counterparty", FilterArray);
	
	If ValueIsFilled(Object.Contract) Then
		
		ContractFilterArray = New Array;
		ContractFilterArray.Add(Object.Contract);
		ContractFilterArray.Add(PredefinedValue("Catalog.CounterpartyContracts.EmptyRef"));
		
		StructureFilter.Insert("Contract", ContractFilterArray);
		
	EndIf;
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("Filter", StructureFilter);
	ParameterStructure.Insert("Product", Object.Equipment);
	ParameterStructure.Insert("Characteristic", Object.Characteristic);
	ParameterStructure.Insert("SerialNumber", Object.SerialNumber);
	
	OpenForm("CommonForm.SelectDocumentInvoice", ParameterStructure, Item);
	
EndProcedure

&AtClient
Procedure InvoiceChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(SelectedValue) = Type("Structure") Then
		
		Object.Invoice = SelectedValue.Document;
		SetInvoiceDate(Object.Invoice);
		SetInWarrantyAttribute();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SerialNumberOnChange(Item)
	
	SerialNumberOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetContractVisible()
	
	Items.Contract.Visible = CounterpartyAttributes.DoOperationsByContracts;
	
EndProcedure

&AtServer
Function GetDataCounterpartyOnChange(Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	StructureData = New Structure();
	StructureData.Insert("Contract", ContractByDefault);
	
	ContactPerson = Catalogs.ContactPersons.GetDefaultContactPerson(Object.Counterparty);
	StructureData.Insert("ContactPerson", ContactPerson);
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure ProcessContractChange()
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		If CounterpartyAttributes.DoOperationsByContracts And ValueIsFilled(Object.Contract) Then
			
			ShippingAddress = GetContractShippingAddress(Object.Contract);
			
			If ValueIsFilled(ShippingAddress) And ShippingAddress <> Object.Location Then
				
				Object.Location = ShippingAddress;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetContractShippingAddress(Contract)
	
	Return Common.ObjectAttributeValue(Contract, "ShippingAddress");
	
EndFunction

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company);
	
EndFunction

&AtServerNoContext
Function GetDeliveryData(Counterparty)
	
	Return ShippingAddressesServer.GetDeliveryDataForCounterparty(Counterparty, False);
	
EndFunction

&AtServer
Procedure SetWarrantyPeriod(EquipmentRef)
	
	If ValueIsFilled(EquipmentRef) Then
		
		WarrantyPeriod = Common.ObjectAttributeValue(EquipmentRef, "GuaranteePeriod");
		
	Else
		
		WarrantyPeriod = 0;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetInvoiceDate(InvoiceRef)
	
	If ValueIsFilled(InvoiceRef) Then
		
		InvoiceDate = BegOfDay(Common.ObjectAttributeValue(InvoiceRef, "Date"));
		
	Else
		
		InvoiceDate = Date(1,1,1);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	SetInWarrantyAttribute();
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Procedure SetInWarrantyAttribute()
	
	WarrantyDate = DriveServer.AddInterval(InvoiceDate, Enums.Periodicity.Month, WarrantyPeriod);
	
	Object.InWarranty = (WarrantyDate >= BegOfDay(Object.Date));
	
EndProcedure

&AtServer
Procedure SetSerialNumberEnable()
	
	If ValueIsFilled(Object.Equipment) Then
		UseSerialNumbers = Common.ObjectAttributeValue(Object.Equipment, "UseSerialNumbers");
	Else
		UseSerialNumbers = False;
	EndIf;
	
	Items.SerialNumber.Enabled = UseSerialNumbers;
	
	If UseSerialNumbers Then
		Items.SerialNumber.InputHint = "";
	Else
		Items.SerialNumber.InputHint = NStr("en = '<not use>'; ru = '<Не используется>';pl = '<nie używaj>';es_ES = '<no se usa>';es_CO = '<no se usa>';tr = '<kullanmayın>';it = '<non utilizzato>';de = '<nicht verwendet>'");
	EndIf;
	
EndProcedure

&AtServer
Procedure SetCharacteristicEnable()
	
	If ValueIsFilled(Object.Equipment) Then
		UseCharacteristics = Common.ObjectAttributeValue(Object.Equipment, "UseCharacteristics");
	Else
		UseCharacteristics = False;
	EndIf;
	
	Items.Characteristic.Enabled = UseCharacteristics;
	
	If UseCharacteristics Then
		Items.Characteristic.InputHint = "";
	Else
		Items.Characteristic.InputHint = NStr("en = '<not use>'; ru = '<Не используется>';pl = '<nie używaj>';es_ES = '<no se usa>';es_CO = '<no se usa>';tr = '<kullanmayın>';it = '<non utilizzato>';de = '<nicht verwendet>'");
	EndIf;
	
EndProcedure

&AtServer
Procedure SerialNumberOnChangeAtServer()
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref
	|INTO SalesDocument
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Company = &Company
	|	AND SalesInvoice.Counterparty = &Counterparty
	|	AND SalesInvoice.Contract = &Contract
	|
	|UNION ALL
	|
	|SELECT
	|	SalesSlip.Ref
	|FROM
	|	Document.SalesSlip AS SalesSlip
	|WHERE
	|	SalesSlip.Company = &Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	SalesDocument.Ref AS Invoice
	|FROM
	|	SalesDocument AS SalesDocument
	|		INNER JOIN Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|			INNER JOIN Catalog.Products AS CatalogProducts
	|			ON SalesInvoiceInventory.Products = CatalogProducts.Ref
	|		ON SalesDocument.Ref = SalesInvoiceInventory.Ref
	|		INNER JOIN Document.SalesInvoice.SerialNumbers AS SalesInvoiceSerialNumbers
	|		ON SalesDocument.Ref = SalesInvoiceSerialNumbers.Ref
	|WHERE
	|	SalesInvoiceInventory.Products = &Product
	|	AND (NOT CatalogProducts.UseCharacteristics
	|			OR SalesInvoiceInventory.Characteristic = &Characteristic)
	|	AND (NOT CatalogProducts.UseSerialNumbers
	|			OR SalesInvoiceSerialNumbers.SerialNumber = &SerialNumber)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	SalesDocument.Ref
	|FROM
	|	SalesDocument AS SalesDocument
	|		INNER JOIN Document.SalesSlip.Inventory AS SalesSlipInventory
	|			INNER JOIN Catalog.Products AS CatalogProducts
	|			ON SalesSlipInventory.Products = CatalogProducts.Ref
	|		ON SalesDocument.Ref = SalesSlipInventory.Ref
	|		INNER JOIN Document.SalesSlip.SerialNumbers AS SalesSlipSerialNumbers
	|		ON SalesDocument.Ref = SalesSlipSerialNumbers.Ref
	|WHERE
	|	SalesSlipInventory.Products = &Product
	|	AND (NOT CatalogProducts.UseCharacteristics
	|			OR SalesSlipInventory.Characteristic = &Characteristic)
	|	AND (NOT CatalogProducts.UseSerialNumbers
	|			OR SalesSlipSerialNumbers.SerialNumber = &SerialNumber)";
	
	Query.SetParameter("Company", Object.Company);
	Query.SetParameter("Counterparty", Object.Counterparty);
	Query.SetParameter("Contract", Object.Contract);
	Query.SetParameter("Product", Object.Equipment);
	Query.SetParameter("Characteristic", Object.Characteristic);
	Query.SetParameter("SerialNumber", Object.SerialNumber);
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		ResultTable = QueryResult.Unload();
		
		If ResultTable.Count() = 1 Then
			
			Object.Invoice = ResultTable[0].Invoice;
			SetInvoiceDate(Object.Invoice);
			SetInWarrantyAttribute();
			
		EndIf;
		
	EndIf;
	
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
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure

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

#EndRegion