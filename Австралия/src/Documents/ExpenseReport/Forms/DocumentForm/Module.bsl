
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf ChoiceSource.FormName = "Catalog.Employees.Form.EmployeeGLAccounts" Then
		EmployeeGLAccountsChoiceProcessing(SelectedValue);
	EndIf;
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
// The procedure implements
// - form attribute initialization,
// - setting of the form functional options parameters.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed);
	
	FunctionalCurrency = Constants.FunctionalCurrency.Get();
	
	If Parameters.Key.IsEmpty() Then
		
		If Not ValueIsFilled(Object.DocumentCurrency) Then
			Object.DocumentCurrency = FunctionalCurrency;
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	Policy = GetAccountingPolicyValues(DocumentDate, ParentCompany);
	PerInvoiceVATRoundingRule = Policy.PerInvoiceVATRoundingRule;
	RegisteredForVAT = Policy.RegisteredForVAT;
	
	CompanyAttributesStructure = Common.ObjectAttributesValues(Object.Company, "PresentationCurrency, ExchangeRateMethod");
	PresentationCurrency = CompanyAttributesStructure.PresentationCurrency;
	ExchangeRateMethod = CompanyAttributesStructure.ExchangeRateMethod;
	StructureByCurrency = GetDataCurrencyRateRepetition(Object.Date, PresentationCurrency, Object.Company);
	RatePresentationCurrency = StructureByCurrency.Rate;
	RepetitionPresentationCurrency = StructureByCurrency.Repetition;
	
	If Not ValueIsFilled(Object.Ref)
		And Not ValueIsFilled(Parameters.Basis) 
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByVATTaxation();
	Else
		SetPropertiesOfItemsByVATTaxation();
	EndIf;
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	GenerateLabelPricesAndCurrency(ThisObject);
	
	ProcessingCompanyVATNumbers();
	
	User = Users.CurrentUser();
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
	MainWarehouse = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainWarehouse);
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
	Items.InventoryInventoryPick.Visible = AccessRight("Read", Metadata.AccumulationRegisters.Inventory);
	Items.ExpensesExpensesSelection.Visible = AccessRight("Read", Metadata.AccumulationRegisters.Inventory);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillExpenses", True);
	ParametersStructure.Insert("FillPayments", True);
	
	FillAddedColumns(ParametersStructure);
	
	StructureForFilling = EmployeeGLAccountsStructure(Object);
	GLAccounts = GetEmployeeGLAccountsDescription(StructureForFilling);
	
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(ThisObject, "ExpensesRegisterExpense");
	
	// Filling in the additional attributes of tabular section.
	SetAccountsAttributesVisible();
	
	DriveClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
	DriveServer.OverrideStandartGenerateTaxInvoiceReceivedCommand(ThisObject);
	
	SetFormConditionalAppearance();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.ExpenseReport.TabularSections.Inventory, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	Items.InventoryDataImportFromExternalSources.Visible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	Items.BasisDocument.Visible = ValueIsFilled(Object.BasisDocument);
	
	DriveServer.CheckObjectGeneratedEnteringBalances(ThisObject);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
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
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillExpenses", True);
	ParametersStructure.Insert("FillPayments", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	TabularSectionNames = New Array;
	TabularSectionNames.Add("Inventory");
	TabularSectionNames.Add("Expenses");
	CalculationParameters = New Structure;
	CalculationParameters.Insert("TabularSectionNames", TabularSectionNames);
	WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject, CalculationParameters);
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	SetVisibleOnCurrencyChange();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisObject, "BarCodeScanner");
	// End Peripherals
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company,PricesFields());
	// Prices precision end
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	// Notification of payment.
	NotifyAboutOrderPayment = False;
	
	For Each CurRow In Object.Payments Do
		NotifyAboutOrderPayment = ?(
			NotifyAboutOrderPayment,
			NotifyAboutOrderPayment,
			ValueIsFilled(CurRow.Order));
	EndDo;
	
	If NotifyAboutOrderPayment Then
		Notify("NotificationAboutOrderPayment");
	EndIf;
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillExpenses", True);
	ParametersStructure.Insert("FillPayments", True);
	
	FillAddedColumns(ParametersStructure);
	
	// Filling in the additional attributes of tabular section.
	SetAccountsAttributesVisible();
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			// Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;
			
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
	If EventName = "AfterRecordingOfCounterparty" 
		AND ValueIsFilled(Parameter) Then
			
		For Each CurRow In Object.Payments Do
			
			If Parameter = CurRow.Counterparty Then
				
				ReadCounterpartyAttributes(CounterpartyAttributes, CurRow.Counterparty);
				
				SetAccountsAttributesVisible();
				Break;
				
			EndIf;
			
		EndDo;
			
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company, Object.Date);
	ParentCompany = StructureData.ParentCompany;
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	PresentationCurrency = StructureData.PresentationCurrency;
	ExchangeRateMethod = StructureData.ExchangeRateMethod;
	RatePresentationCurrency = StructureData.PresentationCurrencyRateRepetition.Rate;
	RepetitionPresentationCurrency = StructureData.PresentationCurrencyRateRepetition.Repetition;
	
	PerInvoiceVATRoundingRule = StructureData.PerInvoiceVATRoundingRule;
	SetAutomaticVATCalculation();
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	SetVisibleOnCurrencyChange();
	
	For Each RowInventory In Object.Inventory Do
		CalculateRowTotalPresentationCur(RowInventory);
	EndDo;
	
	For Each RowExpense In Object.Expenses Do
		CalculateRowTotalPresentationCur(RowExpense);
	EndDo;
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

&AtClient
Procedure EmployeeOnChange(Item)
	
	EmployeeOnChangeAtServer();
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
EndProcedure

&AtClient
Procedure GLAccountsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not ReadOnly Then
		LockFormDataForEdit();
	EndIf;
	
	FormParameters = EmployeeGLAccountsStructure(Object);
	FormParameters.Insert("Employee", Object.Employee);
	
	OpenForm("Catalog.Employees.Form.EmployeeGLAccounts", FormParameters, ThisObject);
	
EndProcedure

// Procedure - EditDocumentCurrency command handler.
//
&AtClient
Procedure EditDocumentCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonEditCurrency(Object.DocumentCurrency);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAdvancesPaid

// Procedure - SelectionStart event handler of the Document input field.
//
&AtClient
Procedure AdvancesPaidDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	StructureFilter = New Structure();
	StructureFilter.Insert("Company", Object.Company);
	StructureFilter.Insert("AdvanceHolder", Object.Employee);
	StructureFilter.Insert("Currency", Object.DocumentCurrency);
	
	OpenForm("CommonForm.SelectDocumentPayment", New Structure("Filter", StructureFilter), Item);
	
EndProcedure

&AtClient
Procedure IssuedAdvancesDocumentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.AdvancesPaid.CurrentData;
	
	If TypeOf(SelectedValue) = Type("Structure") And TabularSectionRow <> Undefined Then
		
		TabularSectionRow.Document = SelectedValue.Document;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersInventory

// Procedure - OnStartEdit event handler of the Inventory list string.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		TabularSectionRow = Items.Inventory.CurrentData;
		TabularSectionRow.StructuralUnit = MainWarehouse;
		TabularSectionRow.ExchangeRate = ?(Object.ExchangeRate = 0, 1, Object.ExchangeRate);
		TabularSectionRow.Multiplicity = ?(Object.Multiplicity = 0, 1, Object.Multiplicity);
	EndIf;
	
	ThisIsNewRow = NewRow;
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("Object", Object);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("StructuralUnit", TabularSectionRow.StructuralUnit);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Inventory", StructureData, TabularSectionRow);
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData);
	
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Content = "";
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure

// Procedure - event handler AutoPick of the Content input field.
//
&AtClient
Procedure InventoryContentAutoComplete(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow = Items.Inventory.CurrentData;
		ContentPattern = DriveServer.GetContentText(TabularSectionRow.Products, TabularSectionRow.Characteristic);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure InventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
	 OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	// Price.
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure InventoryDeductibleTaxOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow <> Undefined Then
		ClearSupplierWithDeductibleTaxOff(TabularSectionRow)
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateRowTotalPresentationCur(TabularSectionRow);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateRowTotalPresentationCur(TabularSectionRow);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
	ClearDeductibleTaxByVATRate(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateRowTotalPresentationCur(TabularSectionRow);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

&AtClient
Procedure InventoryExchangeRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateRowTotalPresentationCur(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure InventoryMultiplicityOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateRowTotalPresentationCur(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure InventoryTotalPresentationCurOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateExchRate(TabularSectionRow);
	
	TabularSectionRow.VATAmountPresentationCur = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.VATAmount,
		ExchangeRateMethod,
		TabularSectionRow.ExchangeRate,
		RatePresentationCurrency,
		TabularSectionRow.Multiplicity,
		RepetitionPresentationCurrency,
		PricesPrecision);
	
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, Items.Inventory.CurrentRow, "Inventory");
	
EndProcedure

&AtClient
Procedure InventoryStructuralUnitOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("Object", Object);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("StructuralUnit", TabularSectionRow.StructuralUnit);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Inventory", StructureData, TabularSectionRow);
		StructureData = GetDataStructuralUnitOnChange(StructureData);
	EndIf;
	
	FillPropertyValues(TabularSectionRow, StructureData);
	
EndProcedure

// Procedure - event handler AfterDeletion of the Inventory list row.
//
&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - event handler OnEditEnd of the Inventory list row.
//
&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnEditEnd(ThisIsNewRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnActivateCell(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Inventory.CurrentItem;
		If TableCurrentColumn.Name = "InventoryGLAccounts" And Not CurrentData.GLAccountsFilled Then
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, Items.Inventory.CurrentRow, "Inventory");
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersExpenses

// Procedure - event handler OnStartEdit of the Expenses list row.
//
&AtClient
Procedure ExpensesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		TabularSectionRow = Items.Expenses.CurrentData;
		TabularSectionRow.StructuralUnit = MainDepartment;
		TabularSectionRow.ExchangeRate = ?(Object.ExchangeRate = 0, 1, Object.ExchangeRate);
		TabularSectionRow.Multiplicity = ?(Object.Multiplicity = 0, 1, Object.Multiplicity);
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	
EndProcedure

&AtClient
Procedure ExpensesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ExpensesGLAccounts" Then
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Expenses");
	ElsIf Field.Name = "ExpensesIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Expenses");
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesOnActivateCell(Item)
	
	CurrentData = Items.Expenses.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Expenses.CurrentItem;
		If TableCurrentColumn.Name = "ExpensesGLAccounts" And Not CurrentData.GLAccountsFilled Then
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, Items.Expenses.CurrentRow, "Expenses");
		ElsIf TableCurrentColumn.Name = "ExpensesIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			
			SelectedRow = Items.Expenses.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Expenses");
		EndIf;
	EndIf;

EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure ExpensesProductsOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("TabName", "Expenses");
	StructureData.Insert("Object", Object);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("StructuralUnit", TabularSectionRow.StructuralUnit);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	StructureData.Insert("IncomeAndExpenseItems", TabularSectionRow.IncomeAndExpenseItems);
	StructureData.Insert("IncomeAndExpenseItemsFilled", TabularSectionRow.IncomeAndExpenseItemsFilled);
	StructureData.Insert("ExpenseItem", TabularSectionRow.ExpenseItem);
	StructureData.Insert("RegisterExpense", TabularSectionRow.RegisterExpense);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Expenses", StructureData, TabularSectionRow);
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData);
	
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Content = "";
	
	If StructureData.ClearOrderAndDepartment Then
		TabularSectionRow.StructuralUnit = Undefined;
		TabularSectionRow.SalesOrder = Undefined;
	EndIf;
	
	If StructureData.ClearBusinessLine Then
		TabularSectionRow.BusinessLine = Undefined;
	EndIf;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure

// Procedure - event handler AutoPick of the Content input field.
//
&AtClient
Procedure CostsContentAutoComplete(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow = Items.Expenses.CurrentData;
		ContentPattern = DriveServer.GetContentText(TabularSectionRow.Products);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure ExpensesQuantityOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure ExpensesMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
		OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	// Price.
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure ExpensesPriceOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure AmountExpensesOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateRowTotalPresentationCur(TabularSectionRow);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure ExpensesVATRateOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateRowTotalPresentationCur(TabularSectionRow);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
	ClearDeductibleTaxByVATRate(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure AmountExpensesVATOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateRowTotalPresentationCur(TabularSectionRow);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

&AtClient
Procedure ExpensesExchangeRateOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateRowTotalPresentationCur(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure ExpensesMultiplicityOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateRowTotalPresentationCur(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure ExpensesTotalPresentationCurOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateExchRate(TabularSectionRow);
	
	TabularSectionRow.VATAmountPresentationCur = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.VATAmount,
		ExchangeRateMethod,
		TabularSectionRow.ExchangeRate,
		RatePresentationCurrency,
		TabularSectionRow.Multiplicity,
		RepetitionPresentationCurrency,
		PricesPrecision);
	
EndProcedure

&AtClient
Procedure ExpensesStructuralUnitOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("TabName", "Expenses");
	StructureData.Insert("Object", Object);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("StructuralUnit", TabularSectionRow.StructuralUnit);
	StructureData.Insert("ExpenseItem", TabularSectionRow.ExpenseItem);
	StructureData.Insert("RegisterExpense", TabularSectionRow.RegisterExpense);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Expenses", StructureData, TabularSectionRow);
		StructureData = GetDataStructuralUnitOnChange(StructureData);
	EndIf;
	
	FillPropertyValues(TabularSectionRow, StructureData);
	
EndProcedure

&AtClient
Procedure ExpensesDeductibleTaxOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	If TabularSectionRow <> Undefined Then
		ClearSupplierWithDeductibleTaxOff(TabularSectionRow)
	EndIf;
	
EndProcedure

// Procedure - SelectionStart event handler of the ExpensesBusinessLine input field.
//
&AtClient
Procedure ExpensesBusinessLineStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = GetDataBusinessLineStartChoice(TabularSectionRow.ExpenseItem);
	
	If Not StructureData.AvailabilityOfPointingLinesOfBusiness Then
		ShowMessageBox(, NStr("en = 'Business area is not required for this type of expense.'; ru = 'Для данного расхода направление деятельности не указывается!';pl = 'Dla tego typu rozchodów rodzaj działalności nie jest wymagany.';es_ES = 'No se requiere el área de negocio para este tipo de gasto.';es_CO = 'No se requiere el área de negocio para este tipo de gasto.';tr = 'Bu tür harcamalar için iş alanı gerekli değildir.';it = 'L''area di Business non è richiesta per questo tipo di spesa.';de = 'Der Geschäftsbereich wird für diese Art von Aufwand nicht benötigt.'"));
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler SelectionStart of input field Order.
//
Procedure ExpensesOrderStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = GetDataOrderStartChoice(TabularSectionRow.ExpenseItem);
	
	If Not StructureData.AbilityToSpecifyOrder Then
		ShowMessageBox(, NStr("en = 'The order is not specified for this type of expense.'; ru = 'Для этого расхода заказ не указывается!';pl = 'Dla tego rodzaju kosztów nie określa się zamówienia.';es_ES = 'El orden no está especificado para este tipo de gasto.';es_CO = 'El orden no está especificado para este tipo de gasto.';tr = 'Bu harcama türü için sipariş belirtilmemiş.';it = 'L''ordine non è specificato per questo tipo di spesa.';de = 'Der Auftrag ist für diese Art von Kosten nicht angegeben.'"));
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, Items.Expenses.CurrentRow, "Expenses");
	
EndProcedure

&AtClient
Procedure ExpensesIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Expenses", StandardProcessing);
	
EndProcedure

// Procedure - event handler OnEditEnd of the Expenses list row.
//
&AtClient
Procedure ExpensesOnEditEnd(Item, NewRow, CancelEdit)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnEditEnd(ThisIsNewRow);
	EndIf;
	
EndProcedure

// Procedure - event handler AfterDeletion of the Expenses list row.
//
&AtClient
Procedure ExpensesAfterDeleteRow(Item)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

&AtClient
Procedure ExpensesRegisterExpenseOnChange(Item)
	
	CurData = Items.Expenses.CurrentData;
	If CurData <> Undefined Then
		If Not CurData.RegisterExpense Then
			CurData.ExpenseItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
			
			ParametersStructure = New Structure;
			ParametersStructure.Insert("GetGLAccounts", True);
			ParametersStructure.Insert("FillInventory", False);
			ParametersStructure.Insert("FillExpenses", True);
			ParametersStructure.Insert("FillPayments", False);
			
			FillAddedColumns(ParametersStructure);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPayments

// The OnChange event handler of the CounterpartyPayment field.
// It updates the contract currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure PaymentsCounterpartyOnChange(Item)
	
	TabularSectionRow = Items.Payments.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("TabName", "Payments");
	StructureData.Insert("Object", Object);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Payments", StructureData, TabularSectionRow);
	EndIf;
	
	FillDataCounterpartyOnChange(StructureData);
	FillPropertyValues(TabularSectionRow, StructureData);
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	ContractCurrencyRates = StructureData.ContractCurrencyRateRepetition;
	TabularSectionRow.ExchangeRate = ContractCurrencyRates.Rate;
	TabularSectionRow.Multiplicity = ContractCurrencyRates.Repetition;
	
	CalculatePaymentSettlementsAmount(TabularSectionRow);
	
EndProcedure

// The OnChange event handler of the PaymentContract field.
// It updates the contract currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure PaymentsContractOnChange(Item)
	
	TabularSectionRow = Items.Payments.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("TabName", "Payments");
	StructureData.Insert("Object", Object);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Payments", StructureData, TabularSectionRow);
	EndIf;
	
	If ValueIsFilled(TabularSectionRow.Contract) Then
		
		GetPaymentDataContractOnChange(StructureData);
		ContractCurrencyRates = StructureData.ContractCurrencyRateRepetition;
		TabularSectionRow.ExchangeRate = ContractCurrencyRates.Rate;
		TabularSectionRow.Multiplicity = ContractCurrencyRates.Repetition;
		
		FillPropertyValues(TabularSectionRow, StructureData);
		
	ElsIf UseDefaultTypeOfAccounting Then
		
		TabularSectionRow.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
		
	EndIf;
	
	CalculatePaymentSettlementsAmount(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of the PaymentsSettlementKind input field.
// Clears an attribute document if a settlement type is - "Advance".
//
&AtClient
Procedure PaymentsAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.Payments.CurrentData;
	
	If TabularSectionRow.AdvanceFlag Then
		TabularSectionRow.Document = Undefined;
	EndIf;
	
EndProcedure

// Procedure - SelectionStart event handler of the PaymentDocument input field.
// Passes the current attribute value to the parameters.
//
&AtClient
Procedure PaymentsDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Payments.CurrentData;
	
	If TabularSectionRow.AdvanceFlag Then
		ShowMessageBox(, NStr("en = 'The current document is a billing document in case of advance payment.'; ru = 'Данный документ является документом расчетов для авансовых платежей.';pl = 'Obecny dokument jest dokumentem rozliczeniowym w przypadku zaliczki.';es_ES = 'El documento actual es documento de facturación en caso del pago anticipado.';es_CO = 'El documento actual es documento de facturación en caso del pago anticipado.';tr = 'Geçerli belge, avans ödeme durumunda faturalama belgesidir.';it = 'Il documebto corrente è un documento di fatturazione in caso di pagamento anticipato.';de = 'Der aktuelle Beleg ist im Falle einer Vorauszahlung ein Abrechnungsbeleg.'"));
		StandardProcessing = False;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the PaymentsSettlementAmount field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentsSettlementsAmountOnChange(Item)
	
	TabularSectionRow = Items.Payments.CurrentData;
	If Not TabularSectionRow.SettlementsAmount = 0 Then
		TabularSectionRow.ExchangeRate = TabularSectionRow.PaymentAmount * Object.ExchangeRate * TabularSectionRow.Multiplicity
			/ (TabularSectionRow.SettlementsAmount * Object.Multiplicity);
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the PaymentRate input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentsExchangeRateOnChange(Item)
	
	CalculatePaymentSettlementsAmount(Items.Payments.CurrentData);
	
EndProcedure

// Procedure - OnChange event handler of the PaymentsRatio input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentsMultiplicityOnChange(Item)
	
	CalculatePaymentSettlementsAmount(Items.Payments.CurrentData);
	
EndProcedure

// The OnChange event handler of the PaymentPaymentAmount field.
// It updates the payment currency exchange rate and exchange rate multiplier, and also the VAT amount.
//
&AtClient
Procedure PaymentsPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.Payments.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.PaymentAmount,
		ExchangeRateMethod,
		Object.ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Object.Multiplicity,
		TabularSectionRow.Multiplicity,
		PricesPrecision);
		
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - event handler AfterDeletion of the Payments list row.
//
&AtClient
Procedure PaymentsAfterDeleteRow(Item)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	SetAccountsAttributesVisible();
	
EndProcedure

&AtClient
Procedure PaymentsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableSelection(ThisObject, "Payments", SelectedRow, Field, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentsOnActivateCell(Item)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnActivateCell(ThisObject, "Payments", ThisIsNewRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentsOnStartEdit(Item, NewRow, Clone)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentsOnEditEnd(Item, NewRow, CancelEdit)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnEditEnd(ThisIsNewRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentsGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	GLAccountsInDocumentsClient.GLAccountsStartChoice(ThisObject, "Payments", StandardProcessing);  
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'expense claim'; ru = 'Авансовый отчет';pl = 'raport rozchodów';es_ES = 'reclamación de gastos';es_CO = 'reclamación de gastos';tr = 'masraf raporu';it = 'richiesta di spese';de = 'Kostenabrechnung'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject,
		TabularSectionName, DocumentPresentaion, True, False, False);
	SelectionParameters.Insert("Company", Counterparty);
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject);
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure ExpensesPick(Command)
	
	TabularSectionName	= "Expenses";
	DocumentPresentaion	= NStr("en = 'expense claim'; ru = 'Авансовый отчет';pl = 'raport rozchodów';es_ES = 'reclamación de gastos';es_CO = 'reclamación de gastos';tr = 'masraf raporu';it = 'richiesta di spese';de = 'Kostenabrechnung'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, False, False);
	SelectionParameters.Insert("Company", Counterparty);
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject);
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure AdvancesPick(Command)
	
	AddressAdvancesPaidInStorage = PlaceAdvancesPaidToStorage();
	
	SelectionParameters = New Structure(
		"AddressAdvancesPaidInStorage,
		|ParentCompany,
		|Period,
		|Employee,
		|DocumentCurrency,
		|Refs",
		AddressAdvancesPaidInStorage,
		ParentCompany,
		Object.Date,
		Object.Employee,
		Object.DocumentCurrency,
		Object.Ref);
	
	Result = Undefined;
	
	NotifyDescription = New NotifyDescription("AdvancesFilterEnd",
		ThisObject,
		New Structure("AddressAdvancesPaidInStorage", AddressAdvancesPaidInStorage));
	OpenForm("CommonForm.SelectAdvancesIssuedToTheAdvanceHolder",
		SelectionParameters, , , , ,
		NotifyDescription);
	
EndProcedure

&AtClient
Procedure FillAdvancesWithBalances(Command)
	
	FillAdvancesAtServer();
	
EndProcedure

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)),
		CurBarcode, 
		NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));

EndProcedure

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en = 'Select a line for which the weight should be received.'; ru = 'Необходимо выбрать строку, для которой необходимо получить вес.';pl = 'Wybierz wiersz, dla którego trzeba uzyskać wagę.';es_ES = 'Seleccionar una línea para la cual el peso tienen que recibirse.';es_CO = 'Seleccionar una línea para la cual el peso tienen que recibirse.';tr = 'Ağırlığın alınması gereken bir satır seçin.';it = 'Selezionare una linea dove il peso deve essere ricevuto';de = 'Wählen Sie eine Zeile, für die das Gewicht empfangen werden soll.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NotifyDescription, UUID);
		
	EndIf;
	
EndProcedure

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure

&AtClient
Procedure Attachable_GenerateTaxInvoiceReceived(Command)
	
	If Modified And Not Write() Then
		Return;
	EndIf;
	
	DriveClient.TaxInvoiceReceivedGenerationBasedOnExpenseReport(Object.Ref);
	
EndProcedure

#EndRegion

#Region Private

#Region GLAccounts

&AtClientAtServerNoContext
Procedure AddGLAccountsToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
	
	If StructureData.TabName = "Payments" Then
		StructureData.Insert("CounterpartyGLAccounts", True);
		StructureData.Insert("Counterparty", TabRow.Counterparty);
		StructureData.Insert("Contract", TabRow.Contract);
		StructureData.Insert("VATTaxation", PredefinedValue("Enum.VATTaxationTypes.EmptyRef"));
		StructureData.Insert("AccountsPayableGLAccount", TabRow.AccountsPayableGLAccount);
		StructureData.Insert("AdvancesPaidGLAccount", TabRow.AdvancesPaidGLAccount);
	Else
		StructureData.Insert("ProductGLAccounts", True);
		StructureData.Insert("InventoryGLAccount",	TabRow.InventoryGLAccount);
		StructureData.Insert("VATInputGLAccount",	TabRow.VATInputGLAccount);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting Then
		
		If ParametersStructure.FillInventory Then
			
			StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
			GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
			StructureArray.Add(StructureData);
			
		EndIf;
		
		If ParametersStructure.FillPayments Then
			
			StructureData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Payments");
			GLAccountsInDocuments.CompleteCounterpartyStructureData(StructureData, ObjectParameters, "Payments");
			StructureArray.Add(StructureData);
			
		EndIf;
		
	EndIf;
	
	If ParametersStructure.FillExpenses Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Expenses");
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Expenses");
		StructureArray.Add(StructureData);
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
EndProcedure

&AtClient
Procedure EmployeeGLAccountsChoiceProcessing(StructureData);
	
	FillPropertyValues(Object, StructureData);
	
	GLAccounts = GetEmployeeGLAccountsDescription(StructureData);
	
EndProcedure

&AtServerNoContext
Function GetEmployeeGLAccountsDescription(StructureData)
	
	GLAccountsInDocumentsServerCall.GetGLAccountsDescription(StructureData);
	
	Return StructureData.GLAccounts;
	
EndFunction

&AtClientAtServerNoContext
Function EmployeeGLAccountsStructure(DocObject)
	
	StructureData = New Structure("AdvanceHoldersReceivableGLAccount, AdvanceHoldersPayableGLAccount");
	
	FillPropertyValues(StructureData, DocObject);
	
	Return StructureData;
	
EndFunction

#EndRegion

// Procedure sets visible of calculation attributes depending on the parameters specified to the counterparty.
//
&AtServer
Procedure SetAccountsAttributesVisible(Val DoOperationsByContracts = False, Val DoOperationsByOrders = False)
	
	FillServiceAttributesByCounterpartyInCollection(Object.Payments);
	
	For Each CurRow In Object.Payments Do
		If CurRow.DoOperationsByContracts Then
			DoOperationsByContracts = True;
		EndIf;
		If CurRow.DoOperationsByOrders Then
			DoOperationsByOrders = True;
		EndIf;
	EndDo;
	
	Items.PaymentContract.Visible = DoOperationsByContracts;
	Items.PaymentSchedule.Visible = DoOperationsByOrders;
	
	Items.GLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.InventoryGLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.ExpensesGLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.PaymentsGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
EndProcedure

// The function moves the AdvancesPaid tabular section
// to the temporary storage and returns the address
//
&AtServer
Function PlaceAdvancesPaidToStorage()
	
	AdvancesTable = Object.AdvancesPaid.Unload( ,"Document, Amount");
	AdvancesTable.Columns.Add("Currency", New TypeDescription("CatalogRef.Currencies"));
	AdvancesTable.FillValues(Object.DocumentCurrency, "Currency");
	
	Return PutToTempStorage(AdvancesTable, UUID);
	
EndFunction

// Peripherals
// Procedure gets data by barcodes.
//
&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	// Transform weight barcodes.
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		InformationRegisters.Barcodes.ConvertWeightBarcode(CurBarcode);
		
	EndDo;
	
	DataByBarCodes = InformationRegisters.Barcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined And BarcodeData.Count() <> 0 Then
			
			StructureProductsData = New Structure();
			StructureProductsData.Insert("Company", StructureData.Company);
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsData.Insert("VATTaxation", StructureData.VATTaxation);
			StructureProductsData.Insert("UseDefaultTypeOfAccounting", StructureData.UseDefaultTypeOfAccounting);
			
			If StructureData.UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(StructureProductsData, StructureData.Object, "ExpenseReport");
			EndIf;
			
			BarcodeData.Insert("StructureProductsData", GetDataProductsOnChange(StructureProductsData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.Products.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure

// Procedure processes the received barcodes.
//
&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("Object", Object);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined And BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			SearchStructure = New Structure("Products,Characteristic,Batch,MeasurementUnit");
			FillPropertyValues(SearchStructure, BarcodeData);
			TSRowsArray = Object.Inventory.FindRows(SearchStructure);
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit),
					BarcodeData.MeasurementUnit, 
					BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.ExchangeRate = ?(Object.ExchangeRate = 0, 1, Object.ExchangeRate);
				NewRow.Multiplicity = ?(Object.Multiplicity = 0, 1, Object.Multiplicity);
				CalculateAmountInTabularSectionLine(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(FoundString);
				Items.Inventory.CurrentRow = FoundString.GetID();
			EndIf;
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;
	
EndFunction

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisObject, UnknownBarcodes);
		
		OpenForm("InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes),
			ThisObject, , , ,
			Notification);
		
		Return;
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement In ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement In ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		UnknownBarcodes = FillByBarcodesData(BarcodesArray);
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Barcode data is not found: %1; quantity: %2'; ru = 'Данные по штрихкоду не найдены: %1; количество: %2';pl = 'Nie znaleziono danych kodu kreskowego: %1; ilość: %2';es_ES = 'Datos del código de barras no encontrados: %1; cantidad: %2';es_CO = 'Datos del código de barras no encontrados: %1; cantidad: %2';tr = 'Barkod verisi bulunamadı: %1; miktar: %2';it = 'Il codice a barre non è stato trovato per: %1; quantità: %2';de = 'Barcode-Daten wurden nicht gefunden: %1; Menge: %2'"),
			CurUndefinedBarcode.Barcode,
			CurUndefinedBarcode.Quantity);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure
// End Peripherals

// The function receives the AdvancesPaid tabular section from the temporary storage.
//
&AtServer
Procedure GetAdvancesPaidFromStorage(AddressAdvancesPaidInStorage)
	
	TableAdvancesPaid = GetFromTempStorage(AddressAdvancesPaidInStorage);
	Object.AdvancesPaid.Clear();
	For Each StringAdvancesPaid In TableAdvancesPaid Do
		String = Object.AdvancesPaid.Add();
		FillPropertyValues(String, StringAdvancesPaid);
	EndDo;
	
EndProcedure

// The procedure calculates the rate and ratio of
// the document currency when changing the document date.
//
&AtClient
Procedure RecalculateRateRepetitionOfDocumentCurrency(StructureData)
	
	CurrencyRateRepetition = StructureData.CurrencyRateRepetition;
	
	NewExchangeRate	= ?(CurrencyRateRepetition.Rate = 0, 1, CurrencyRateRepetition.Rate);
	NewRatio		= ?(CurrencyRateRepetition.Repetition = 0, 1, CurrencyRateRepetition.Repetition);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio Then
		
		QuestionText = NStr("en = 'The document date has changed.
							|Do you want to apply the new exchange rate?'; 
							|ru = 'Дата документа была изменена.
							|Пересчитать курсы валют?';
							|pl = 'Data dokumentu uległa zmianie.
							|Czy chcesz zastosować nowy kurs wymiany walut na tą datę?';
							|es_ES = 'La fecha del documento ha sido cambiada.
							|¿Quiere aplicar el nuevo tipo de cambio?';
							|es_CO = 'La fecha del documento ha sido cambiada.
							|¿Quiere aplicar el nuevo tipo de cambio?';
							|tr = 'Belge tarihi değişti.
							|Yeni döviz kurunu uygulamak ister misiniz?';
							|it = 'La data del documento è cambiata.
							|Volete applicare il nuovo tasso di cambio?';
							|de = 'Das Belegdatum hat sich geändert.
							|Möchten Sie den neuen Wechselkurs verwenden?'");
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewExchangeRate",	NewExchangeRate);
		AdditionalParameters.Insert("NewRatio",			NewRatio);
		
		NotifyDescription = New NotifyDescription("CalculateRateDocumentCurrencyRatioEnd", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		Return;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateRateDocumentCurrencyRatioEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		
		For Each RowPayment In Object.Payments Do
			CalculatePaymentSettlementsAmount(RowPayment, False);
		EndDo;
		
		For Each RowInventory In Object.Inventory Do
			RowInventory.ExchangeRate = Object.ExchangeRate;
			RowInventory.Multiplicity = Object.Multiplicity;
			CalculateRowTotalPresentationCur(RowInventory);
		EndDo;
		
		For Each RowExpense In Object.Expenses Do
			RowExpense.ExchangeRate = Object.ExchangeRate;
			RowExpense.Multiplicity = Object.Multiplicity;
			CalculateRowTotalPresentationCur(RowExpense);
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
&AtClient
Procedure ProcessChangesOnButtonEditCurrency(Val DocumentCurrencyBeforeChange)
	
	ParametersStructure = New Structure();
	ParametersStructure.Insert("Company",				 	 Object.Company);
	ParametersStructure.Insert("DocumentDate",				 Object.Date);
	ParametersStructure.Insert("Company",					 ParentCompany);
	ParametersStructure.Insert("DocumentCurrency",			 Object.DocumentCurrency);
	ParametersStructure.Insert("VATTaxation",				 Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",			 Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",			 Object.IncludeVATInPrice);
	ParametersStructure.Insert("RecalculatePrices",			 False);
	ParametersStructure.Insert("ReverseChargeNotApplicable", True);
	ParametersStructure.Insert("AutomaticVATCalculation",	 Object.AutomaticVATCalculation);
	ParametersStructure.Insert("PerInvoiceVATRoundingRule",	 PerInvoiceVATRoundingRule);
	
	NotifyDescription = New NotifyDescription("ProcessChangesOnEditCurrencyButtonEnd",
		ThisObject,
		New Structure("DocumentCurrencyBeforeChange", DocumentCurrencyBeforeChange));
	
	OpenForm("CommonForm.PricesAndCurrency",
		ParametersStructure,
		ThisObject,,,,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ProcessChangesOnEditCurrencyButtonEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) <> Type("Structure") Or Not ClosingResult.WereMadeChanges Then
		Return;
	EndIf;
	
	DocCurRecalcStructure = New Structure;
	DocCurRecalcStructure.Insert("DocumentCurrency", ClosingResult.DocumentCurrency);
	DocCurRecalcStructure.Insert("PrevDocumentCurrency", AdditionalParameters.DocumentCurrencyBeforeChange);
	
	FillPropertyValues(Object, ClosingResult, , "ExchangeRate, Multiplicity");
	
	// Clearing the tabular section of the issued advances.
	If AdditionalParameters.DocumentCurrencyBeforeChange <> ClosingResult.DocumentCurrency Then
		
		Object.AdvancesPaid.Clear();
		
		CurrencyRateRepetition = New Structure("Rate, Repetition", ClosingResult.ExchangeRate, ClosingResult.Multiplicity);
		
		RecalculateRateRepetitionOfDocumentCurrency(New Structure("CurrencyRateRepetition", CurrencyRateRepetition));
		
		SetVisibleOnCurrencyChange();
		
	EndIf;
	
	// Recalculate prices by currency.
	If ClosingResult.RecalculatePrices Then
		DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Inventory", PricesPrecision);
		DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Expenses", PricesPrecision);
	EndIf;
	
	// Recalculate the amount if VAT taxation flag is changed.
	If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
	// Recalculate the amount if the "Amount includes VAT" flag is changed.
	If Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
		DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Inventory", PricesPrecision);
		DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Expenses", PricesPrecision);
	EndIf;
	
	For Each RowPayment In Object.Payments Do
		CalculatePaymentSettlementsAmount(RowPayment, False);
	EndDo;
	
	For Each RowInventory In Object.Inventory Do
		CalculateRowTotalPresentationCur(RowInventory);
	EndDo;
	
	For Each RowExpense In Object.Expenses Do
		CalculateRowTotalPresentationCur(RowExpense);
	EndDo;
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
	Modified = True;
	
	// Generate price and currency label.
	GenerateLabelPricesAndCurrency(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateLabelPricesAndCurrency(Form)
	
	Object = Form.Object;
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("AmountIncludesVAT",			Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	Form.ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation",				Object.VATTaxation);
	
	Form.DocumentCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

// VAT amount is calculated in the row of tabular section.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
		TabularSectionRow.Amount * VATRate / 100);
		
EndProcedure

&AtClientAtServerNoContext
Procedure ClearDeductibleTaxByVATRate(TabularSectionRow)
	
	If TabularSectionRow.VATRate = PredefinedValue("Catalog.VATRates.Exempt") Then
		TabularSectionRow.DeductibleTax = False;
		TabularSectionRow.Supplier = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculatePaymentSettlementsAmount(TabularSectionRow, CalculateSpentTotalAmount = True)
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.PaymentAmount,
		ExchangeRateMethod,
		Object.ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Object.Multiplicity,
		TabularSectionRow.Multiplicity,
		PricesPrecision);
		
	If CalculateSpentTotalAmount Then
		SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	EndIf;
		
EndProcedure

&AtClient
Procedure CalculateRowTotalPresentationCur(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.TotalPresentationCur = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.Total,
		ExchangeRateMethod,
		TabularSectionRow.ExchangeRate,
		RatePresentationCurrency,
		TabularSectionRow.Multiplicity,
		RepetitionPresentationCurrency,
		PricesPrecision);
	
	TabularSectionRow.VATAmountPresentationCur = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.VATAmount,
		ExchangeRateMethod,
		TabularSectionRow.ExchangeRate,
		RatePresentationCurrency,
		TabularSectionRow.Multiplicity,
		RepetitionPresentationCurrency,
		PricesPrecision);
	
EndProcedure

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateRowTotalPresentationCur(TabularSectionRow);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

&AtClient
Procedure CalculateExchRate(TabularSectionRow)
	
	If TabularSectionRow.Total = TabularSectionRow.TotalPresentationCur
		Or TabularSectionRow.Total = 0
		Or TabularSectionRow.TotalPresentationCur = 0 Then
		TabularSectionRow.ExchangeRate = 1;
		Return;
	EndIf;
	
	If ExchangeRateMethod = PredefinedValue("Enum.ExchangeRateMethods.Divisor") Then 
		TabularSectionRow.ExchangeRate = Round(TabularSectionRow.Total / TabularSectionRow.TotalPresentationCur, 4);
	ElsIf ExchangeRateMethod = PredefinedValue("Enum.ExchangeRateMethods.Multiplier") Then	
		TabularSectionRow.ExchangeRate = Round(TabularSectionRow.TotalPresentationCur / TabularSectionRow.Total, 4);
	Else
		TabularSectionRow.ExchangeRate = 1;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange(Object.Ref, Object.Date, Object.DocumentCurrency, Object.Company);
	
	RatePresentationCurrency = StructureData.PresentationCurrencyRateRepetition.Rate;
	RepetitionPresentationCurrency = StructureData.PresentationCurrencyRateRepetition.Repetition;
	
	PerInvoiceVATRoundingRule = StructureData.PerInvoiceVATRoundingRule;
	SetAutomaticVATCalculation();
	
	If ValueIsFilled(Object.DocumentCurrency) Then
		RecalculateRateRepetitionOfDocumentCurrency(StructureData);
	EndIf;
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	DocumentDate = Object.Date;
	
EndProcedure

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetDataDateOnChange(DocumentRef, DateNew, DocumentCurrency, Company)
	
	CurrencyRateRepetition = GetDataCurrencyRateRepetition(DateNew, DocumentCurrency, Company);
	PresentationCurrencyRateRepetition = GetDataCurrencyRateRepetition(DateNew, PresentationCurrency, Company);
	Policy = GetAccountingPolicyValues(DateNew, Company);
	
	RegisteredForVAT = Policy.RegisteredForVAT;
	
	ProcessingCompanyVATNumbers();
	FillVATRateByCompanyVATTaxation();
	
	StructureData = New Structure();
	StructureData.Insert("CurrencyRateRepetition", CurrencyRateRepetition);
	StructureData.Insert("PerInvoiceVATRoundingRule", Policy.PerInvoiceVATRoundingRule);
	StructureData.Insert("PresentationCurrencyRateRepetition", PresentationCurrencyRateRepetition);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataCurrencyRateRepetition(Date, Currency, Company)
	Return CurrencyRateOperations.GetCurrencyRate(Date, Currency, Company);
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange(Company, Date)
	
	Policy = GetAccountingPolicyValues(Date, Company);
	AttributesStructure = Common.ObjectAttributesValues(Company, "PresentationCurrency, ExchangeRateMethod");
	PresentationCurrencyRateRepetition = GetDataCurrencyRateRepetition(
		Date,
		AttributesStructure.PresentationCurrency,
		Company);
	
	StructureData = New Structure();
	StructureData.Insert("ParentCompany", DriveServer.GetCompany(Company));
	StructureData.Insert("PerInvoiceVATRoundingRule", Policy.PerInvoiceVATRoundingRule);
	StructureData.Insert("PresentationCurrencyRateRepetition", PresentationCurrencyRateRepetition);
	StructureData.Insert("PresentationCurrency", AttributesStructure.PresentationCurrency);
	StructureData.Insert("ExchangeRateMethod", AttributesStructure.ExchangeRateMethod);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillExpenses", True);
	ParametersStructure.Insert("FillPayments", True);
	
	FillAddedColumns(ParametersStructure);
	
	RegisteredForVAT = Policy.RegisteredForVAT;
	
	ProcessingCompanyVATNumbers(False);
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure EmployeeOnChangeAtServer()
	
	DocumentObject = FormAttributeToValue("Object");
	DocumentObject.FillInEmployeeGLAccounts();
	ValueToFormAttribute(DocumentObject, "Object");
	
	If UseDefaultTypeOfAccounting Then
		StructureForFilling = EmployeeGLAccountsStructure(Object);
		GLAccounts = GetEmployeeGLAccountsDescription(StructureForFilling);
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure FillAdvancesAtServer()
	
	Query = New Query();
	Query.Text =
	"SELECT ALLOWED
	|	AdvanceHoldersBalances.DocumentDate AS DocumentDate,
	|	AdvanceHoldersBalances.Document AS Document,
	|	SUM(AdvanceHoldersBalances.AmountCurBalance) AS Amount
	|FROM
	|	(SELECT
	|		CASE
	|			WHEN AdvanceHoldersBalances.Document REFS Document.ExpenseReport
	|				THEN CAST(AdvanceHoldersBalances.Document AS Document.ExpenseReport).Date
	|			WHEN AdvanceHoldersBalances.Document REFS Document.PaymentExpense
	|				THEN CAST(AdvanceHoldersBalances.Document AS Document.PaymentExpense).Date
	|			WHEN AdvanceHoldersBalances.Document REFS Document.PaymentReceipt
	|				THEN CAST(AdvanceHoldersBalances.Document AS Document.PaymentReceipt).Date
	|			WHEN AdvanceHoldersBalances.Document REFS Document.CashReceipt
	|				THEN CAST(AdvanceHoldersBalances.Document AS Document.CashReceipt).Date
	|			WHEN AdvanceHoldersBalances.Document REFS Document.CashVoucher
	|				THEN CAST(AdvanceHoldersBalances.Document AS Document.CashVoucher).Date
	|		END AS DocumentDate,
	|		AdvanceHoldersBalances.Document AS Document,
	|		ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AdvanceHolders.Balance(
	|				,
	|				Currency = &DocumentCurrency
	|					AND Company = &Company
	|					AND Employee = &Employee) AS AdvanceHoldersBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CASE
	|			WHEN DocumentRegisterRecordsAdvanceHolders.Document REFS Document.ExpenseReport
	|				THEN CAST(DocumentRegisterRecordsAdvanceHolders.Document AS Document.ExpenseReport).Date
	|			WHEN DocumentRegisterRecordsAdvanceHolders.Document REFS Document.PaymentExpense
	|				THEN CAST(DocumentRegisterRecordsAdvanceHolders.Document AS Document.PaymentExpense).Date
	|			WHEN DocumentRegisterRecordsAdvanceHolders.Document REFS Document.PaymentReceipt
	|				THEN CAST(DocumentRegisterRecordsAdvanceHolders.Document AS Document.PaymentReceipt).Date
	|			WHEN DocumentRegisterRecordsAdvanceHolders.Document REFS Document.CashReceipt
	|				THEN CAST(DocumentRegisterRecordsAdvanceHolders.Document AS Document.CashReceipt).Date
	|			WHEN DocumentRegisterRecordsAdvanceHolders.Document REFS Document.CashVoucher
	|				THEN CAST(DocumentRegisterRecordsAdvanceHolders.Document AS Document.CashVoucher).Date
	|		END,
	|		DocumentRegisterRecordsAdvanceHolders.Document,
	|		CASE
	|			WHEN DocumentRegisterRecordsAdvanceHolders.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsAdvanceHolders.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsAdvanceHolders.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AdvanceHolders AS DocumentRegisterRecordsAdvanceHolders
	|	WHERE
	|		DocumentRegisterRecordsAdvanceHolders.Recorder = &Ref
	|		AND DocumentRegisterRecordsAdvanceHolders.Period <= &Period
	|		AND DocumentRegisterRecordsAdvanceHolders.Company = &Company
	|		AND DocumentRegisterRecordsAdvanceHolders.Employee = &Employee) AS AdvanceHoldersBalances
	|
	|GROUP BY
	|	AdvanceHoldersBalances.DocumentDate,
	|	AdvanceHoldersBalances.Document
	|
	|HAVING
	|	SUM(AdvanceHoldersBalances.AmountCurBalance) > 0
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("Company", Object.Company);
	Query.SetParameter("DocumentCurrency", Object.DocumentCurrency);
	Query.SetParameter("Employee", Object.Employee);
	Query.SetParameter("Ref", Object.Ref);
	Query.SetParameter("Period", Object.Date);
	
	Object.AdvancesPaid.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	If WorkWithVAT.VATTaxationTypeIsValid(Object.VATTaxation, RegisteredForVAT, True)
		And Object.VATTaxation <> Enums.VATTaxationTypes.NotSubjectToVAT Then
		Return;
	EndIf;
	
	TaxationBeforeChange = Object.VATTaxation;
	
	Object.VATTaxation = DriveServer.VATTaxation(Object.Company, Object.Date);
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure

// Procedure fills the VAT rate in the tabular section according to the taxation system.
//
&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		For Each TabularSectionRow In Object.Inventory Do
			
			If ValueIsFilled(TabularSectionRow.Products.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.Products.VATRate;
			Else
				TabularSectionRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
			EndIf;	
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
		For Each TabularSectionRow In Object.Expenses Do
			
			If ValueIsFilled(TabularSectionRow.Products.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.Products.VATRate;
			Else
				TabularSectionRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
			EndIf;	
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
	Else
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
		
		For Each TabularSectionRow In Object.Inventory Do
			
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
			ClearDeductibleTaxByVATRate(TabularSectionRow);
			
		EndDo;
		
		For Each TabularSectionRow In Object.Expenses Do
			
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
			ClearDeductibleTaxByVATRate(TabularSectionRow);
			
		EndDo;
		
	EndIf;
	
	SetPropertiesOfItemsByVATTaxation();
	
EndProcedure

&AtServer
Procedure SetPropertiesOfItemsByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.InventoryDeductibleTax.Visible = True;
		Items.InventorySupplier.Visible = True;
		Items.ExpencesVATRate.Visible = True;
		Items.ExpencesAmountVAT.Visible = True;
		Items.TotalExpences.Visible = True;
		Items.ExpensesDeductibleTax.Visible = True;
		Items.ExpensesSupplier.Visible = True;
		
		TotalTitle = NStr("en = 'Total (presentation currency)'; ru = 'Итого (валюта представления отчетности)';pl = 'Łącznie (waluta prezentacji)';es_ES = 'Total (moneda de presentación)';es_CO = 'Total (moneda de presentación)';tr = 'Toplam (finansal tablo para birimi)';it = 'Totale (valuta di presentazione)';de = 'Gesamt (Währung für die Berichtserstattung)'");
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryDeductibleTax.Visible = False;
		Items.InventorySupplier.Visible = False;
		Items.ExpencesVATRate.Visible = False;
		Items.ExpencesAmountVAT.Visible = False;
		Items.TotalExpences.Visible = False;
		Items.ExpensesDeductibleTax.Visible = False;
		Items.ExpensesSupplier.Visible = False;
		
		TotalTitle = NStr("en = 'Amount (presentation currency)'; ru = 'Сумма (валюта представления отчетности)';pl = 'Kwota (waluta prezentacji)';es_ES = 'Importe (moneda de presentación)';es_CO = 'Importe (moneda de presentación)';tr = 'Tutar (finansal tablo para birimi)';it = 'Importo (valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'");
		
	EndIf;
	
	Items.InventoryTotalPresentationCur.Title = TotalTitle;
	Items.ExpensesTotalPresentationCur.Title = TotalTitle;
	
EndProcedure

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	AttributeArray = New Array;
	AttributeArray.Add("MeasurementUnit");
	AttributeArray.Add("VATRate");
	
	If StructureData.UseDefaultTypeOfAccounting Then
		AttributeArray.Add("ExpensesGLAccount.TypeOfAccount");
	EndIf;
	
	ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products, StrConcat(AttributeArray, ","));
	
	StructureData.Insert("MeasurementUnit", ProductsAttributes.MeasurementUnit);
	
	If StructureData.Property("VATTaxation") 
		AND Not StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		If StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		Else
			StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		EndIf;	
																
	ElsIf ValueIsFilled(StructureData.Products) And ValueIsFilled(ProductsAttributes.VATRate) Then
		StructureData.Insert("VATRate", ProductsAttributes.VATRate);
	Else
		StructureData.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company));
	EndIf;
	
	StructureData.Insert("ClearOrderAndDepartment", False);
	StructureData.Insert("ClearBusinessLine", False);
	
	If StructureData.UseDefaultTypeOfAccounting
		And ProductsAttributes.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Expenses
		And ProductsAttributes.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Revenue
		And ProductsAttributes.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.WorkInProgress
		And ProductsAttributes.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		
		StructureData.ClearOrderAndDepartment = True;
	EndIf;
	
	If StructureData.UseDefaultTypeOfAccounting
		And ProductsAttributes.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Expenses
		And ProductsAttributes.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.CostOfSales
		And ProductsAttributes.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Revenue Then
		
		StructureData.ClearBusinessLine = True;
	EndIf;
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataStructuralUnitOnChange(StructureData)
	
	GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	
	Return StructureData;
	
EndFunction

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure();
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else	
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Procedure GetPaymentDataContractOnChange(StructureData)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
	EndIf;
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		GetDataCurrencyRateRepetition(Object.Date, StructureData.Contract.SettlementsCurrency, Object.Company));
	
EndProcedure

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Procedure FillDataCounterpartyOnChange(StructureData)
	
	Counterparty = StructureData.Counterparty;
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Counterparty);
	
	Contract = GetContractByDefault(Object.Ref, Counterparty, Object.Company);
	StructureData.Insert("Contract", Contract);
	
	StructureData.Insert("DoOperationsByContracts", CounterpartyAttributes.DoOperationsByContracts);
	StructureData.Insert("DoOperationsByOrders", CounterpartyAttributes.DoOperationsByOrders);
	
	StructureData.Insert("ContractCurrencyRateRepetition", GetDataCurrencyRateRepetition(Object.Date, Contract.SettlementsCurrency, Object.Company));
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
	EndIf;
	
	SetAccountsAttributesVisible(CounterpartyAttributes.DoOperationsByContracts, CounterpartyAttributes.DoOperationsByOrders);
	
EndProcedure

// Gets the default contract depending on the billing details.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company);
	
EndFunction

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataBusinessLineStartChoice(ExpenseItem)
	
	StructureData = New Structure;
	
	AvailabilityOfPointingLinesOfBusiness = True;
	
	If ExpenseItem.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses
		And ExpenseItem.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.CostOfSales
		And ExpenseItem.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.Revenue Then
		
		AvailabilityOfPointingLinesOfBusiness = False;
	EndIf;
	
	StructureData.Insert("AvailabilityOfPointingLinesOfBusiness", AvailabilityOfPointingLinesOfBusiness);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataOrderStartChoice(ExpenseItem)
	
	StructureData = New Structure;
	
	AbilityToSpecifyOrder = True;
	
	If ExpenseItem.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses
		And ExpenseItem.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.Revenue
		And ExpenseItem.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.ManufacturingOverheads Then
		
		AbilityToSpecifyOrder = False;
	EndIf;
	
	StructureData.Insert("AbilityToSpecifyOrder", AbilityToSpecifyOrder);
	
	Return StructureData;
	
EndFunction

// Procedure fills out the service attributes.
//
&AtServerNoContext
Procedure FillServiceAttributesByCounterpartyInCollection(DataCollection)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CAST(Table.LineNumber AS NUMBER) AS LineNumber,
	|	Table.Counterparty AS Counterparty
	|INTO TableOfCounterparty
	|FROM
	|	&DataCollection AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TableOfCounterparty.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	TableOfCounterparty.Counterparty.DoOperationsByOrders AS DoOperationsByOrders
	|FROM
	|	TableOfCounterparty AS TableOfCounterparty";
	
	Query.SetParameter("DataCollection", DataCollection.Unload( ,"LineNumber, Counterparty"));
	
	Selection = Query.Execute().Select();
	For Ct = 0 To DataCollection.Count() - 1 Do
		Selection.Next(); // Number of rows in the query selection always equals to the number of rows in the collection
		FillPropertyValues(DataCollection[Ct], Selection, "DoOperationsByContracts, DoOperationsByOrders");
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetAccountingPolicyValues(Date, Company)
	
	RegisterPolicy = InformationRegisters.AccountingPolicy;
	Policy = RegisterPolicy.GetAccountingPolicy(Date, Company);
	
	Result = New Structure;
	Result.Insert("PerInvoiceVATRoundingRule", Policy.PerInvoiceVATRoundingRule);
	Result.Insert("RegisteredForVAT", Policy.RegisteredForVAT);
	
	Return Result;
	
EndFunction

