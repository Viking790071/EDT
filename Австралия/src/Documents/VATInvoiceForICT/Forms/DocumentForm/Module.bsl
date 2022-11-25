
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(
		Metadata.Documents.VATInvoiceForICT.TabularSections.Inventory, DataLoadSettings, ThisObject);
	DataImportFromExternalSources.OnCreateAtServer(
		Metadata.Documents.VATInvoiceForICT.TabularSections.InventoryDestination, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ProcessingCompanyVATNumbers();
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
	SetVisibleAndEnabled();
	
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

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CalculationParameters = New Structure;
	
	CalculationParameters.Insert("TabularSectionName", "Inventory");
	WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject, CalculationParameters);
	
	CalculationParameters.Insert("TabularSectionName", "InventoryDestination");
	WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject, CalculationParameters);
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(False);
	EndIf;

EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	CompanyOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure BasisDocumentOnChange(Item)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		Object.DocumentCurrency = PredefinedValue("Catalog.Currencies.EmptyRef");
		Return;
	EndIf;
	
	Object.DocumentCurrency = GetBasisDocumentCurrency(Object.BasisDocument);
	
EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True, "Inventory");
	EndIf;
	
EndProcedure

&AtClient
Procedure StructuralUnitDestinationOnChange(Item)
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True, "InventoryDestination");
	EndIf;

EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	CalculateVATAmountTotal(TabularSectionRow, Object.AmountIncludesVAT, True);
	
EndProcedure

&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	CalculateVATAmountTotal(TabularSectionRow, Object.AmountIncludesVAT, False);
	
EndProcedure

&AtClient
Procedure InventoryDestinationVATRateOnChange(Item)
	
	TabularSectionRow = Items.InventoryDestination.CurrentData;
	CalculateVATAmountTotal(TabularSectionRow, Object.AmountIncludesVAT, True);
	
EndProcedure

&AtClient
Procedure InventoryDestinationVATAmountOnChange(Item)
	
	TabularSectionRow = Items.InventoryDestination.CurrentData;
	CalculateVATAmountTotal(TabularSectionRow, Object.AmountIncludesVAT, False);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		MessagesToUserClient.ShowMessageSelectBaseDocument();
		Return;
	EndIf;
	
	Response = Undefined;
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'Do you want to refill the VAT invoice?'; ru = 'Налоговый инвойс будет перезаполнен по основанию. Продолжить?';pl = 'Czy chcesz uzupełnić fakturę VAT?';es_ES = '¿Quiere volver a rellenar la factura de IVA?';es_CO = '¿Quiere volver a rellenar la factura de IVA?';tr = 'KDV faturası yeniden doldurulsun mu?';it = 'Ricompilare la fattura IVA?';de = 'Möchten Sie die USt.-Rechnung wieder auffüllen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.Yes Then
		
		FillByDocument(Object.BasisDocument);
		
		SetVisibleAndEnabled();
		
	EndIf;
	
EndProcedure

#EndRegion

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

#EndRegion

#Region Private

&AtClient
Procedure Attachable_ProcessDateChange()
	
	DateOnChangeAtServer();
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Procedure DateOnChangeAtServer()
	ProcessingCompanyVATNumbers();
EndProcedure

&AtServer
Procedure CompanyOnChangeAtServer()
	
	If UseDefaultTypeOfAccounting Then
		FillAddedColumns(True);
	EndIf;
	
	ProcessingCompanyVATNumbers(False);
	
EndProcedure

&AtServerNoContext
Function GetBasisDocumentCurrency(BasisDocument)
	Return Common.ObjectAttributeValue(BasisDocument, "DocumentCurrency");	
EndFunction

&AtServer
Procedure SetVisibleAndEnabled()
	
	NewParameter = New ChoiceParameter("Filter.Status", Enums.InventoryOwnershipTypes.OwnInventory);
	NewArray = New Array();
	NewArray.Add(NewParameter);
	NewParameters = New FixedArray(NewArray);
	
	Items.InventoryBatch.ChoiceParameters = NewParameters;
	
	Items.InventoryGLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.InventoryDestinationGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	Fields.Add(Items.InventoryDestinationPrice);
	
	Return Fields;
	
EndFunction

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.DestinationVATNumber, FillOnlyEmpty);
	
EndProcedure

&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
EndProcedure

&AtClientAtServerNoContext
Procedure CalculateVATAmountTotal(TabularSectionRow, AmountIncludesVAT, CalculateVATAmount, VATRate = Undefined)
	
	If CalculateVATAmount Then
		
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
		TabularSectionRow.VATAmount = ?(AmountIncludesVAT, 
			TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
			TabularSectionRow.Amount * VATRate / 100);
		
	EndIf;
		
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False, TableName = "")
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	If IsBlankString(TableName) Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Inventory");
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Inventory");
		
		StructureArray.Add(StructureData);
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "InventoryDestination");
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "InventoryDestination");
		
		StructureArray.Add(StructureData);
		
	Else
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, TableName);
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, TableName);
		
		StructureArray.Add(StructureData);
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion
