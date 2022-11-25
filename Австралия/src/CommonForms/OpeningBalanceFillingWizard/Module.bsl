
#Region Variables

&AtClient
Var mCurrentPageNumber;

&AtClient
Var mFirstPage;

&AtClient
Var mLastPage;

&AtClient
Var mFormRecordCompleted;

#EndRegion

#Region FormEventHandlers

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	mCurrentPageNumber = 0;
	mFirstPage = 0;
	mLastPage = 5;
	mFormRecordCompleted = False;
	
	SetActivePage();
	SetButtonsEnabled();
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Company, PricesFields());
	// Prices precision end
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	BalanceDate = CurrentSessionDate();
	Company = Catalogs.Companies.MainCompany;
	
	UseSeveralWarehouses = DriveClientServer.BooleanToYesNo(Constants.UseSeveralWarehouses.Get());
	
	UseStorageBins = DriveClientServer.BooleanToYesNo(Constants.UseStorageBins.Get());
	
	UseSeveralUnitsForProduct = DriveClientServer.BooleanToYesNo(Constants.UseSeveralUnitsForProduct.Get());
	
	UseCharacteristics = DriveClientServer.BooleanToYesNo(Constants.UseCharacteristics.Get());
	
	UseBatches = DriveClientServer.BooleanToYesNo(Constants.UseBatches.Get());
	
	ForeignExchangeAccounting = DriveClientServer.BooleanToYesNo(Constants.ForeignExchangeAccounting.Get());
	
	FunctionalCurrency = DriveReUse.GetFunctionalCurrency();
	
	UseContractsWithCounterparties = DriveClientServer.BooleanToYesNo(Constants.UseContractsWithCounterparties.Get());
	
	UseCounterpartyContractTypes = DriveClientServer.BooleanToYesNo(Constants.UseCounterpartyContractTypes.Get());
	
	UseProduction = DriveClientServer.BooleanToYesNo(Constants.UseProductionSubsystem.Get());
	
	MetadataOpeningBalanceEntryName = Metadata.Documents.OpeningBalanceEntry.Name;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If DriveClientServer.YesNoToBoolean(ForeignExchangeAccounting) Then
		Items.FunctionalCurrency.ReadOnly = False;
		Items.FunctionalCurrency.AutoChoiceIncomplete = True;
		Items.FunctionalCurrency.AutoMarkIncomplete = True;
	Else
		Items.FunctionalCurrency.ReadOnly = True;
		Items.FunctionalCurrency.AutoChoiceIncomplete = False;
		Items.FunctionalCurrency.AutoMarkIncomplete = False;
	EndIf;
	
	ImportFormSettings();
	
	If Not ValueIsFilled(AssistantSimpleUseMode) Then
		AssistantSimpleUseMode = DriveClientServer.BooleanToYesNo(True);
	EndIf;
	
	SetAssistantUsageMode();
	
	FillDocumentTypeLists();
	DocumentsAndTablesInitialization();
	
	SetFormConditionalAppearance();
	
	DataImportAccessible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	Items.OpeningBalanceEntryProductsInventoryDataImportFromExternalSources.Visible = DataImportAccessible;
	Items.CashAssetsBankDataImportFromExternalSourcesBankAccounts.Visible = DataImportAccessible;
	Items.CashAssetsCashDataImportFromExternalSourcesCashAccounts.Visible = DataImportAccessible;
	Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableDataImportFromExternalSourcesAccountsPayable.Visible
		= DataImportAccessible;
	Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableDataImportFromExternalSourcesAccountsReceivable.Visible
		= DataImportAccessible;
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.OpeningBalanceEntry.TabularSections.Inventory, DataLoadSettings, ThisObject, False);
	// End StandardSubsystems.DataImportFromExternalSource
	
EndProcedure

// Procedure - event handler BeforeClose form.
//
&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)	
	
	If Not mFormRecordCompleted
		AND Modified Then
		
		If Exit Then
			WarningText = NStr("en = 'Data will be lost'; ru = 'Данные будут потеряны';pl = 'Dane zostaną utracone';es_ES = 'Datos se perderán';es_CO = 'Datos se perderán';tr = 'Veriler kaybolacak';it = 'I dati andranno persi';de = 'Daten gehen verloren'");
			Return;
		EndIf;
		
		Cancel = True;
		NotifyDescription = New NotifyDescription("BeforeCloseEnd", ThisObject);
		Text = NStr("en = 'Save changes?'; ru = 'Сохранить изменения?';pl = 'Zapisać zmiany?';es_ES = '¿Guardar los cambios?';es_CO = '¿Guardar los cambios?';tr = 'Değişiklikler kaydedilsin mi?';it = 'Salvare le modifiche?';de = 'Änderungen speichern?'");
		ShowQueryBox(NotifyDescription, Text, QuestionDialogMode.YesNoCancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeCloseEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Cancel = False;
		ExecuteActionsOnTransitionToNextPage(Cancel);
		If Not Cancel Then
			WriteFormChanges();
			SaveFormSettings();
			Modified = False;
			Close();
		EndIf;
	ElsIf Result = DialogReturnCode.No Then
		Modified = False;
		Close();
	EndIf;
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter) Then
			For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements.AccountsReceivable Do
				If Parameter = CurRow.Counterparty Then
					SetAccountsAttributesVisible(, , "AccountsReceivable");
					Return;
				EndIf;
			EndDo;
			For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements.AccountsPayable Do
				If Parameter = CurRow.Counterparty Then
					SetAccountsAttributesVisible(, , "AccountsPayable");
					Return;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Procedure - handler of the OnChange event of the ForeignExchangeAccounting attribute.
//
&AtClient
Procedure CurrencyTransactionsAccountingOnChange(Item)
	
	WriteChangesCurrencyTransactionsAccounting();
	
	RefreshInterface();
	
EndProcedure

// Procedure - handler of the OnChange event of the UseSeveralWarehouses attribute.
//
&AtClient
Procedure AccountingBySeveralWarehousesOnChange(Item)
	
	WriteChangesAccountingBySeveralWarehouses(UseSeveralWarehouses);
	
	RefreshInterface();
	
EndProcedure

&AtClient
Procedure AccountingByStorageBinsOnChange(Item)
	
	WriteChangesAccountingByStorageBins(UseStorageBins);
	
	RefreshInterface();
	
EndProcedure

// Procedure - handler of the OnChange event of the UseSeveralUnitsForProduct attribute.
//
&AtClient
Procedure AccountingInVariousUOMOnChange(Item)
	
	WriteChangesAccountingInVariousUOM(UseSeveralUnitsForProduct);
	
	RefreshInterface();
	
EndProcedure

// Procedure - handler of the OnChange event of the UseCharacteristics attribute.
//
&AtClient
Procedure UseCharacteristicsOnChange(Item)
	
	WriteChangesUseCharacteristics(UseCharacteristics);
	
	RefreshInterface();
	
EndProcedure

// Procedure - handler of the OnChange event of the UseBatches attribute.
//
&AtClient
Procedure UseBatchesOnChange(Item)
	
	WriteChangesUseBatches(UseBatches);
	
	RefreshInterface();
	
EndProcedure

&AtClient
Procedure UseContractsWithCounterpartiesOnChange(Item)
	
	WriteChangesUseContractsWithCounterparties(UseContractsWithCounterparties);
	
	RefreshInterface();
	
EndProcedure

&AtClient
Procedure UseCounterpartyContractTypesOnChange(Item)
	
	WriteChangesUseCounterpartyContractTypes(UseCounterpartyContractTypes);
	
	RefreshInterface();
	
EndProcedure

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Procedure FillDataCounterpartyOnChange(StructureData, TabularSectionName)
	
	CounterpartyParameter = StructureData.Counterparty;
	
	Contract = DriveServer.GetContractByDefault(OpeningBalanceEntryCounterpartiesSettlements.Ref,
		CounterpartyParameter,
		Company,
		,
		TabularSectionName);
	
	StructureData.Insert("TabName", 				TabularSectionName);
	StructureData.Insert("Contract", 				Contract);
	StructureData.Insert("SettlementsCurrency", 	Contract.SettlementsCurrency);
	StructureData.Insert("DoOperationsByContracts", CounterpartyParameter.DoOperationsByContracts);
	StructureData.Insert("DoOperationsByOrders",	CounterpartyParameter.DoOperationsByOrders);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
	EndIf;
	
	Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Company,
		StructureData.AmountCur,
		StructureData.SettlementsCurrency,
		BalanceDate);
		
	StructureData.Insert("Amount", Amount);
	
	SetAccountsAttributesVisible(
		CounterpartyParameter.DoOperationsByContracts,
		CounterpartyParameter.DoOperationsByOrders,
		TabularSectionName);
	
EndProcedure

&AtServer
Procedure FillDataConctractOnChange(StructureData)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
	EndIf;
	
	Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Company,
		StructureData.AmountCur,
		StructureData.Contract,
		BalanceDate);
	
EndProcedure

// Procedure sets visible of calculation attributes depending on the parameters specified to the counterparty.
//
&AtServer
Procedure SetAccountsAttributesVisible(Val DoOperationsByContracts = False, Val DoOperationsByOrders = False, TabularSectionName)
	
	FillServiceAttributesByCounterpartyInCollection(OpeningBalanceEntryCounterpartiesSettlements[TabularSectionName]);
	
	For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements[TabularSectionName] Do
		If CurRow.DoOperationsByContracts Then
			DoOperationsByContracts = True;
		EndIf;
		If CurRow.DoOperationsByOrders Then
			DoOperationsByOrders = True;
		EndIf;
	EndDo;
	
	If TabularSectionName = "AccountsPayable" Then
		Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableContract.Visible = DoOperationsByContracts;
		Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayablePurchaseOrder.Visible = DoOperationsByOrders;
	ElsIf TabularSectionName = "AccountsReceivable" Then
		Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableContract.Visible = DoOperationsByContracts;
		Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableSalesOrder.Visible = DoOperationsByOrders;
	EndIf;
	
EndProcedure

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
	|SELECT
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

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration47Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 1;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration53Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 3;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration50Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 2;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration56Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 4;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration133Click(Item)
	
	mCurrentPageNumber = 0;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - handler of the OnChange event of the AssistantSimpleUseMode attribute in tabular section.
//
&AtClient
Procedure AssistantSimpleUseModeOnChange(Item)
	
	SetAssistantUsageMode();
	
EndProcedure

// Procedure changes the visible of attributes depending on the usage mode.
//
&AtServer
Procedure SetAssistantUsageMode()
	
	AdditionalAttributesVisible = Not DriveClientServer.YesNoToBoolean(AssistantSimpleUseMode);
	
	Items.Step1FOTitle.Visible = AdditionalAttributesVisible;
	Items.Step1FO.Visible = AdditionalAttributesVisible;
	Items.Step2FOTitle.Visible = AdditionalAttributesVisible;
	Items.Step2FO.Visible = AdditionalAttributesVisible;
	
EndProcedure

// Procedure - event data processor.
//
&AtClient
Procedure DateOfChange(Item)
	
	BalanceDateOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Company, PricesFields());
	// Prices precision end
	
	DocumentsAndTablesInitialization();
	
EndProcedure

// Procedure - event data processor.
//
&AtServer
Procedure BalanceDateOnChangeAtServer()
	
	For Each CurRow In OpeningBalanceEntryBankAndPettyCash.CashAssets Do
		
		CurRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
			Company,
			CurRow.AmountCur,
			CurRow.CashCurrency,
			BalanceDate);
			
	EndDo;
	
	For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements.AccountsPayable Do
		
		CurRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
			Company,
			CurRow.AmountCur,
			CurRow.Contract,
			BalanceDate);
			
	EndDo;
	
	For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements.AccountsReceivable Do
		
		CurRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
			Company,
			CurRow.AmountCur,
			CurRow.Contract,
			BalanceDate);
			
	EndDo;
	
EndProcedure

#EndRegion 

#Region FormTableItemsEventHandlers

&AtClient
Procedure OpeningBalanceEntryProductsInventoryOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Not Clone Then
		TabularSectionRow = Items.OpeningBalanceEntryProductsInventory.CurrentData;
		TabularSectionRow.StructuralUnit = PredefinedValue("Catalog.BusinessUnits.MainWarehouse");
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of attribute OpeningBalanceEntryProductsInventoryPrice.
//
&AtClient
Procedure OpeningBalanceEntryProductsInventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange of attribute OpeningBalanceEntryProductsInventoryQuantity.
//
&AtClient
Procedure OpeningBalanceEntryProductsInventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange of attribute OpeningBalanceEntryProductsInventoryAmount.
//
&AtClient
Procedure OpeningBalanceEntryProductsInventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryProductsInventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of the Products attribute in tablular section.
//
&AtClient
Procedure OpeningBalanceEntryProductsInventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryProductsInventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company",				Company);
	StructureData.Insert("Products", 			TabularSectionRow.Products);
	StructureData.Insert("Object",				OpeningBalanceEntryProducts);
	StructureData.Insert("StructuralUnit",		TabularSectionRow.StructuralUnit);
	StructureData.Insert("StructuralUnitInTabularSection", True);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If UseDefaultTypeOfAccounting Then
		StructureData.Insert("InventoryGLAccount", TabularSectionRow.InventoryGLAccount);
		StructureData.Insert("ProductGLAccounts", True);
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	If TabularSectionRow.Quantity = 0 Then
		TabularSectionRow.Quantity = 1;
	EndIf;
	
EndProcedure

&AtClient
Procedure OpeningBalanceEntryProductsInventoryStructuralUnitOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryProductsInventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company",				Company);
	StructureData.Insert("Products", 			TabularSectionRow.Products);
	StructureData.Insert("Object",				OpeningBalanceEntryProducts);
	StructureData.Insert("StructuralUnit",		TabularSectionRow.StructuralUnit);
	StructureData.Insert("StructuralUnitInTabularSection", True);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If UseDefaultTypeOfAccounting Then
		StructureData.Insert("InventoryGLAccount", TabularSectionRow.InventoryGLAccount);
		StructureData.Insert("ProductGLAccounts", True);
	EndIf;
	
	StructureData = GetDataStructuralUnitOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	If TabularSectionRow.Quantity = 0 Then
		TabularSectionRow.Quantity = 1;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
Procedure OpeningBalanceEntryProductsInventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.OpeningBalanceEntryProductsInventory.CurrentData;
	
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
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - handler of the OnChange event of input field.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableCounterpartyOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayable.CurrentData;
	
	StructureData = GetStructureDataForObject(ThisObject, "AccountsPayable", TabularSectionRow);
	FillDataCounterpartyOnChange(StructureData, "AccountsPayable");
	FillPropertyValues(TabularSectionRow, StructureData);
	
	AdjustDocumentType(TabularSectionRow);
	
EndProcedure

// Procedure - handler of the OnChange event of the AmountCur attribute in tabular section.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableAmountValOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayable.CurrentData;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Company,
		TabularSectionRow.AmountCur,
		TabularSectionRow.Contract,
		BalanceDate);
EndProcedure

// Procedure - handler of the OnChange event of the AccountsPayableContract attribute in tabular section.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableContractOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayable.CurrentData;
	
	StructureData = GetStructureDataForObject(ThisObject, "AccountsPayable", TabularSectionRow);
	FillDataConctractOnChange(StructureData);
	FillPropertyValues(TabularSectionRow, StructureData);
	
	AdjustDocumentType(TabularSectionRow);
	
EndProcedure

// Procedure - event data processor.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableAfterDeleteRowRow(Item)
	
	SetAccountsAttributesVisible(, , "AccountsPayable");
	
EndProcedure

&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableDocumentTypeOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayable.CurrentData;
	AdjustDocumentType(TabularSectionRow);
	ChangeAdvanceFlag(TabularSectionRow, False, PreviousDocumentTypeValue);
	
EndProcedure

&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableDocumentTypeChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayable.CurrentData;
	PreviousDocumentTypeValue = TabularSectionRow.DocumentType;
	
EndProcedure

&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableDocumentOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
		TabularSectionRow.AdvanceFlag = True;
	ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ArApAdjustments") Then
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
	DocumentData = GetDocumentData(TabularSectionRow.Document);
	FillPropertyValues(TabularSectionRow, DocumentData);
	
EndProcedure

// Procedure - handler of the OnChange event of input field.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableCounterpartyOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivable.CurrentData;
	
	StructureData = GetStructureDataForObject(ThisObject, "AccountsReceivable", TabularSectionRow);
	
	FillDataCounterpartyOnChange(StructureData, "AccountsReceivable");
	FillPropertyValues(TabularSectionRow, StructureData);
	
	AdjustDocumentType(TabularSectionRow);
	
EndProcedure

// Procedure - handler of the OnChange event of the AmountCur attribute in tabular section.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableAmountCurOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivable.CurrentData;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Company,
		TabularSectionRow.AmountCur,
		TabularSectionRow.Contract,
		BalanceDate);
EndProcedure

// Procedure - handler of the OnChange event of the AccountsReceivableContract attribute in tabular section.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableContractOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivable.CurrentData;
	
	StructureData = GetStructureDataForObject(ThisObject, "AccountsReceivable", TabularSectionRow);
	FillDataConctractOnChange(StructureData);
	FillPropertyValues(TabularSectionRow, StructureData);
	
	AdjustDocumentType(TabularSectionRow);
	
EndProcedure

// Procedure - event data processor.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableAfterDeleteRowRow(Item)
	
	SetAccountsAttributesVisible(, , "AccountsReceivable");
	
EndProcedure

&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableDocumentTypeOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivable.CurrentData;
	AdjustDocumentType(TabularSectionRow);
	ChangeAdvanceFlag(TabularSectionRow, True, PreviousDocumentTypeValue);
	
EndProcedure

&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableDocumentTypeChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivable.CurrentData;
	PreviousDocumentTypeValue = TabularSectionRow.DocumentType;
	
EndProcedure

&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableDocumentOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
		TabularSectionRow.AdvanceFlag = True;
	ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ArApAdjustments") Then
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
	DocumentData = GetDocumentData(TabularSectionRow.Document);
	FillPropertyValues(TabularSectionRow, DocumentData);
	
EndProcedure

&AtClient
Procedure CashAssetsBankOnChange(Item)
	
	FillLineNumbers(CashAssetsBank);
	
EndProcedure

&AtClient
Procedure CashAssetsBankAmountCurOnChange(Item)
	
	TabularSectionRow = Items.CashAssetsBank.CurrentData;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Company,
		TabularSectionRow.AmountCur,
		TabularSectionRow.CashCurrency,
		BalanceDate);
	
EndProcedure

&AtClient
Procedure CashAssetsBankBankAccountPettyCashOnChange(Item)
	
	TabularSectionRow = Items.CashAssetsBank.CurrentData;
	
	StructureData = GetDataCashAssetsBankAccountPettyCashOnChange(TabularSectionRow.BankAccountPettyCash);
	
	TabularSectionRow.CashCurrency = StructureData.Currency;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Company,
		TabularSectionRow.AmountCur,
		TabularSectionRow.CashCurrency,
		BalanceDate);
	
EndProcedure

&AtClient
Procedure CashAssetsCashOnChange(Item)
	
	FillLineNumbers(CashAssetsCash);
	
EndProcedure

&AtClient
Procedure CashAssetsCashAmountCurOnChange(Item)
	
	TabularSectionRow = Items.CashAssetsCash.CurrentData;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Company,
		TabularSectionRow.AmountCur,
		TabularSectionRow.CashCurrency,
		BalanceDate);
	
EndProcedure

&AtClient
Procedure CashAssetsCashBankAccountPettyCashOnChange(Item)
	
	TabularSectionRow = Items.CashAssetsCash.CurrentData;
	
	StructureData = GetDataCashAssetsBankAccountPettyCashOnChange(TabularSectionRow.BankAccountPettyCash);
	
	TabularSectionRow.CashCurrency = StructureData.Currency;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Company,
		TabularSectionRow.AmountCur,
		TabularSectionRow.CashCurrency,
		BalanceDate);
	
EndProcedure

&AtClient
Procedure OpeningBalanceEntryProductsInventoryDocumentTypeOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryProductsInventory.CurrentData;
	AdjustDocumentType(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure OpeningBalanceEntryProductsInventoryDocumentOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryProductsInventory.CurrentData;
	DocumentData = GetDocumentData(TabularSectionRow.Document);
	FillPropertyValues(TabularSectionRow, DocumentData);
	
EndProcedure

#EndRegion 

#Region FormCommandsEventHandlers

// Procedure - CloseForm command handler.
//
&AtClient
Procedure CloseForm(Command)
	
	Close(False);
	
EndProcedure

// Procedure - Next command handler.
//
&AtClient
Procedure GoToNext(Command)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	If mCurrentPageNumber = mLastPage Then
		WriteFormChanges(True);
		mFormRecordCompleted = True;
		SaveFormSettings();
		Close(True);
	EndIf;
	
	mCurrentPageNumber = ?(mCurrentPageNumber + 1 > mLastPage, mLastPage, mCurrentPageNumber + 1);
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - Back command handler.
//
&AtClient
Procedure Back(Command)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = ?(mCurrentPageNumber - 1 < mFirstPage, mFirstPage, mCurrentPageNumber - 1);
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - handler of the GoToPricing command.
//
&AtClient
Procedure GoToPricing(Command)
	
	AddressInventoryInStorage = PlaceInventoryToStorage();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("AddressInventoryInStorage", AddressInventoryInStorage);
	ParametersStructure.Insert("ToDate", BalanceDate);
	ParametersStructure.Insert("Company", Company);
	
	Notification = New NotifyDescription("GoToPricingCompletion",ThisForm);
	OpenForm("DataProcessor.Pricing.Form", ParametersStructure,,,,,Notification);
	
EndProcedure

&AtClient
Procedure GoToPricingCompletion(GenerationResult,Parameters) Export
	
	Result = GenerationResult;
	
EndProcedure

// Procedure - handler of the DocumentsListOpeningBalanceEntry command.
//
&AtClient
Procedure DocumentsListOpeningBalanceEntry(Command)
	
	If Modified Then
		Text = NStr("en = 'The specified details will be saved. Do you want to continue?'; ru = 'Указанные данные будут сохранены. Продолжить?';pl = 'Określone szczegóły zostaną zapisane. Czy chcesz kontynuować?';es_ES = 'Los detalles especificados se guardarán. ¿Quiere continuar?';es_CO = 'Los detalles especificados se guardarán. ¿Quiere continuar?';tr = 'Belirtilen bilgiler kaydedilecek. Devam etmek istiyor musunuz?';it = 'I dettagli specificati verrano salvati. Continuare?';de = 'Die angegebenen Details werden gespeichert. Möchten Sie fortfahren?'");
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("DocumentsListOpeningBalanceEntryEnd", ThisObject), Text, Mode, 0);
		Return;
	EndIf;
	
	DocumentsListOpeningBalanceEntryFragment();
	
EndProcedure

&AtClient
Procedure DocumentsListOpeningBalanceEntryEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	WriteFormChanges(True);
	mFormRecordCompleted = True;
	SaveFormSettings();
	Modified = False;
	ReadDocumentTypes();
	
	DocumentsListOpeningBalanceEntryFragment();
	
EndProcedure

&AtClient
Procedure DocumentsListOpeningBalanceEntryFragment()
	
	OpenForm("Document.OpeningBalanceEntry.ListForm");
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CheckBatchesFilling(Cancel)
	
	DocObject = FormAttributeToValue("OpeningBalanceEntryProducts");
	DocObject.AdditionalProperties.Insert("MessagesDataPath", "OpeningBalanceEntryProducts");
	BatchesServer.CheckFilling(DocObject, Cancel);
	
EndProcedure

&AtClient
Procedure AdjustDocumentType(TabularSectionRow)
	
	If Not IsBlankString(TabularSectionRow.DocumentType) Then
		
		DocTypeDescription = New TypeDescription("DocumentRef." + TabularSectionRow.DocumentType);
		TabularSectionRow.Document = DocTypeDescription.AdjustValue(TabularSectionRow.Document);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetDocumentData(Document)
	
	Result = New Structure;
	
	If ValueIsFilled(Document) Then
		
		DocumentData = Common.ObjectAttributesValues(Document, "Number, Date");
		Result.Insert("DocumentNumber", DocumentData.Number);
		Result.Insert("DocumentDate", DocumentData.Date);
		Result.Insert("DocumentType", Document.Metadata().Name);
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure ReadDocumentTypes()
	
	TableNames = New Array;
	TableNames.Add("Inventory");
	TableNames.Add("AccountsPayable");
	TableNames.Add("AccountsReceivable");
	TableNames.Add("AdvanceHolders");
	
	For Each TableName In TableNames Do
		
		For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements[TableName] Do
			If CurRow.Document <> Undefined Then
				CurRow.DocumentType = CurRow.Document.Metadata().Name;
			EndIf;
		EndDo;
		
		For Each CurRow In OpeningBalanceEntryProducts[TableName] Do
			If CurRow.Document <> Undefined Then
				CurRow.DocumentType = CurRow.Document.Metadata().Name;
			EndIf;
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillDocumentTypeLists()
	
	AttributesDocument = New Array;
	AttributesDocument.Add("Inventory");
	AttributesDocument.Add("AccountsReceivable");
	AttributesDocument.Add("AccountsPayable");
	
	DocMetadataTS = Metadata.Documents.OpeningBalanceEntry.TabularSections;
	
	For Each AttributeDocument In AttributesDocument Do
		
		If AttributeDocument = "Inventory" Then
			ItemName = "OpeningBalanceEntryProductsInventoryDocumentType";
			AttributeName = "OpeningBalanceEntryProducts.Inventory.DocumentType";
		Else
			ItemName = "OpeningBalanceEntryCounterpartiesSettlements" + AttributeDocument + "DocumentType";
			AttributeName = "OpeningBalanceEntryCounterpartiesSettlements." + AttributeDocument + ".DocumentType";
		EndIf;
		
		ChoiceList = Items[ItemName].ChoiceList;
		AttributeDocumentTypes = DocMetadataTS[AttributeDocument].Attributes.Document.Type.Types();
		
		For Each AttributeDocumentType In AttributeDocumentTypes Do
			
			If AttributeDocumentType = Type("DocumentRef.OpeningBalanceEntry")
				// begin Drive.FullVersion
				Or (AttributeDocumentType = Type("DocumentRef.Manufacturing")
				And UseProduction = Enums.YesNo.No)
				// end Drive.FullVersion
				Then
				
				Continue;
				
			EndIf;
			
			DocTypeMetadata = Metadata.FindByType(AttributeDocumentType);
			DocTypeName = DocTypeMetadata.Name;
			DocTypePresentation = DocTypeMetadata.ObjectPresentation;
			If IsBlankString(DocTypePresentation) Then
				DocTypePresentation = DocTypeMetadata.Presentation();
			EndIf;
			
			ChoiceList.Add(DocTypeName, DocTypePresentation);
			
			NewConditionalAppearance = ConditionalAppearance.Items.Add();
			WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
				AttributeName,
				DocTypeName,
				DataCompositionComparisonType.Equal);
			WorkWithForm.AddAppearanceField(NewConditionalAppearance, ItemName);
			WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", DocTypePresentation);
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillLineNumbers(Table)
	
	LineNumber = 0;
	For Each CurRow In Table Do
		LineNumber = LineNumber + 1;
		CurRow.LineNumber = LineNumber;
	EndDo;
	
EndProcedure

&AtServer
Procedure DocumentsAndTablesInitialization()
	
	ReadOpeningBalanceEntryDocuments();
	FillCashAssetsTables();
	
	SetAccountsAttributesVisible(, , "AccountsPayable");
	SetAccountsAttributesVisible(, , "AccountsReceivable");
	
	ReadDocumentTypes();
	
	PresentationCurrency = DriveServer.GetPresentationCurrency(Company);
	
	AmountPCTitle = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Amount (%1)'; ru = 'Сумма (%1)';pl = 'Wartość (%1)';es_ES = 'Importe (%1)';es_CO = 'Cantidad (%1)';tr = 'Tutar (%1)';it = 'Importo (%1)';de = 'Betrag (%1)'"),
		PresentationCurrency);
	Items.CashAssetsBankAmount.Title = AmountPCTitle;
	Items.CashAssetsCashAmount.Title = AmountPCTitle;
	Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableAmount.Title = AmountPCTitle;
	Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableAmount.Title = AmountPCTitle;
	
	OpeningBalanceEntryProducts.Company = Company;
	InventoryValuationMethod = InformationRegisters.AccountingPolicy.InventoryValuationMethod(BalanceDate, Company);
	Items.OpeningBalanceEntryProductsInventoryDocumentGroup.Visible = 
		(InventoryValuationMethod = Enums.InventoryValuationMethods.FIFO);
	
EndProcedure

&AtServer
Procedure ReadOpeningBalanceEntryDocuments()
	
	NewBankAndPettyCash = Documents.OpeningBalanceEntry.CreateDocument();
	NewProducts = Documents.OpeningBalanceEntry.CreateDocument();
	NewCounterpartiesSettlements = Documents.OpeningBalanceEntry.CreateDocument();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	OpeningBalanceEntry.Ref AS Ref,
	|	OpeningBalanceEntry.AccountingSection AS AccountingSection,
	|	OpeningBalanceEntry.Date AS Date
	|FROM
	|	Document.OpeningBalanceEntry AS OpeningBalanceEntry
	|WHERE
	|	OpeningBalanceEntry.Company = &Company
	|	AND NOT OpeningBalanceEntry.DeletionMark
	|	AND OpeningBalanceEntry.CreatedViaOpeningBalancesWizard";
	
	Query.SetParameter("Company", Company);
	
	SelectionQueryResult = Query.Execute().Select();
	
	While SelectionQueryResult.Next() Do
		If SelectionQueryResult.AccountingSection = Enums.OpeningBalanceAccountingSections.CashAssets Then
			NewBankAndPettyCash = SelectionQueryResult.Ref.GetObject();
		ElsIf SelectionQueryResult.AccountingSection = Enums.OpeningBalanceAccountingSections.Inventory Then
			NewProducts = SelectionQueryResult.Ref.GetObject();
		ElsIf SelectionQueryResult.AccountingSection = Enums.OpeningBalanceAccountingSections.AccountsReceivablePayable Then
			NewCounterpartiesSettlements = SelectionQueryResult.Ref.GetObject();
		EndIf;
		If BalanceDate > SelectionQueryResult.Date Then
			BalanceDate = SelectionQueryResult.Date;
		EndIf;
	EndDo;
	
	ValueToFormAttribute(NewBankAndPettyCash,			"OpeningBalanceEntryBankAndPettyCash");
	ValueToFormAttribute(NewProducts,					"OpeningBalanceEntryProducts");
	ValueToFormAttribute(NewCounterpartiesSettlements,	"OpeningBalanceEntryCounterpartiesSettlements");
	
EndProcedure

&AtServer
Procedure FillCashAssetsTables()
	
	CashAssetsBank.Clear();
	CashAssetsCash.Clear();
	
	For Each CashAssetsRow In OpeningBalanceEntryBankAndPettyCash.CashAssets Do
		If TypeOf(CashAssetsRow.BankAccountPettyCash) = Type("CatalogRef.BankAccounts") Then
			FillPropertyValues(CashAssetsBank.Add(), CashAssetsRow);
		ElsIf TypeOf(CashAssetsRow.BankAccountPettyCash) = Type("CatalogRef.CashAccounts") Then
			FillPropertyValues(CashAssetsCash.Add(), CashAssetsRow);
		EndIf;
	EndDo;
	FillLineNumbers(CashAssetsBank);
	FillLineNumbers(CashAssetsCash);
	
EndProcedure

// Procedure sets the explanation text.
//
&AtClient
Procedure SetExplanationText()
	
	If mCurrentPageNumber = 0 Then
		Items.DecorationNextActionExplanation.Title = NStr("en = 'To fill in bank and cash account balances, click Next.'; ru = 'Нажмите Далее для заполнения остатков на банковских и кассовых счетах.';pl = 'Aby wypełnić salda rachunku w banku i kasy, kliknij Dalej.';es_ES = 'Para rellenar los saldos de cuentas bancarias y de efectivo, haga clic en Siguiente.';es_CO = 'Para rellenar los saldos de cuentas bancarias y de efectivo, haga clic en Siguiente.';tr = 'Banka ve kasa hesabı bakiyelerini girmek için ""Sonraki"" butonuna tıklayın.';it = 'Per compilare i saldi bancario e di conto di cassa, cliccare su Avanti.';de = 'Klicken Sie auf Weiter, um die Bank- und Liquiditätskontobestände aufzufüllen.'");
	ElsIf mCurrentPageNumber = 1 Then
		Items.DecorationNextActionExplanation.Title = NStr("en = 'To fill in inventory balances, click Next.'; ru = 'Нажмите Далее для заполнения остатков ТМЦ.';pl = 'Aby wypełnić stany magazynowe, kliknij Dalej.';es_ES = 'Para rellenar los saldos de inventario, haga clic en Siguiente.';es_CO = 'Para rellenar los saldos de inventario, haga clic en Siguiente.';tr = 'Stok bakiyelerini girmek için ""Sonraki"" butonuna tıklayın.';it = 'Per compilare i saldi di scorte, cliccare su Avanti.';de = 'Klicken Sie auf Weiter, um den Bestandssaldo aufzufüllen.'");
	ElsIf mCurrentPageNumber = 2 Then
		Items.DecorationNextActionExplanation.Title = NStr("en = 'To fill in supplier balances, click Next.'; ru = 'Для заполнения остатков поставщиков нажмите Далее.';pl = 'Aby wypełnić salda dostawcy, kliknij Dalej.';es_ES = 'Para rellenar los balances del proveedor, haga clic en Siguiente.';es_CO = 'Para rellenar los balances del proveedor, haga clic en Siguiente.';tr = 'Tedarikçi bakiyelerini girmek için ""İleri"" butonuna tıklayın.';it = 'Per compilare i saldi fornitore, cliccare su Avanti.';de = 'Klicken Sie auf Weiter, um die Lieferantensalden aufzufüllen.'");
	ElsIf mCurrentPageNumber = 3 Then
		Items.DecorationNextActionExplanation.Title = NStr("en = 'To fill in customer balances, click Next.'; ru = 'Для заполнения остатков покупателей нажмите Далее.';pl = 'Aby wypełnić salda nabywcy, kliknij Dalej.';es_ES = 'Para rellenar los saldos del cliente, haga clic en Siguiente.';es_CO = 'Para rellenar los saldos del cliente, haga clic en Siguiente.';tr = 'Müşteri bakiyelerini girmek için ""Sonraki"" butonuna tıklayın.';it = 'Per compilare i saldi cliente, cliccare su Avanti.';de = 'Klicken Sie auf Weiter, um die Kundensalden aufzufüllen.'");
	ElsIf mCurrentPageNumber = 4 Then
		Items.DecorationNextActionExplanation.Title = NStr("en = 'To proceed to the final step, click Next.'; ru = 'Нажмите Далее для перехода к заключительному этапу.';pl = 'Aby przejść do ostatniego kroku, kliknij Dalej.';es_ES = 'Para proceder al último paso, haga clic en Siguiente.';es_CO = 'Para proceder al último paso, haga clic en Siguiente.';tr = 'Son adıma geçmek için ""Sonraki"" butonuna tıklayın.';it = 'Per procedere al passaggio finale, cliccare su Avanti.';de = 'Klicken Sie auf Weiter, um Abschlussetappen zu verarbeiten.'");
	ElsIf mCurrentPageNumber = 5 Then
		Items.DecorationNextActionExplanation.Title = NStr("en = 'To complete setting up opening balances, click Finish.'; ru = 'Нажмите Готово, чтобы завершить настройку начальных остатков.';pl = 'Aby zakończyć skonfigurowanie sald początkowych, kliknij Zakończ.';es_ES = 'Para completar la configuración de los saldos iniciales, haga clic en Finalizar.';es_CO = 'Para completar la configuración de los saldos iniciales, haga clic en Finalizar.';tr = 'Açılış bakiyesi ayarını tamamlamak için Bitir butonuna tıklayın.';it = 'Per completare la configurazione dei saldi iniziali, cliccare su Termina.';de = 'Klicken Sie auf Weiter, um die Anfangssaldo-Einstellung zu fertigen.'");
	EndIf;
	
EndProcedure

// Procedure sets the active page.
//
&AtClient
Procedure SetActivePage()
	
	SearchString = "Step" + String(mCurrentPageNumber);
	Items.Pages.CurrentPage = Items.Find(SearchString);
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Opening balances wizard (Step %1/%2)'; ru = 'Помощник заполнения начальных остатков (Шаг %1/%2)';pl = 'Kreator sald otwarcia (Krok %1/%2)';es_ES = 'Asistente de saldos iniciales (Paso %1/%2)';es_CO = 'Asistente de saldos iniciales (Paso %1/%2)';tr = 'Açılış bakiyesi sihirbazı (Adım %1/%2)';it = 'Procedura guidata dei saldi iniziali (Fase %1/%2)';de = 'Assistent zu Anfangssalden (Schritt %1/%2)'"),
		mCurrentPageNumber, mLastPage);
	SetExplanationText();
	
EndProcedure

// Procedure sets the buttons accessibility.
//
&AtClient
Procedure SetButtonsEnabled()
	
	Items.Back.Enabled = mCurrentPageNumber <> mFirstPage;
	
	If mCurrentPageNumber = mLastPage Then
		Items.GoToNext.Title = NStr("en = 'Finish'; ru = 'Готово';pl = 'Koniec';es_ES = 'Finalizar';es_CO = 'Finalizar';tr = 'Bitiş';it = 'Termina';de = 'Abschluss'");
		Items.GoToNext.Representation = ButtonRepresentation.Text;
		Items.GoToNext.Font = New Font(Items.GoToNext.Font,,,True);
	Else
		Items.GoToNext.Title = NStr("en = 'Next'; ru = 'Далее';pl = 'Dalej';es_ES = 'Siguiente';es_CO = 'Siguiente';tr = 'İleri';it = 'Avanti';de = 'Weiter'");
		Items.GoToNext.Representation = ButtonRepresentation.PictureAndText;
		Items.GoToNext.Font = New Font(Items.GoToNext.Font,,,False);
	EndIf;
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.OpeningBalanceEntryProductsInventoryPrice);
	
	Return Fields;
	
EndFunction

// Procedure writes the form changes.
//
&AtServer
Procedure WriteFormChanges(FinishEntering = False)
	
	CommentText = NStr("en = '# Created with the help of the Opening balances wizard.'; ru = '# Создано с помощью Помощника заполнения начальных остатков.';pl = '# Stworzono za pomocą kreatora Sald otwarcia.';es_ES = '# Creado con la ayuda del asistente de saldos iniciales.';es_CO = '# Creado con la ayuda del asistente de saldos iniciales.';tr = '# Açılış bakiyesi sihirbazıyla oluşturuldu.';it = '# Creato grazie al supporto della Procedura guidata dei saldi iniziali.';de = '# Erstellt mit dem Assistenten zu Anfangssalden.'");
	
	If CashAssetsBank.Count() > 0 Or CashAssetsCash.Count() > 0
		Or Not OpeningBalanceEntryBankAndPettyCash.Ref.IsEmpty() Then
		
		OpeningBalanceEntryBankAndPettyCash.CashAssets.Clear();
		For Each CurRow In CashAssetsBank Do
			FillPropertyValues(OpeningBalanceEntryBankAndPettyCash.CashAssets.Add(), CurRow);
		EndDo;
		For Each CurRow In CashAssetsCash Do
			FillPropertyValues(OpeningBalanceEntryBankAndPettyCash.CashAssets.Add(), CurRow);
		EndDo;
		
		EnteringInitialBalancesBankAndCashObject = FormAttributeToValue("OpeningBalanceEntryBankAndPettyCash");
		EnteringInitialBalancesBankAndCashObject.Date = BalanceDate;
		EnteringInitialBalancesBankAndCashObject.Company = Company;
		EnteringInitialBalancesBankAndCashObject.Comment = CommentText;
		EnteringInitialBalancesBankAndCashObject.AccountingSection = Enums.OpeningBalanceAccountingSections.CashAssets;
		EnteringInitialBalancesBankAndCashObject.CreatedViaOpeningBalancesWizard = True;
		EnteringInitialBalancesBankAndCashObject.Write(DocumentWriteMode.Posting);
		ValueToFormAttribute(EnteringInitialBalancesBankAndCashObject, "OpeningBalanceEntryBankAndPettyCash");
		
	EndIf;
	
	If OpeningBalanceEntryProducts.Inventory.Count() > 0
		Or Not OpeningBalanceEntryProducts.Ref.IsEmpty() Then
		OpeningBalanceEntryProductsObject = FormAttributeToValue("OpeningBalanceEntryProducts");
		OpeningBalanceEntryProductsObject.Date = BalanceDate;
		OpeningBalanceEntryProductsObject.Company = Company;
		OpeningBalanceEntryProductsObject.InventoryValuationMethod = InventoryValuationMethod;
		OpeningBalanceEntryProductsObject.AutogenerateInventoryAcqusitionDocuments = True;
		OpeningBalanceEntryProductsObject.Comment = CommentText;
		OpeningBalanceEntryProductsObject.AccountingSection = Enums.OpeningBalanceAccountingSections.Inventory;
		OpeningBalanceEntryProductsObject.CreatedViaOpeningBalancesWizard = True;
		OpeningBalanceEntryProductsObject.Write(DocumentWriteMode.Posting);
		ValueToFormAttribute(OpeningBalanceEntryProductsObject, "OpeningBalanceEntryProducts");
	EndIf;
	
	If OpeningBalanceEntryCounterpartiesSettlements.AccountsPayable.Count() > 0
		Or OpeningBalanceEntryCounterpartiesSettlements.AccountsReceivable.Count() > 0
		Or Not OpeningBalanceEntryCounterpartiesSettlements.Ref.IsEmpty() Then
		
		TableNames = New Array;
		TableNames.Add("AccountsReceivable");
		TableNames.Add("AccountsPayable");
		
		For Each TableName In TableNames Do
			For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements[TableName] Do
				If Not ValueIsFilled(CurRow.Document) Then
					CurRow.Document = Documents[CurRow.DocumentType].EmptyRef();
				EndIf;
			EndDo;
		EndDo;
		
		OpeningBalanceEntryCounterpartiesSettlementsObject = FormAttributeToValue("OpeningBalanceEntryCounterpartiesSettlements");
		OpeningBalanceEntryCounterpartiesSettlementsObject.Date = BalanceDate;
		OpeningBalanceEntryCounterpartiesSettlementsObject.Company = Company;
		OpeningBalanceEntryCounterpartiesSettlementsObject.Autogeneration = True;
		OpeningBalanceEntryCounterpartiesSettlementsObject.Comment = CommentText;
		OpeningBalanceEntryCounterpartiesSettlementsObject.AccountingSection = Enums.OpeningBalanceAccountingSections.AccountsReceivablePayable;
		OpeningBalanceEntryCounterpartiesSettlementsObject.CreatedViaOpeningBalancesWizard = True;
		OpeningBalanceEntryCounterpartiesSettlementsObject.Write(DocumentWriteMode.Posting);
		ValueToFormAttribute(OpeningBalanceEntryCounterpartiesSettlementsObject, "OpeningBalanceEntryCounterpartiesSettlements");
	EndIf;
	
	Constants.UseSeveralWarehouses.Set(DriveClientServer.YesNoToBoolean(UseSeveralWarehouses));
	
	Constants.UseStorageBins.Set(DriveClientServer.YesNoToBoolean(UseStorageBins));
	
	Constants.UseSeveralUnitsForProduct.Set(DriveClientServer.YesNoToBoolean(UseSeveralUnitsForProduct));
	
	Constants.UseCharacteristics.Set(DriveClientServer.YesNoToBoolean(UseCharacteristics));
	
	Constants.UseBatches.Set(DriveClientServer.YesNoToBoolean(UseBatches));
	
	Constants.ForeignExchangeAccounting.Set(DriveClientServer.YesNoToBoolean(ForeignExchangeAccounting));
	
	Constants.FunctionalCurrency.Set(FunctionalCurrency);
	
	Constants.UseContractsWithCounterparties.Set(DriveClientServer.YesNoToBoolean(UseContractsWithCounterparties));
	
	Constants.UseCounterpartyContractTypes.Set(DriveClientServer.YesNoToBoolean(UseCounterpartyContractTypes));
	
	If FinishEntering Then
		Constants.OpeningBalanceIsFilled.Set(True);
	EndIf;
	
	SetAccountsAttributesVisible(, , "AccountsPayable");
	SetAccountsAttributesVisible(, , "AccountsReceivable");
	
EndProcedure

// Procedure calculates the amount in tabular section row.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine()
	
	TabularSectionRow = Items.OpeningBalanceEntryProductsInventory.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
EndProcedure

// Procedure writes changes of accounting in various units.
//
&AtServerNoContext
Procedure WriteChangesAccountingInVariousUOM(UseSeveralUnitsForProduct)
	
	UseSeveralUnitsForProductBoolean = DriveClientServer.YesNoToBoolean(UseSeveralUnitsForProduct);
	
	If Not UseSeveralUnitsForProductBoolean Then
		ErrorText = DataProcessors.AdministrationPanel.CancellationUncheckFunctionalOptionAccountingInVariousUOM();
		If Not IsBlankString(ErrorText) Then
			CommonClientServer.MessageToUser(ErrorText, , "UseSeveralUnitsForProduct");
			UseSeveralUnitsForProduct = DriveClientServer.BooleanToYesNo(True);
			Return;
		EndIf;
	EndIf;
	
	Constants.UseSeveralUnitsForProduct.Set(UseSeveralUnitsForProductBoolean);
	
EndProcedure

// Procedure writes changes of accounting by multiple warehouses.
//
&AtServerNoContext
Procedure WriteChangesAccountingBySeveralWarehouses(UseSeveralWarehouses)
	
	UseSeveralWarehousesBoolean = DriveClientServer.YesNoToBoolean(UseSeveralWarehouses);
	
	If Not UseSeveralWarehousesBoolean Then
		ErrorText = DataProcessors.AdministrationPanel.CancellationUncheckAccountingBySeveralWarehouses();
		If Not IsBlankString(ErrorText) Then
			CommonClientServer.MessageToUser(ErrorText, , "UseSeveralWarehouses");
			UseSeveralWarehouses = DriveClientServer.BooleanToYesNo(True);
			Return;
		EndIf;
	EndIf;
	
	Constants.UseSeveralWarehouses.Set(UseSeveralWarehousesBoolean);
	
EndProcedure

&AtServerNoContext
Procedure WriteChangesAccountingByStorageBins(UseStorageBins)
	
	UseStorageBinsBoolean = DriveClientServer.YesNoToBoolean(UseStorageBins);
	
	If Not UseStorageBinsBoolean Then
		ErrorText = DataProcessors.AdministrationPanel.CancellationUncheckFunctionalOptionAccountingByCells();
		If Not IsBlankString(ErrorText) Then
			CommonClientServer.MessageToUser(ErrorText, , "UseStorageBins");
			UseStorageBins = DriveClientServer.BooleanToYesNo(True);
			Return;
		EndIf;
	EndIf;
	
	Constants.UseStorageBins.Set(UseStorageBinsBoolean);
	
EndProcedure

// Procedure writes changes in characteristics application.
//
&AtServerNoContext
Procedure WriteChangesUseCharacteristics(UseCharacteristics)
	
	UseCharacteristicsBoolean = DriveClientServer.YesNoToBoolean(UseCharacteristics);
	
	If Not UseCharacteristicsBoolean Then
		ErrorText = DataProcessors.AdministrationPanel.CancellationUncheckFunctionalOptionUseCharacteristics();
		If Not IsBlankString(ErrorText) Then
			CommonClientServer.MessageToUser(ErrorText, , "UseCharacteristics");
			UseCharacteristics = DriveClientServer.BooleanToYesNo(True);
			Return;
		EndIf;
	EndIf;
	
	Constants.UseCharacteristics.Set(UseCharacteristicsBoolean);
	
EndProcedure

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
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

// Procedure writes the changes in batches usage.
//
&AtServerNoContext
Procedure WriteChangesUseBatches(UseBatches)
	
	UseBatchesBoolean = DriveClientServer.YesNoToBoolean(UseBatches);
	
	If Not UseBatchesBoolean Then
		ErrorText = DataProcessors.AdministrationPanel.CancellationUncheckFunctionalOptionUseBatches();
		If Not IsBlankString(ErrorText) Then
			CommonClientServer.MessageToUser(ErrorText, , "UseBatches");
			UseBatches = DriveClientServer.BooleanToYesNo(True);
			Return;
		EndIf;
	EndIf;
	
	Constants.UseBatches.Set(UseBatchesBoolean);
	
EndProcedure

&AtServerNoContext
Procedure WriteChangesUseContractsWithCounterparties(UseContractsWithCounterparties)
	
	UseContractsWithCounterpartiesBoolean = DriveClientServer.YesNoToBoolean(UseContractsWithCounterparties);
	
	If Not UseContractsWithCounterpartiesBoolean Then
		ErrorText = DataProcessors.AdministrationPanel.CancellationUncheckUseContractsWithCounterparties();
		If Not IsBlankString(ErrorText) Then
			CommonClientServer.MessageToUser(ErrorText, , "UseContractsWithCounterparties");
			UseContractsWithCounterparties = DriveClientServer.BooleanToYesNo(True);
			Return;
		EndIf;
	EndIf;
	
	Constants.UseContractsWithCounterparties.Set(UseContractsWithCounterpartiesBoolean);
	
EndProcedure

&AtServerNoContext
Procedure WriteChangesUseCounterpartyContractTypes(UseCounterpartyContractTypes)
	
	UseCounterpartyContractTypesBoolean = DriveClientServer.YesNoToBoolean(UseCounterpartyContractTypes);
	
	Constants.UseCounterpartyContractTypes.Set(UseCounterpartyContractTypesBoolean);
	
EndProcedure

// Function puts the Inventory tabular section in
// temporary storage and returns the address.
//
&AtServer
Function PlaceInventoryToStorage()
	
	Return PutToTempStorage(
		OpeningBalanceEntryProducts.Inventory.Unload(,
			"Products,
			|Characteristic,
			|Batch,
			|MeasurementUnit,
			|Price"
		),
		UUID
	);
	
EndFunction

// Procedure writes changes of currency operations accounting.
//
&AtServer
Procedure WriteChangesCurrencyTransactionsAccounting()
	
	ForeignExchangeAccountingBoolean = DriveClientServer.YesNoToBoolean(ForeignExchangeAccounting);
	
	If Not ForeignExchangeAccountingBoolean Then
		ErrorText = DataProcessors.AdministrationPanel.CancellationUncheckForeignExchangeAccounting();
		If Not IsBlankString(ErrorText) Then
			CommonClientServer.MessageToUser(ErrorText, , "ForeignExchangeAccounting");
			ForeignExchangeAccounting = DriveClientServer.BooleanToYesNo(True);
			Return;
		EndIf;
	EndIf;
	
	Constants.ForeignExchangeAccounting.Set(ForeignExchangeAccountingBoolean);
	
	If ForeignExchangeAccountingBoolean Then
		Items.FunctionalCurrency.ReadOnly = False;
		Items.FunctionalCurrency.AutoChoiceIncomplete = True;
		Items.FunctionalCurrency.AutoMarkIncomplete = True;
	Else
		Items.FunctionalCurrency.ReadOnly = True;
		Items.FunctionalCurrency.AutoChoiceIncomplete = False;
		Items.FunctionalCurrency.AutoMarkIncomplete = False;
	EndIf;
	
EndProcedure

// It receives data set from the server for the CashAssetsBankAccountPettyCashOnChange procedure.
//
&AtServerNoContext
Function GetDataCashAssetsBankAccountPettyCashOnChange(BankAccountPettyCash)

	StructureData = New Structure();

	If TypeOf(BankAccountPettyCash) = Type("CatalogRef.CashAccounts") Then
		StructureData.Insert("Currency", BankAccountPettyCash.CurrencyByDefault);
	ElsIf TypeOf(BankAccountPettyCash) = Type("CatalogRef.BankAccounts") Then
		StructureData.Insert("Currency", BankAccountPettyCash.CashCurrency);
	Else
		StructureData.Insert("Currency", Catalogs.Currencies.EmptyRef());
	EndIf;
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataStructuralUnitOnChange(StructureData)
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

// Procedure checks filling of the mandatory attributes when you go to the next page.
//
&AtClient
Procedure ExecuteActionsOnTransitionToNextPage(Cancel)
	
	ClearMessages();
	
	If mCurrentPageNumber = 1 Then
		
		If DriveClientServer.YesNoToBoolean(ForeignExchangeAccounting) And Not ValueIsFilled(FunctionalCurrency) Then
			MessageText = NStr("en = 'Specify functional currency.'; ru = 'Укажите функциональную валюту.';pl = 'Podaj walutę funkcjonalną.';es_ES = 'Especificar la moneda funcional.';es_CO = 'Especificar la moneda funcional.';tr = 'Fonksiyonel para birimini belirtin.';it = 'Specificare valuta nazionale.';de = 'Geben Sie die Landeswährung an.'");
			CommonClientServer.MessageToUser(MessageText, , "FunctionalCurrency", , Cancel);
		EndIf;
		
		CashAssetsTables = New Array;
		CashAssetsTables.Add(New Structure("Name, Table", "CashAssetsBank", CashAssetsBank));
		CashAssetsTables.Add(New Structure("Name, Table", "CashAssetsCash", CashAssetsCash));
		
		For Each CashAssetTable In CashAssetsTables Do
			
			For Each CurRow In CashAssetTable.Table Do
				If Not ValueIsFilled(CurRow.BankAccountPettyCash) Then
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Specify the bank account or cash account in line %1.'; ru = 'Укажите банковский или кассовый счет в строке %1.';pl = 'Określ rachunek bankowy lub konto gotówkowe w wierszu %1.';es_ES = 'Especifique la cuenta bancaria o la cuenta de efectivo en línea %1.';es_CO = 'Especifique la cuenta bancaria o la cuenta de efectivo en línea %1.';tr = '%1 satırında banka hesabını veya kasa hesabını belirtin.';it = 'Specificare conto corrente o conto di cassa nella riga %1.';de = 'Geben Sie das Bankkonto oder Liquiditätskonto in Zeile %1 an.'"), CurRow.LineNumber);
					CommonClientServer.MessageToUser(
						MessageText,
						,
						CommonClientServer.PathToTabularSection(CashAssetTable.Name, CurRow.LineNumber, "BankAccountPettyCash"),
						,
						Cancel);
				EndIf;
				If Not ValueIsFilled(CurRow.CashCurrency) Then
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Specify currency in line %1.'; ru = 'Укажите валюту в строке %1.';pl = 'Określ walutę w wierszu %1.';es_ES = 'Moneda no especificada en la línea %1.';es_CO = 'Moneda no especificada en la línea %1.';tr = '%1 satırında para birimini belirtin.';it = 'Specificare la valuta nella linea %1.';de = 'Geben Sie die Währung in Zeile %1 an.'"),
						CurRow.LineNumber);
					CommonClientServer.MessageToUser(
						MessageText,
						,
						CommonClientServer.PathToTabularSection(CashAssetTable.Name, CurRow.LineNumber, "CashCurrency"),
						,
						Cancel);
				EndIf;
				If Not ValueIsFilled(CurRow.AmountCur) Then
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Specify amount in line %1.'; ru = 'Укажите сумму в строке %1.';pl = 'Podaj wartość w wierszu %1.';es_ES = 'Especificar el importe en la línea %1.';es_CO = 'Especificar el importe en la línea %1.';tr = '%1 satırında tutarı belirtin.';it = 'Specificare l''importo nella linea %1.';de = 'Geben Sie den Betrag in Zeile %1 an.'"),
						CurRow.LineNumber);
					CommonClientServer.MessageToUser(
						MessageText,
						,
						CommonClientServer.PathToTabularSection(CashAssetTable.Name, CurRow.LineNumber, "AmountCur"),
						,
						Cancel);
				EndIf;
				If ValueIsFilled(CurRow.AmountCur) And ValueIsFilled(CurRow.Amount) Then
					If (CurRow.AmountCur > 0 And CurRow.Amount < 0) Or (CurRow.AmountCur < 0 And CurRow.Amount > 0) Then
						MessageText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'On the ""Bank"" tab, in line #%1, ""Amount"" and ""Amount in currency"" must be numbers of the same type: positive or negative.'; ru = 'На вкладке ""Банк"" в строке №%1 ""Сумма"" и ""Сумма (вал.)"" должны быть числами одного типа: положительными или отрицательными.';pl = 'Na karcie ""Bank"", w wierszu nr #%1, ""Kwota"" i ""Kwota w walucie"" powinny być liczbami tego samego typu: dodatnimi lub ujemnymi.';es_ES = 'En la pestaña ""Banco"", en la línea #%1, el ""Importe"" e ""Importe en la moneda"" deben ser números del mismo tipo: positivos o negativos.';es_CO = 'En la pestaña ""Banco"", en la línea #%1, el ""Importe"" e ""Importe en la moneda"" deben ser números del mismo tipo: positivos o negativos.';tr = '""Banka"" sekmesinin %1 satırında, ""Tutar"" ve ""Para biriminde tutar"" aynı türde sayılar olmalıdır: artı veya eksi.';it = 'Nella scheda ""Banca"", nella riga #%1, ""Importo"" e ""Importo in valuta"" devono esserci numero dello stesso tipo: positivo o negativo.';de = 'Die Nummern müssen auf der Registerkarte ""Bank"", in der Zeile Nr. %1, ""Betrag"" und ""Betrag in Währung"" denselben Typ haben: positiv oder negativ.'"),
							CurRow.LineNumber);
						CommonClientServer.MessageToUser(
							MessageText,
							,
							CommonClientServer.PathToTabularSection(CashAssetTable.Name, CurRow.LineNumber, "AmountCur"),
							,
							Cancel);
					EndIf;
				EndIf;
				If CashAssetTable.Name = "CashAssetsBank" And (CurRow.AmountCur < 0 Or CurRow.Amount < 0) Then
					
					OverdraftRow = BankAccountUseOverdraft(CurRow.BankAccountPettyCash, BalanceDate);
					AllowNegativeBalance = AllowNegativeBalanceBankAccount(CurRow.BankAccountPettyCash);
					
					If (CurRow.AmountCur < 0 Or CurRow.Amount < 0) And Not AllowNegativeBalance And Not OverdraftRow.UseOverdraft Then
						NegativeMessageTemplate = NStr("en = 'On the ""Bank"" tab, in line #%1, the bank account does not allow an overdraft or negative balance.'; ru = 'На вкладке ""Банк"" в строке №%1 на банковском счете не разрешен овердрафт или отрицательный остаток.';pl = 'Na karcie ""Bank"", w wierszu nr%1, rachunek bankowy nie dopuszcza przekroczenia stanu rachunku lub salda ujemnego.';es_ES = 'En la pestaña ""Banco"", en la línea#%1, la cuenta bancaria no permite un sobregiro o un saldo negativo.';es_CO = 'En la pestaña ""Banco"", en la línea#%1, la cuenta bancaria no permite un sobregiro o un saldo negativo.';tr = '""Banka"" sekmesinin %1 satırında banka hesabı fazla para çekmeye veya eksi bakiyeye izin vermiyor.';it = 'Nella scheda ""Banca"", nella riga #%1, il conto corrente non permette uno scoperto o saldo negativo.';de = 'Die Bankkonten gestatten auf der Registerkarte ""Bank"", in der Zeile Nr. %1, keine Überziehung und keinen negativen Saldo.'");
						MessageText = StringFunctionsClientServer.SubstituteParametersToString(NegativeMessageTemplate,
							CurRow.LineNumber);
						CommonClientServer.MessageToUser(
							MessageText,
							,
							CommonClientServer.PathToTabularSection(CashAssetTable.Name, CurRow.LineNumber, ?(CurRow.AmountCur < 0, "AmountCur", "Amount")),
							,
							Cancel);
					EndIf;
						
					If (CurRow.AmountCur < 0 Or CurRow.Amount < 0) And Not AllowNegativeBalance And OverdraftRow.UseOverdraft
							And (OverdraftRow.Limit < -CurRow.AmountCur Or OverdraftRow.Limit < -CurRow.Amount) Then
							
						LimitExceedMessageTemplate = NStr("en = 'On the ""Bank"" tab, in line #%1, the bank account has a negative balance.
														|The overdraft limit is insufficient to cover it.'; 
														|ru = 'На вкладке ""Банк"" в строке №%1 на банковском счете имеется отрицательный остаток.
														|Лимита овердрафта недостаточно для его покрытия.';
														|pl = 'Na karcie ""Bank"", w wierszu nr %1, rachunek bankowy ma saldo ujemne.
														|Limit przekroczenia limit stanu rachunku jest niewystarczający aby pokryć go.';
														|es_ES = 'En la pestaña ""Banco"", en la línea#%1, la cuenta bancaria tiene un saldo negativo.
														| El límite de sobregiro es insuficiente para cubrirlo.';
														|es_CO = 'En la pestaña ""Banco"", en la línea#%1, la cuenta bancaria tiene un saldo negativo.
														| El límite de sobregiro es insuficiente para cubrirlo.';
														|tr = '""Banka"" sekmesinin %1 satırında banka hesabının bakiyesi eksi.
														|Fazla para çekme limiti tutarı karşılamıyor.';
														|it = 'Nella scheda ""Banca"", nella riga #%1, il conto corrente ha un saldo negativo.
														|Il limite dello scoperto è insufficiente a coprirlo.';
														|de = 'Das Bankkonto hat auf der Registerkarte ""Bank"" in der Zeile Nr. %1, einen negativen Saldo .
														|Die Überziehungsgrenze ist  für dessen Deckung nicht ausreichend.'");
						MessageText = StringFunctionsClientServer.SubstituteParametersToString(LimitExceedMessageTemplate,
							CurRow.LineNumber);
						CommonClientServer.MessageToUser(
							MessageText,
							,
							CommonClientServer.PathToTabularSection(CashAssetTable.Name, CurRow.LineNumber, ?(CurRow.AmountCur < 0, "AmountCur", "Amount")),
							,
							Cancel);
							
					EndIf;
					
				EndIf;
				If DriveClientServer.YesNoToBoolean(ForeignExchangeAccounting) And Not ValueIsFilled(CurRow.Amount) Then
				
					CommonClientServer.MessageToUser(
						StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'Specify amount in presentation currency in line %1.'; ru = 'Укажите сумму в валюте представления отчетности в строке %1.';pl = 'Podaj kwotę w walucie prezentacji w wierszu %1.';es_ES = 'Especificar el importe en la moneda de presentación en la línea %1.';es_CO = 'Especificar el importe en la moneda de presentación en la línea %1.';tr = '%1 satırında tutarı finansal tablo para biriminde belirtin.';it = 'Specificare l''importo nella valuta contabile nella linea %1.';de = 'Geben Sie den Betrag in der Währung für die Berichtserstattung in der Zeile %1 an.'"),
							CurRow.LineNumber),,
						CommonClientServer.PathToTabularSection(CashAssetTable.Name, CurRow.LineNumber, "Amount"),
						,
						Cancel);
				EndIf;
			EndDo;
			
		EndDo;
		
	ElsIf mCurrentPageNumber = 2 Then
		
		For Each CurRow In OpeningBalanceEntryProducts.Inventory Do
			If Not ValueIsFilled(CurRow.StructuralUnit) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify business unit in line %1.'; ru = 'Укажите структурную единицу в строке %1.';pl = 'Określ jednostkę biznesową w wierszu %1.';es_ES = 'Especificar unidad empresarial en línea %1.';es_CO = 'Especificar unidad del negocio en línea %1.';tr = '%1 satırında departmanı belirtin.';it = 'Specificare il Dipartimento nella linea %1.';de = 'Geben Sie die Abteilung in Zeile %1 an.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("Inventory", CurRow.LineNumber, "StructuralUnit"),
					"OpeningBalanceEntryProducts",
					Cancel);
			EndIf;
			If Not ValueIsFilled(CurRow.Products) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify a product in line %1.'; ru = 'Укажите номенклатуру в строке %1.';pl = 'Określ produkt w wierszu %1.';es_ES = 'Especifique un producto en línea %1.';es_CO = 'Especifique un producto en línea %1.';tr = '%1 satırında bir ürün belirtin.';it = 'Selezionare un articolo nella riga %1.';de = 'Geben Sie das Produkt in Zeile %1 an.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("Inventory", CurRow.LineNumber, "Products"),
					"OpeningBalanceEntryProducts",
					Cancel);
			EndIf;
			CheckBatchesFilling(Cancel);
			If Not ValueIsFilled(CurRow.MeasurementUnit) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify unit of measurement in line %1.'; ru = 'Укажите единицу измерения в строке %1.';pl = 'Określ jednostkę miary w wierszu %1.';es_ES = 'Especificar la unidad de mesura en línea %1.';es_CO = 'Especificar la unidad de mesura en línea %1.';tr = '%1 satırında ölçü birimini belirtin.';it = 'Specificare unità di misura nella linea %1.';de = 'Geben Sie die Maßeinheit in Zeile %1 an.'"), 
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("Inventory", CurRow.LineNumber, "MeasurementUnit"),
					"OpeningBalanceEntryProducts",
					Cancel);
			EndIf;
			If Not ValueIsFilled(CurRow.Quantity) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify quantity in line %1.'; ru = 'Укажите количество в строке %1.';pl = 'Określ ilość w wierszu %1.';es_ES = 'Especificar la cantidad en línea %1.';es_CO = 'Especificar la cantidad en línea %1.';tr = '%1 satırında miktarı belirtin.';it = 'Specificare la quantità nella linea %1.';de = 'Geben Sie die Menge in Zeile %1 an.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("Inventory", CurRow.LineNumber, "Quantity"),
					"OpeningBalanceEntryProducts",
					Cancel);
			EndIf;
			
			If InventoryValuationMethod = PredefinedValue("Enum.InventoryValuationMethods.FIFO") Then
				
				If Not ValueIsFilled(CurRow.DocumentType) Then
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Specify document type in line %1.'; ru = 'Укажите тип документа в строке %1.';pl = 'Podaj typ dokumentu w wierszu %1.';es_ES = 'Especificar el tipo de documento en la línea %1.';es_CO = 'Especificar el tipo de documento en la línea %1.';tr = '%1 satırında belge türünü belirtin.';it = 'Indicare il tipo di documento nella riga %1.';de = 'Geben Sie den Dokumententyp in Zeile %1 an.'"),
						CurRow.LineNumber);
					CommonClientServer.MessageToUser(
						MessageText,
						,
						CommonClientServer.PathToTabularSection("Inventory", CurRow.LineNumber, "DocumentType"),
						"OpeningBalanceEntryProducts",
						Cancel);
				EndIf;
				
				If ValueIsFilled(CurRow.DocumentType)
					And CurRow.DocumentType <> MetadataOpeningBalanceEntryName Then
					
					If Not ValueIsFilled(CurRow.DocumentNumber) Then 
						MessageText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'Specify number in line %1.'; ru = 'Укажите номер в строке %1.';pl = 'Określ numer w wierszu %1.';es_ES = 'Especifique un número en la línea %1.';es_CO = 'Especifique un número en la línea %1.';tr = '%1 satırında numarayı belirtin.';it = 'Indicare il numero nella riga %1.';de = 'Geben Sie die Nummer in Zeile %1 ein.'"),
							CurRow.LineNumber);
						CommonClientServer.MessageToUser(
							MessageText,
							,
							CommonClientServer.PathToTabularSection("Inventory", CurRow.LineNumber, "DocumentNumber"),
							"OpeningBalanceEntryProducts",
							Cancel);
					Endif;
					
					If Not ValueIsFilled(CurRow.DocumentDate) Then
						MessageText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'Specify date in line %1.'; ru = 'Укажите дату в строке %1.';pl = 'Określ datę w wierszu %1.';es_ES = 'Especifique una fecha en la línea %1.';es_CO = 'Especifique una fecha en la línea %1.';tr = '%1 satırında tarihi belirtin.';it = 'Indicare la data nella riga %1.';de = 'Geben Sie das Datum in Zeile %1 ein.'"),
							CurRow.LineNumber);
						CommonClientServer.MessageToUser(
							MessageText,
							,
							CommonClientServer.PathToTabularSection("Inventory", CurRow.LineNumber, "DocumentDate"),
							"OpeningBalanceEntryProducts",
							Cancel);
					Endif;
					
				EndIf; 
			EndIf;
		EndDo;
		
	ElsIf mCurrentPageNumber = 3 Then
		
		For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements.AccountsPayable Do
			If Not ValueIsFilled(CurRow.Counterparty) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify counterparty in line %1.'; ru = 'Укажите контрагента в строке %1.';pl = 'Określ kontrahenta w wierszu %1.';es_ES = 'Especificar la contraparte en línea %1.';es_CO = 'Especificar la contraparte en línea %1.';tr = '%1 satırında cari hesabı belirtin.';it = 'Specificare la controparte nella linea %1.';de = 'Den Geschäftspartner in Zeile %1 angeben.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("AccountsPayable", CurRow.LineNumber, "Counterparty"),
					"OpeningBalanceEntryCounterpartiesSettlements",
					Cancel);
			EndIf;
			If Not ValueIsFilled(CurRow.Contract) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify contract in the line %1.'; ru = 'Укажите договор в строке %1.';pl = 'Podaj kontrakt w wierszu %1.';es_ES = 'Especificar el contrato en línea %1.';es_CO = 'Especificar el contrato en línea %1.';tr = '%1 satırında sözleşmeyi belirtin.';it = 'Specificare il contratto nella linea %1.';de = 'Geben Sie den Vertrag in der Zeile %1 an.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("AccountsPayable", CurRow.LineNumber, "Contract"),
					"OpeningBalanceEntryCounterpartiesSettlements",
					Cancel);
			EndIf;
			If Not ValueIsFilled(CurRow.AmountCur) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify amount in line %1.'; ru = 'Укажите сумму в строке %1.';pl = 'Podaj wartość w wierszu %1.';es_ES = 'Especificar el importe en la línea %1.';es_CO = 'Especificar el importe en la línea %1.';tr = '%1 satırında tutarı belirtin.';it = 'Specificare l''importo nella linea %1.';de = 'Geben Sie den Betrag in Zeile %1 an.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("AccountsPayable", CurRow.LineNumber, "AmountCur"),
					"OpeningBalanceEntryCounterpartiesSettlements",
					Cancel);
			EndIf;
			If DriveClientServer.YesNoToBoolean(ForeignExchangeAccounting) And Not ValueIsFilled(CurRow.Amount) Then
				CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify amount in presentation currency in line %1.'; ru = 'Укажите сумму в валюте представления отчетности в строке %1.';pl = 'Podaj kwotę w walucie prezentacji w wierszu %1.';es_ES = 'Especificar el importe en la moneda de presentación en la línea %1.';es_CO = 'Especificar el importe en la moneda de presentación en la línea %1.';tr = '%1 satırında tutarı finansal tablo para biriminde belirtin.';it = 'Specificare l''importo nella valuta contabile nella linea %1.';de = 'Geben Sie den Betrag in der Währung für die Berichtserstattung in der Zeile %1 an.'"),
					CurRow.LineNumber),,
					CommonClientServer.PathToTabularSection("AccountsPayable", CurRow.LineNumber, "Amount"),
					"OpeningBalanceEntryCounterpartiesSettlements",
					Cancel);
			EndIf;
			If Not ValueIsFilled(CurRow.DocumentType) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify document type in the line %1.'; ru = 'Укажите тип документа в строке %1.';pl = 'Podaj typ dokumentu w wierszu %1.';es_ES = 'Especificar el tipo de documento en la línea %1.';es_CO = 'Especificar el tipo de documento en la línea %1.';tr = '%1 satırında belge türünü belirtin.';it = 'Specificare il tipo di documento nella riga %1.';de = 'Geben Sie den Dokumententyp in der Zeile %1 an.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("AccountsPayable", CurRow.LineNumber, "DocumentType"),
					"OpeningBalanceEntryCounterpartiesSettlements",
					Cancel);
			EndIf;
			If Not ValueIsFilled(CurRow.DocumentNumber) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify document number in the line %1.'; ru = 'Укажите номер документа в строке %1.';pl = 'Podaj numer dokumentu w wierszu %1.';es_ES = 'Especificar el número de documento en la línea %1.';es_CO = 'Especificar el número de documento en la línea %1.';tr = '%1 satırında belge numarasını belirtin.';it = 'Specificare il numero di documento nella riga %1.';de = 'Geben Sie die Belegnummer in der Zeile %1 an.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("AccountsPayable", CurRow.LineNumber, "DocumentNumber"),
					"OpeningBalanceEntryCounterpartiesSettlements",
					Cancel);
			EndIf;
			If Not ValueIsFilled(CurRow.DocumentDate) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify document date in the line %1.'; ru = 'Укажите дату документа в строке %1.';pl = 'Podaj datę dokumentu w wierszu %1.';es_ES = 'Especificar la fecha del documento en la línea %1.';es_CO = 'Especificar la fecha del documento en la línea %1.';tr = '%1 satırında belge tarihini belirtin.';it = 'Specificare la data del documento nella riga %1.';de = 'Geben Sie das Belegdatum in der Zeile %1 an.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("AccountsPayable", CurRow.LineNumber, "DocumentDate"),
					"OpeningBalanceEntryCounterpartiesSettlements",
					Cancel);
			EndIf;
		EndDo;
		
	ElsIf mCurrentPageNumber = 4 Then
		
		For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements.AccountsReceivable Do
			If Not ValueIsFilled(CurRow.Counterparty) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify counterparty in line %1.'; ru = 'Укажите контрагента в строке %1.';pl = 'Określ kontrahenta w wierszu %1.';es_ES = 'Especificar la contraparte en línea %1.';es_CO = 'Especificar la contraparte en línea %1.';tr = '%1 satırında cari hesabı belirtin.';it = 'Specificare la controparte nella linea %1.';de = 'Den Geschäftspartner in Zeile %1 angeben.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("AccountsReceivable", CurRow.LineNumber, "Counterparty"),
					"OpeningBalanceEntryCounterpartiesSettlements",
					Cancel);
			EndIf;
			If Not ValueIsFilled(CurRow.Contract) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify contract in line %1.'; ru = 'Укажите договор в строке %1.';pl = 'Określ umowę w wierszu %1.';es_ES = 'Especificar el contrato en línea %1.';es_CO = 'Especificar el contrato en línea %1.';tr = '%1 satırında sözleşmeyi belirtin.';it = 'Specificare il contratto nella linea %1.';de = 'Geben Sie den Vertrag in Zeile %1 an.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("AccountsReceivable", CurRow.LineNumber, "Contract"),
					"OpeningBalanceEntryCounterpartiesSettlements",
					Cancel);
			EndIf;
			If Not ValueIsFilled(CurRow.AmountCur) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify amount in the line %1.'; ru = 'Укажите сумму в строке %1.';pl = 'Podaj wartość w tym wierszu %1';es_ES = 'Especificar la cantidad en línea %1.';es_CO = 'Especificar la cantidad en línea %1.';tr = '%1 satırında tutarı belirtin.';it = 'Specificare l''importo nella linea %1.';de = 'Geben Sie den Betrag in der Zeile %1 an.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("AccountsReceivable", CurRow.LineNumber, "AmountCur"),
					"OpeningBalanceEntryCounterpartiesSettlements",
					Cancel);
			EndIf;
			If DriveClientServer.YesNoToBoolean(ForeignExchangeAccounting) And Not ValueIsFilled(CurRow.Amount) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify amount in presentation currency in line %1.'; ru = 'Укажите сумму в валюте представления отчетности в строке %1.';pl = 'Podaj kwotę w walucie prezentacji w wierszu %1.';es_ES = 'Especificar el importe en la moneda de presentación en la línea %1.';es_CO = 'Especificar el importe en la moneda de presentación en la línea %1.';tr = '%1 satırında tutarı finansal tablo para biriminde belirtin.';it = 'Specificare l''importo nella valuta contabile nella linea %1.';de = 'Geben Sie den Betrag in der Währung für die Berichtserstattung in der Zeile %1 an.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("AccountsReceivable", CurRow.LineNumber, "Amount"),
					"OpeningBalanceEntryCounterpartiesSettlements",
					Cancel);
			EndIf;
			If Not ValueIsFilled(CurRow.DocumentType) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify document type in the line %1.'; ru = 'Укажите тип документа в строке %1.';pl = 'Podaj typ dokumentu w wierszu %1.';es_ES = 'Especificar el tipo de documento en la línea %1.';es_CO = 'Especificar el tipo de documento en la línea %1.';tr = '%1 satırında belge türünü belirtin.';it = 'Specificare il tipo di documento nella riga %1.';de = 'Geben Sie den Dokumententyp in der Zeile %1 an.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("AccountsReceivable", CurRow.LineNumber, "DocumentType"),
					"OpeningBalanceEntryCounterpartiesSettlements",
					Cancel);
			EndIf;
			If Not ValueIsFilled(CurRow.DocumentNumber) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify document number in the line %1.'; ru = 'Укажите номер документа в строке %1.';pl = 'Podaj numer dokumentu w wierszu %1.';es_ES = 'Especificar el número de documento en la línea %1.';es_CO = 'Especificar el número de documento en la línea %1.';tr = '%1 satırında belge numarasını belirtin.';it = 'Specificare il numero di documento nella riga %1.';de = 'Geben Sie die Belegnummer in der Zeile %1 an.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("AccountsReceivable", CurRow.LineNumber, "DocumentNumber"),
					"OpeningBalanceEntryCounterpartiesSettlements",
					Cancel);
			EndIf;
			If Not ValueIsFilled(CurRow.DocumentDate) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Specify document date in the line %1.'; ru = 'Укажите дату документа в строке %1.';pl = 'Podaj datę dokumentu w wierszu %1.';es_ES = 'Especificar la fecha del documento en la línea %1.';es_CO = 'Especificar la fecha del documento en la línea %1.';tr = '%1 satırında belge tarihini belirtin.';it = 'Specificare la data del documento nella riga %1.';de = 'Geben Sie das Belegdatum in der Zeile %1 an.'"),
					CurRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					,
					CommonClientServer.PathToTabularSection("AccountsReceivable", CurRow.LineNumber, "DocumentDate"),
					"OpeningBalanceEntryCounterpartiesSettlements",
					Cancel);
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

// Imports the form settings.
// If settings are imported during form attribute
// change, for example for new company, it shall be checked
// whether extension for file handling is enabled.
//
// Data in attributes of the processed object will be a flag of connection failure:
// ExportFile, ImportFile
//
&AtServer
Procedure ImportFormSettings()
	
	Settings = SystemSettingsStorage.Load("CommonForm.OpeningBalanceFillingWizard", "FormSettings");
	
	If Settings <> Undefined Then
		AssistantSimpleUseMode = Settings.Get("AssistantSimpleUseMode");
	EndIf;
	
EndProcedure

// Saves form settings.
//
&AtServer
Procedure SaveFormSettings()
	
	Settings = New Map;
	Settings.Insert("AssistantSimpleUseMode", AssistantSimpleUseMode);
	SystemSettingsStorage.Save("CommonForm.OpeningBalanceFillingWizard", "FormSettings", Settings);
	
EndProcedure

&AtServer
Procedure SetFormConditionalAppearance()
	
	// OpeningBalanceEntryProductsInventoryDocument
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryProducts.Inventory.Document",
		Undefined,
		DataCompositionComparisonType.NotFilled);
		
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryProducts.Inventory.DocumentType",
		Metadata.Documents.OpeningBalanceEntry.Name,
		DataCompositionComparisonType.NotEqual);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OpeningBalanceEntryProductsInventoryDocument");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", NStr("en = '<generated automatically>'; ru = '<сформировано автоматически>';pl = '<wygenerowano automatycznie>';es_ES = '<generado automáticamentey>';es_CO = '<generado automáticamentey>';tr = '<otomatik oluşturuldu>';it = '<creato automaticamente>';de = '<automatisch generiert>'"));
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
		
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryProducts.Inventory.DocumentType",
		Metadata.Documents.OpeningBalanceEntry.Name,
		DataCompositionComparisonType.Equal);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OpeningBalanceEntryProductsInventoryDocument");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", NStr("en = '<this document>'; ru = '<этот документ>';pl = '<ten dokument>';es_ES = '<este documento>';es_CO = '<este documento>';tr = '<bu belge>';it = '<questo documento>';de = '<dieses Dokument>'"));
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// OpeningBalanceEntryProductsInventoryDocumentNumberDate
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryProducts.Inventory.DocumentType",
		Metadata.Documents.OpeningBalanceEntry.Name,
		DataCompositionComparisonType.Equal);
		
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OpeningBalanceEntryProductsInventoryDocumentNumber");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OpeningBalanceEntryProductsInventoryDocumentDate");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	FilterOrGroup = WorkWithForm.CreateFilterItemGroup(NewConditionalAppearance.Filter, DataCompositionFilterItemsGroupType.OrGroup);
	
	WorkWithForm.AddFilterItem(FilterOrGroup,
		"OpeningBalanceEntryProducts.Inventory.Document",
		Undefined,
		DataCompositionComparisonType.Filled);
		
	WorkWithForm.AddFilterItem(FilterOrGroup,
		"OpeningBalanceEntryProducts.Inventory.DocumentType",
		Metadata.Documents.OpeningBalanceEntry.Name,
		DataCompositionComparisonType.Equal);
		
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OpeningBalanceEntryProductsInventoryDocumentNumber");
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OpeningBalanceEntryProductsInventoryDocumentDate");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableDocument
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryCounterpartiesSettlements.AccountsReceivable.Document",
		,
		DataCompositionComparisonType.NotFilled);
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>",
		NStr("en = 'generated automatically'; ru = 'создан автоматически';pl = 'wygenerowano automatycznie';es_ES = 'generar automáticamente';es_CO = 'generar automáticamente';tr = 'otomatik oluşturuldu';it = 'generato automaticamente';de = 'automatisch generiert'"));
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableDocument");
	
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	
	// OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableDocument
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryCounterpartiesSettlements.AccountsPayable.Document",
		,
		DataCompositionComparisonType.NotFilled);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableDocument");
	
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	
	// OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableContract
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryCounterpartiesSettlements.AccountsReceivable.Counterparty",
		,
		DataCompositionComparisonType.Filled);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryCounterpartiesSettlements.AccountsReceivable.DoOperationsByContracts",
		False,
		DataCompositionComparisonType.Equal);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableContract");
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>",
		NStr("en = 'Billing details by contracts are not specified for the counterparty'; ru = 'Для контрагента не установлены расчеты по договорам';pl = 'Dane rozliczeniowe według kontraktów nie są określone dla kontrahenta';es_ES = 'Los detalles del presupuesto no están especificados para la contraparte';es_CO = 'Los detalles del presupuesto no están especificados para la contraparte';tr = 'Cari hesap için sözleşmelerle fatura detayları belirtilmemiştir';it = 'I dettagli di fatturazione per contratti non sono specificati per la controparte';de = 'Abrechnungsdetails nach Verträgen sind für die Geschäftspartner nicht angegeben'"));
	
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableSalesOrder
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryCounterpartiesSettlements.AccountsReceivable.Counterparty",
		,
		DataCompositionComparisonType.Filled);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryCounterpartiesSettlements.AccountsReceivable.DoOperationsByOrders",
		False,
		DataCompositionComparisonType.Equal);
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>",
		NStr("en = 'Billing details by orders are not specified for the counterparty'; ru = 'Для контрагента не установлены расчеты по заказам';pl = 'Dane rozliczeniowe według zamówień nie są określone dla kontrahenta';es_ES = 'Los detalles del presupuesto por órdenes no están especificados para la contraparte';es_CO = 'Los detalles del presupuesto por órdenes no están especificados para la contraparte';tr = 'Cari hesap için siparişlere göre fatura ayrıntıları belirtilmemiş';it = 'I dettagli di fatturazione per ordini non sono specificati per la controparte';de = 'Abrechnungsdetails nach Aufträgen sind für die Geschäftspartner nicht angegeben'"));
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableSalesOrder");
	
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableContract
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryCounterpartiesSettlements.AccountsPayable.Counterparty",
		,
		DataCompositionComparisonType.Filled);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryCounterpartiesSettlements.AccountsPayable.DoOperationsByContracts",
		False,
		DataCompositionComparisonType.Equal);
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>",
		NStr("en = 'Billing details by contracts are not specified for the counterparty'; ru = 'Для контрагента не установлены расчеты по договорам';pl = 'Dane rozliczeniowe według kontraktów nie są określone dla kontrahenta';es_ES = 'Los detalles del presupuesto no están especificados para la contraparte';es_CO = 'Los detalles del presupuesto no están especificados para la contraparte';tr = 'Cari hesap için sözleşmelerle fatura detayları belirtilmemiştir';it = 'I dettagli di fatturazione per contratti non sono specificati per la controparte';de = 'Abrechnungsdetails nach Verträgen sind für die Geschäftspartner nicht angegeben'"));
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableContract");
	
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// OpeningBalanceEntryCounterpartiesSettlementsAccountsPayablePurchaseOrder
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryCounterpartiesSettlements.AccountsPayable.Counterparty",
		,
		DataCompositionComparisonType.Filled);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryCounterpartiesSettlements.AccountsPayable.DoOperationsByOrders",
		False,
		DataCompositionComparisonType.Equal);
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>",
		NStr("en = 'Billing details by orders are not specified for the counterparty'; ru = 'Для контрагента не установлены расчеты по заказам';pl = 'Dane rozliczeniowe według zamówień nie są określone dla kontrahenta';es_ES = 'Los detalles del presupuesto por órdenes no están especificados para la contraparte';es_CO = 'Los detalles del presupuesto por órdenes no están especificados para la contraparte';tr = 'Cari hesap için siparişlere göre fatura ayrıntıları belirtilmemiş';it = 'I dettagli di fatturazione per ordini non sono specificati per la controparte';de = 'Abrechnungsdetails nach Aufträgen sind für die Geschäftspartner nicht angegeben'"));
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"OpeningBalanceEntryCounterpartiesSettlementsAccountsPayablePurchaseOrder");
	
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// AccountsPayableDocument Type, Number, Date
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryCounterpartiesSettlements.AccountsPayable.Document",
		Undefined,
		DataCompositionComparisonType.Filled);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableDocumentType,
		|OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableDocumentNumber,
		|OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableDocumentDate");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// AccountsReceivableDocument Type, Number, Date
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"OpeningBalanceEntryCounterpartiesSettlements.AccountsReceivable.Document",
		Undefined,
		DataCompositionComparisonType.Filled);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableDocumentType,
		|OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableDocumentNumber,
		|OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableDocumentDate");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
EndProcedure

&AtServerNoContext
Function GetCustomerSupplierDocumentsNames(Customer = True)
	
	DocNamesArray = New Array;
	
	If Customer Then
		DocNamesArray.Add(Metadata.Documents.CreditNote.Name);
		DocNamesArray.Add(Metadata.Documents.PaymentReceipt.Name);
		DocNamesArray.Add(Metadata.Documents.CashReceipt.Name);
	Else
		DocNamesArray.Add(Metadata.Documents.DebitNote.Name);
		DocNamesArray.Add(Metadata.Documents.PaymentExpense.Name);
		DocNamesArray.Add(Metadata.Documents.CashVoucher.Name);
	EndIf;
	
	Return DocNamesArray;
	
EndFunction

&AtClientAtServerNoContext
Procedure ChangeAdvanceFlag(TabularSectionRow, Customer = True, PreviousDocumentTypeValue = "")
	
	DocNamesArray = GetCustomerSupplierDocumentsNames(Customer);
	
	DocWithAdvanceFlag = (DocNamesArray.Find(TabularSectionRow.DocumentType) <> Undefined);
	
	If DocWithAdvanceFlag
		Or ValueIsFilled(PreviousDocumentTypeValue)
		And DocNamesArray.Find(PreviousDocumentTypeValue) <> Undefined Then
		
		TabularSectionRow.AdvanceFlag = DocWithAdvanceFlag;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureDataForObject(Form, TabName, TabRow)
	
	StructureData = New Structure;
	
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("Object", Form.OpeningBalanceEntryCounterpartiesSettlements);
	
	StructureData.Insert("Company", Form.Company);
	StructureData.Insert("Counterparty", TabRow.Counterparty);
	StructureData.Insert("Contract", TabRow.Contract);
	StructureData.Insert("AmountCur", TabRow.AmountCur);
	
	StructureData.Insert("CounterpartyIncomeAndExpenseItems", True);
	StructureData.Insert("UseDefaultTypeOfAccounting", Form.UseDefaultTypeOfAccounting);
	
	If Form.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("CounterpartyGLAccounts", True);
		
		If TabName = "AccountsPayable" Then
			
			StructureData.Insert("AccountsPayableGLAccount", TabRow.AccountsPayableGLAccount);
			StructureData.Insert("AdvancesPaidGLAccount", TabRow.AdvancesPaidGLAccount);
			
		ElsIf TabName = "AccountsReceivable" Then
			
			StructureData.Insert("AccountsReceivableGLAccount", TabRow.AccountsReceivableGLAccount);
			StructureData.Insert("AdvancesReceivedGLAccount", TabRow.AdvancesReceivedGLAccount);
			
		EndIf;
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function AllowNegativeBalanceBankAccount(BankAccountPettyCash)
	
	Return Common.ObjectAttributeValue(BankAccountPettyCash, "AllowNegativeBalance");
	
EndFunction

&AtServerNoContext
Function BankAccountUseOverdraft(BankAccountPettyCash, BalanceDate)
	
	Return Documents.OpeningBalanceEntry.BankAccountUseOverdraft(BankAccountPettyCash, BalanceDate);
	
EndFunction

#Region LibrariesHandlers

// StandardSubsystems.DataImportFromExternalSources
&AtClient
Procedure DataImportFromExternalSources(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.Inventory";
	
	DocumentAttributes = New Structure;
	DocumentAttributes.Insert("InventoryValuationMethod", InventoryValuationMethod);
	DataLoadSettings.Insert("DocumentAttributes", DocumentAttributes);
	
	DataLoadSettings.Insert("CreateIfNotMatched", True);
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSourcesAccountsPayable(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsPayable";
	DataLoadSettings.Insert("CreateIfNotMatched", True);
	DocumentAttributes = New Structure;
	DocumentAttributes.Insert("Company", Company);
	DocumentAttributes.Insert("Date", BalanceDate);
	DataLoadSettings.Insert("DocumentAttributes", DocumentAttributes);
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSourcesAccountsReceivable(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable";
	DataLoadSettings.Insert("CreateIfNotMatched", True);
	DocumentAttributes = New Structure;
	DocumentAttributes.Insert("Company", Company);
	DocumentAttributes.Insert("Date", BalanceDate);
	DataLoadSettings.Insert("DocumentAttributes", DocumentAttributes);
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSourcesBankAccounts(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.CashAssets";
	DataLoadSettings.Insert("AccountType", "BankAccount");
	DataLoadSettings.Insert("CreateIfNotMatched", True);
	DocumentAttributes = New Structure;
	DocumentAttributes.Insert("Company", Company);
	DocumentAttributes.Insert("Date", BalanceDate);
	DataLoadSettings.Insert("DocumentAttributes", DocumentAttributes);
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSourcesCashAccounts(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.CashAssets";
	DataLoadSettings.Insert("AccountType", "CashAccount");
	DataLoadSettings.Insert("CreateIfNotMatched", True);
	DocumentAttributes = New Structure;
	DocumentAttributes.Insert("Company", Company);
	DocumentAttributes.Insert("Date", BalanceDate);
	DataLoadSettings.Insert("DocumentAttributes", DocumentAttributes);
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult, AdditionalParameters);
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult, AdditionalParameters)
	
	FillingObjectFullName = AdditionalParameters.FillingObjectFullName;
	
	If FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.Inventory" Then
		If Not ValueIsFilled(OpeningBalanceEntryProducts.Company) Then
			OpeningBalanceEntryProducts.Company = Company;
			OpeningBalanceEntryProducts.Date = BalanceDate;
		EndIf;
		DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(
			ImportResult,
			OpeningBalanceEntryProducts,
			ThisObject);
	ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsPayable" Then
		If Not ValueIsFilled(OpeningBalanceEntryCounterpartiesSettlements.Company) Then
			OpeningBalanceEntryCounterpartiesSettlements.Company = Company;
			OpeningBalanceEntryCounterpartiesSettlements.Date = BalanceDate;
		EndIf;
		DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(
			ImportResult,
			OpeningBalanceEntryCounterpartiesSettlements,
			ThisObject);
		For Each TabularSectionRow In OpeningBalanceEntryCounterpartiesSettlements.AccountsPayable Do
			StructureData = GetStructureDataForObject(ThisObject, "AccountsPayable", TabularSectionRow);
			If UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
			EndIf;
			FillPropertyValues(TabularSectionRow, StructureData);
			ChangeAdvanceFlag(TabularSectionRow, False);
		EndDo;
	ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable" Then
		If Not ValueIsFilled(OpeningBalanceEntryCounterpartiesSettlements.Company) Then
			OpeningBalanceEntryCounterpartiesSettlements.Company = Company;
			OpeningBalanceEntryCounterpartiesSettlements.Date = BalanceDate;
		EndIf;
		DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(
			ImportResult,
			OpeningBalanceEntryCounterpartiesSettlements,
			ThisObject);
		For Each TabularSectionRow In OpeningBalanceEntryCounterpartiesSettlements.AccountsReceivable Do
			StructureData = GetStructureDataForObject(ThisObject, "AccountsReceivable", TabularSectionRow);
			If UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
			EndIf;
			FillPropertyValues(TabularSectionRow, StructureData);
			ChangeAdvanceFlag(TabularSectionRow, True);
		EndDo;
	ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.CashAssets" Then
		If Not ValueIsFilled(OpeningBalanceEntryBankAndPettyCash.Company) Then
			OpeningBalanceEntryBankAndPettyCash.Company = Company;
			OpeningBalanceEntryBankAndPettyCash.Date = BalanceDate;
		EndIf;
		OpeningBalanceEntryBankAndPettyCash.CashAssets.Clear();
		For Each CurRow In CashAssetsBank Do
			FillPropertyValues(OpeningBalanceEntryBankAndPettyCash.CashAssets.Add(), CurRow);
		EndDo;
		For Each CurRow In CashAssetsCash Do
			FillPropertyValues(OpeningBalanceEntryBankAndPettyCash.CashAssets.Add(), CurRow);
		EndDo;
		DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(
			ImportResult,
			OpeningBalanceEntryBankAndPettyCash,
			ThisObject);
		FillCashAssetsTables();
	EndIf;
	
EndProcedure
// End StandardSubsystems.DataImportFromExternalSource

#EndRegion

#EndRegion