&AtClient
Procedure SetVisibleOnCurrencyChange()
	
	If Object.DocumentCurrency = PresentationCurrency Then
		Items.InventoryTotalPresentationCur.Visible = False;
		Items.InventoryExchangeRate.Visible = False;
		Items.InventoryMultiplicity.Visible = False;
		Items.ExpensesTotalPresentationCur.Visible = False;
		Items.ExpensesExchangeRate.Visible = False;
		Items.ExpensesMultiplicity.Visible = False;
	Else
		Items.InventoryTotalPresentationCur.Visible = True;
		Items.InventoryExchangeRate.Visible = True;
		Items.InventoryMultiplicity.Visible = True;
		Items.ExpensesTotalPresentationCur.Visible = True;
		Items.ExpensesExchangeRate.Visible = True;
		Items.ExpensesMultiplicity.Visible = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetAutomaticVATCalculation()
	
	// The default value for this document is False, so the value should be True only if set manually
	Object.AutomaticVATCalculation = (Object.AutomaticVATCalculation And PerInvoiceVATRoundingRule);
	
EndProcedure

&AtServer
Procedure SetFormConditionalAppearance()
	
	// PaymentSchedule
	NewConditionalAppearance	= ConditionalAppearance.Items.Add();
	FilterItemsGroup		= WorkWithForm.CreateFilterItemGroup(NewConditionalAppearance.Filter, "AndGroup");
	
	WorkWithForm.AddFilterItem(FilterItemsGroup,
		"Object.Payments.Counterparty",
		,
		DataCompositionComparisonType.Filled);
	
	WorkWithForm.AddFilterItem(FilterItemsGroup,
		"Object.Payments.DoOperationsByOrders",
		False,
		DataCompositionComparisonType.Equal);
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>",
		NStr("en = 'Billing details by orders are not specified for the counterparty'; ru = 'Для контрагента не установлены расчеты по заказам';pl = 'Dane rozliczeniowe według zamówień nie są określone dla kontrahenta';es_ES = 'Los detalles del presupuesto por órdenes no están especificados para la contraparte';es_CO = 'Los detalles del presupuesto por órdenes no están especificados para la contraparte';tr = 'Cari hesap için siparişlere göre fatura ayrıntıları belirtilmemiş';it = 'I dettagli di fatturazione per ordini non sono specificati per la controparte';de = 'Abrechnungsdetails nach Aufträgen sind für die Geschäftspartner nicht angegeben'"));
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "PaymentSchedule");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// PaymentContract
	NewConditionalAppearance	= ConditionalAppearance.Items.Add();
	FilterItemsGroup		= WorkWithForm.CreateFilterItemGroup(NewConditionalAppearance.Filter, "AndGroup");
	
	WorkWithForm.AddFilterItem(FilterItemsGroup,
		"Object.Payments.Counterparty",
		,
		DataCompositionComparisonType.Filled);
	
	WorkWithForm.AddFilterItem(FilterItemsGroup,
		"Object.Payments.DoOperationsByContracts",
		False,
		DataCompositionComparisonType.Equal);
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>",
		NStr("en = 'Billing details by contracts are not specified for the counterparty'; ru = 'Для контрагента не установлены расчеты по договорам';pl = 'Dane rozliczeniowe według kontraktów nie są określone dla kontrahenta';es_ES = 'Los detalles del presupuesto no están especificados para la contraparte';es_CO = 'Los detalles del presupuesto no están especificados para la contraparte';tr = 'Cari hesap için sözleşmelerle fatura detayları belirtilmemiştir';it = 'I dettagli di fatturazione per contratti non sono specificati per la controparte';de = 'Abrechnungsdetails nach Verträgen sind für die Geschäftspartner nicht angegeben'"));
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "PaymentContract");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter, "Object.Inventory.VATRate", Catalogs.VATRates.Exempt);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "InventoryDeductibleTax");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Enabled", False);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter, "Object.Inventory.DeductibleTax", False);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "InventorySupplier");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Enabled", False);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter, "Object.Expenses.VATRate", Catalogs.VATRates.Exempt);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "ExpensesDeductibleTax");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Enabled", False);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter, "Object.Expenses.DeductibleTax", False);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "ExpensesSupplier");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Enabled", False);
	
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance);
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	Fields.Add(Items.ExpencesPrice);
	
	Return Fields;
	
EndFunction

&AtClient
Procedure ClearSupplierWithDeductibleTaxOff(TabularSectionRow)
	
	If Not TabularSectionRow.DeductibleTax Then
		TabularSectionRow.Supplier = Undefined;
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, DoOperationsByOrders";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

#Region WorkWithSelection

&AtClient
Procedure AdvancesFilterEnd(Result1, AdditionalParameters) Export
	
	AddressAdvancesPaidInStorage = AdditionalParameters.AddressAdvancesPaidInStorage;
	
	
	Result = Result1;
	If Result = DialogReturnCode.OK Then
		GetAdvancesPaidFromStorage(AddressAdvancesPaidInStorage);
		
	EndIf;

EndProcedure

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If TabularSectionName = "Inventory" Then
			
			NewRow.StructuralUnit = MainWarehouse;
			
		EndIf;
		
		If TabularSectionName = "Expenses" Then
			
			NewRow.StructuralUnit = MainDepartment;
			
		EndIf;
		
		NewRow.ExchangeRate = ?(Object.ExchangeRate = 0, 1, Object.ExchangeRate);
		NewRow.Multiplicity = ?(Object.Multiplicity = 0, 1, Object.Multiplicity);
		
		NewRow.TotalPresentationCur = DriveServer.RecalculateFromCurrencyToCurrency(
			NewRow.Total,
			ExchangeRateMethod,
			NewRow.ExchangeRate,
			RatePresentationCurrency,
			NewRow.Multiplicity,
			RepetitionPresentationCurrency,
			PricesPrecision);
		
		NewRow.VATAmountPresentationCur = DriveServer.RecalculateFromCurrencyToCurrency(
			NewRow.VATAmount,
			ExchangeRateMethod,
			NewRow.ExchangeRate,
			RatePresentationCurrency,
			NewRow.Multiplicity,
			RepetitionPresentationCurrency,
			PricesPrecision);
			
		IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, TabularSectionName);
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
	EndIf;

EndProcedure

&AtClient
Procedure GetWeightEnd(Weight, Parameters) Export
	
	TabularSectionRow = Parameters;
	
	If Not Weight = Undefined Then
		If Weight = 0 Then
			MessageText = NStr("en = 'Electronic scales returned zero weight.'; ru = 'Электронные весы вернули нулевой вес.';pl = 'Waga elektroniczna zwróciła zerową wagę.';es_ES = 'Escalas electrónicas han devuelto el peso cero.';es_CO = 'Escalas electrónicas han devuelto el peso cero.';tr = 'Elektronik tartı sıfır ağırlık gösteriyor.';it = 'Le bilance elettroniche hanno dato peso pari a zero.';de = 'Die elektronische Waagen gaben Nullgewicht zurück.'");
			CommonClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
			CalculateAmountInTabularSectionLine(TabularSectionRow);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			CurrentPagesInventory		= (Items.Pages.CurrentPage = Items.Products);
			TabularSectionName			= ?(CurrentPagesInventory, "Inventory", "Expenses");
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, CurrentPagesInventory, CurrentPagesInventory);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RecalculateSubtotal()
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileInventory(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName", 	"ExpenseReport.Inventory");
	DataLoadSettings.Insert("Title", 					NStr("en = 'Import products from file'; ru = 'Загрузка номенклатуры из файла';pl = 'Importuj produkty z pliku';es_ES = 'Importar los productos del archivo';es_CO = 'Importar los productos del archivo';tr = 'Ürünleri dosyadan içe aktar';it = 'Importazione articoli da file';de = 'Produkte aus Datei importieren'"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
		RecalculateSubtotal();
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillExpenses", False);
	ParametersStructure.Insert("FillPayments", False);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

#EndRegion

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

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion