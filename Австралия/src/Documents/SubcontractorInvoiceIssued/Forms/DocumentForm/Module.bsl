
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	If Not ValueIsFilled(Object.Ref)
		And ValueIsFilled(Object.Counterparty)
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = DriveServer.GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
		EndIf;
		
		If ValueIsFilled(Object.Contract) Then
			
			ContractAttributes = Common.ObjectAttributesValues(Object.Contract, "SettlementsCurrency");
			
			If Not ValueIsFilled(Object.DocumentCurrency) Then
				
				Object.DocumentCurrency = ContractAttributes.SettlementsCurrency;
				
				CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date,
					Object.DocumentCurrency,
					Object.Company);
				
				Object.ExchangeRate = ?(CurrencyRateRepetition.ExchangeRate = 0, 1, CurrencyRateRepetition.ExchangeRate);
				Object.Multiplicity = ?(CurrencyRateRepetition.Multiplicity = 0, 1, CurrencyRateRepetition.Multiplicity);
				
			EndIf;
			
			If Object.PaymentCalendar.Count() = 0 Then
				FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	Company = DriveServer.GetCompany(Object.Company);
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	SettlementsCurrency = Object.Contract.SettlementsCurrency;
	ExchangeRateMethod = DriveServer.GetExchangeMethod(Object.Company);
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	SetAccountingPolicyValues();
	
	If Not ValueIsFilled(Object.Ref)
		And Not ValueIsFilled(Parameters.Basis)
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		
		FillVATRateByCompanyVATTaxation();
		SetAutomaticVATCalculation();
		
	EndIf;
	
	SetTaxItemsVisible();
	
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	ProcessingCompanyVATNumbers();
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillProducts", True);
	
	FillAddedColumns(ParametersStructure);
	
	Items.GLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.ProductsGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	WorkWithVAT.SetTextAboutTaxInvoiceIssued(ThisObject);
	
	SetPrepaymentColumnsProperties();
	
	SetContractVisible();
	
	SetTaxInvoiceTextVisible();
	
	Items.TaxInvoiceText.Enabled = WorkWithVAT.IsTaxInvoiceAccessRightEdit();
	
	SetSwitchTypeListOfPaymentCalendar();
	
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance);
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance, "Products");
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.SubcontractorInvoiceReceived.TabularSections.Inventory,
		DataLoadSettings,
		ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManager.OnCreateAtServer(ThisObject, New Structure("ItemForPlacementName", "GroupAdditionalAttributes"));
	// End StandardSubsystems.Properties
	
	UseDataImportAccessRight = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	Items.InventoryLoadFromFile.Visible = UseDataImportAccessRight;
	
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
	
	SetSwitchTypeListOfPaymentCalendar();
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillProducts", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(MessageText,
			Object.Ref,
			Object.Company,
			Object.Counterparty,
			Object.Contract,
			CounterpartyAttributes.DoOperationsByContracts,
			Cancel);
		
		If MessageText <> "" Then
			If Cancel Then
				MessageText = NStr("en = 'Document is not posted.'; ru = 'Документ не проведен.';pl = 'Dokument niezaksięgowany.';es_ES = 'El documento no se ha publicado.';es_CO = 'El documento no se ha publicado.';tr = 'Belge kaydedilmedi.';it = 'Il documento non è pubblicato.';de = 'Dokument ist nicht gebucht.'") + " " + MessageText;
				CommonClientServer.MessageToUser(MessageText, , "Object.Contract");
			Else
				CommonClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
		
		If DriveReUse.GetAdvanceOffsettingSettingValue() = Enums.YesNo.Yes And CurrentObject.Prepayment.Count() = 0 Then
			FillPrepayment(CurrentObject);
		ElsIf PrepaymentWasChanged Then
			WorkWithVAT.FillPrepaymentVATFromVATInput(CurrentObject);
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
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
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	PrepaymentWasChanged = False;
	
	SetVisibleEnablePaymentTermItems();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	If EventName = "AfterRecordingOfCounterparty" And ValueIsFilled(Parameter) And Object.Counterparty = Parameter Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Parameter);
		
		SetContractVisible();
		
	ElsIf EventName = "RefreshTaxInvoiceText"
		And TypeOf(Parameter) = Type("Structure") 
		And Not Parameter.BasisDocuments.Find(Object.Ref) = Undefined Then
		
		TaxInvoiceText = Parameter.Presentation;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("NotificationAboutChangingDebt");
	Notify("NotificationSubcontractingServicesDocumentsChange");
	Notify("RefreshAccountingTransaction");
	Notify("Write_SubcontractorInvoiceReceived");
	
	PrepaymentWasChanged = False;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillProducts", True);
	
	FillAddedColumns(ParametersStructure);
	
	WorkWithVAT.SetTextAboutTaxInvoiceIssued(ThisForm);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.TaxInvoiceIssued.Form.DocumentForm" Then
		TaxInvoiceText = SelectedValue;
	ElsIf GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf ChoiceSource.FormName = "Catalog.BillsOfMaterials.Form.ChoiceForm" Then
		Modified = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	Object.Number = "";
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	StructureData = GetCompanyDataOnChange();
	Company = StructureData.Company;
	ExchangeRateMethod = StructureData.ExchangeRateMethod;
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	If Object.SetPaymentTerms And ValueIsFilled(Object.PaymentMethod) Then
		PaymentTermsServerCall.FillPaymentTypeAttributes(
			Object.Company, Object.CashAssetType, Object.BankAccount, Object.PettyCash);
	EndIf;
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Counterparty);
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.Counterparty, Object.Company);
		Object.Contract = StructureData.Contract;
		
		ProcessContractChange(StructureData);
		
		GenerateLabelPricesAndCurrency(ThisObject);
		SetVisibleEnablePaymentTermItems();
		
	Else
		
		Object.Contract = Contract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	If CounterpartyAttributes.DoOperationsByContracts Then
		
		StandardProcessing = False;
		
		FormParameters = GetChoiceFormOfContractParameters(Object.Ref,
			Object.Company,
			Object.Counterparty,
			Object.Contract);
		
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillProducts", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ProcessChangesOnButtonPricesAndCurrencies();
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure GLAccountsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	GLAccountsInDocumentsClient.OpenCounterpartyGLAccountsForm(ThisObject, Object, "");
	
EndProcedure

&AtClient
Procedure SetPaymentTermsOnChange(Item)
	
	If Object.SetPaymentTerms Then
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar, True);
		SetVisibleEnablePaymentTermItems();
		
	Else
		
		Notify = New NotifyDescription("ClearPaymentCalendarContinue", ThisObject);
		
		QueryText = NStr("en = 'The payment terms will be cleared. Do you want to continue?'; ru = 'Условия оплаты будут очищены. Продолжить?';pl = 'Warunki płatności zostaną wyczyszczone. Czy chcesz kontynuować?';es_ES = 'Los términos de pago se eliminarán. ¿Quiere continuar?';es_CO = 'Los términos de pago se eliminarán. ¿Quiere continuar?';tr = 'Ödeme şartları silinecek. Devam etmek istiyor musunuz?';it = 'I termini di pagamento saranno cancellati. Continuare?';de = 'Die Zahlungsbedingungen werden ausgeglichen. Möchten Sie fortsetzen?'");
		ShowQueryBox(Notify, QueryText,  QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearPaymentCalendarContinue(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Object.PaymentCalendar.Clear();
		SetEnableGroupPaymentCalendarDetails();
	ElsIf Result = DialogReturnCode.No Then
		Object.SetPaymentTerms = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure FieldSwitchTypeListOfPaymentCalendarOnChange(Item)
	
	LineCount = Object.PaymentCalendar.Count();
	
	If Not SwitchTypeListOfPaymentCalendar And LineCount > 1 Then
		
		NotifyDescription = New NotifyDescription(
			"SetEditInListEndOption",
			ThisObject,
			New Structure("LineCount", LineCount));
		
		QueryText = NStr("en = 'All lines except for the first one will be deleted. Do you want to continue?'; ru = 'Все строки кроме первой будут удалены. Продолжить?';pl = 'Wszystkie wiersze, oprócz pierwszego, zostaną usunięte. Czy chcesz kontynuować?';es_ES = 'Todas las líneas excepto la primera serán borradas. ¿Quiere continuar?';es_CO = 'Todas las líneas excepto la primera serán borradas. ¿Quiere continuar?';tr = 'İlki haricinde tüm satırlar silinecek. Devam etmek istiyor musunuz?';it = 'Tutte le righe tranne la prima saranno eliminate. Continuare?';de = 'Alle Zeilen außer der ersten werden gelöscht. Möchten Sie fortsetzen?'");
		
		ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo);
		
		Return;
		
	EndIf;
	
	SetVisiblePaymentCalendar();
	
EndProcedure

&AtClient
Procedure PaymentMethodOnChange(Item)
	
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	
	SetVisiblePaymentMethod();
	
EndProcedure

&AtClient
Procedure TaxInvoiceTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	WorkWithVATClient.OpenTaxInvoice(ThisObject);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure PagesOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage = Items.GroupInventory Then
		SetInventoryEnabled();
	EndIf;
	
EndProcedure

#Region FormTableProductsItemsEventHandlers

&AtClient
Procedure ProductsOnChange(Item)
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

&AtClient
Procedure ProductsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ProductsGLAccounts" Then
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Products");
	ElsIf Field.Name = "ProductsIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Products");
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsOnActivateCell(Item)
	
	CurrentData = Items.Products.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Products.CurrentItem;
		If TableCurrentColumn.Name = "ProductsGLAccounts" And Not CurrentData.GLAccountsFilled Then
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, Items.Products.CurrentRow, "Products");
		ElsIf TableCurrentColumn.Name = "ProductsIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.Products.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Products");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If Clone Then
		RecalculateSubtotal()
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsOnStartEdit(Item, NewRow, Clone)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	
EndProcedure

&AtClient
Procedure ProductsOnEditEnd(Item, NewRow, CancelEdit)
	
	ThisIsNewRow = False;
	
EndProcedure

&AtClient
Procedure ProductsProductsOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Counterparty", Object.Counterparty);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("ProcessingDate", Object.Date);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	StructureData.Insert("RevenueItem", TabularSectionRow.RevenueItem);
	StructureData.Insert("CostOfSalesItem", TabularSectionRow.CostOfSalesItem);
	StructureData.Insert("IncomeAndExpenseItems",	TabularSectionRow.IncomeAndExpenseItems);
	StructureData.Insert("IncomeAndExpenseItemsFilled", TabularSectionRow.IncomeAndExpenseItemsFilled);
	
	AddTabRowDataToStructure(ThisObject, "Products", StructureData);
	StructureData = GetDataProductsOnChange(StructureData, Object.Date);
	
	FillPropertyValues(TabularSectionRow, StructureData);
	TabularSectionRow.Quantity = 1;
	
	ProductsRowCalculateAmount(TabularSectionRow);
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure ProductsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

&AtClient
Procedure ProductsCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	If DriveClient.UseMatrixForm(TabularSectionRow.Products) Then
		
		StandardProcessing = False;
		
		SelectionParameters = DriveClient.GetMatrixParameters(ThisObject, "Products", False);
		NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseVariantsSelection", ThisObject);
		
		OpenForm("Catalog.ProductsCharacteristics.Form.MatrixChoiceForm",
			SelectionParameters,
			ThisObject,
			True,,,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsQuantityOnChange(Item)
	
	ProductsRowCalculateAmount();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure ProductsMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Products.CurrentData;
	
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
	
	TabularSectionRow.MeasurementUnit = ValueSelected;
	
EndProcedure

&AtClient
Procedure ProductsPriceOnChange(Item)
	
	ProductsRowCalculateAmount();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure ProductsAmountOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	CalculateVATAmount(TabularSectionRow);
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure ProductsVATRateOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	CalculateVATAmount(TabularSectionRow);
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure ProductsVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure ProductsGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, Items.Products.CurrentRow, "Products");
	
EndProcedure

&AtClient
Procedure ProductsIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Products", StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormTableInventoryItemsEventHandlers

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	ThisIsNewRow = False;
	
EndProcedure

&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData);
	TabularSectionRow.Quantity = 1;
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If DriveClient.UseMatrixForm(TabularSectionRow.Products) Then
		
		StandardProcessing = False;
		
		SelectionParameters = DriveClient.GetMatrixParameters(ThisObject, "Inventory", False);
		NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseVariantsSelection", ThisObject);
		
		OpenForm("Catalog.ProductsCharacteristics.Form.MatrixChoiceForm",
			SelectionParameters,
			ThisObject,
			True,,,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTablePaymentCalendarItemsEventHandlers

&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	CurrentRow.PaymentAmount = Round(Object.Products.Total("Amount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(Object.Products.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure PaymentCalendarPaymentAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	AmountTotal = Object.Products.Total("Amount");
	
	CurrentRow.PaymentPercentage = ?(AmountTotal = 0, 0, Round(CurrentRow.PaymentAmount / AmountTotal * 100, 2, 1));
	CurrentRow.PaymentVATAmount = Round(Object.Products.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	VATAmountTotal = Object.Products.Total("VATAmount");
	PaymentCalendarVATAmountTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	
	If PaymentCalendarVATAmountTotal > VATAmountTotal Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarVATAmountTotal - VATAmountTotal);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Copy)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	If CurrentRow.PaymentPercentage = 0 Then
		CurrentRow.PaymentPercentage = 100 - Object.PaymentCalendar.Total("PaymentPercentage");
		CurrentRow.PaymentAmount = Object.Products.Total("Amount") - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = Object.Products.Total("VATAmount") - Object.PaymentCalendar.Total("PaymentVATAmount");
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarBeforeDelete(Item, Cancel)
	
	If Object.PaymentCalendar.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTablePrepaymentItemsEventHandlers

&AtClient
Procedure PrepaymentOnChange(Item)
	PrepaymentWasChanged = True;
EndProcedure

&AtClient
Procedure PrepaymentSettlementsAmountOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	CalculatePrepaymentPaymentAmount(TabularSectionRow);
	
	TabularSectionRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		ExchangeRateMethod,
		Object.ContractCurrencyExchangeRate,
		Object.ExchangeRate,
		Object.ContractCurrencyMultiplicity,
		Object.Multiplicity,
		PricesPrecision);
	
EndProcedure

&AtClient
Procedure PrepaymentPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	If ExchangeRateMethod = PredefinedValue("Enum.ExchangeRateMethods.Divisor") Then
		If TabularSectionRow.PaymentAmount <> 0 Then
			TabularSectionRow.ExchangeRate = TabularSectionRow.SettlementsAmount
				* TabularSectionRow.Multiplicity
				/ TabularSectionRow.PaymentAmount;
		EndIf;
	Else
		If TabularSectionRow.SettlementsAmount <> 0 Then
			TabularSectionRow.ExchangeRate = TabularSectionRow.PaymentAmount
				/ TabularSectionRow.SettlementsAmount
				* TabularSectionRow.Multiplicity;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure PrepaymentDocumentOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.Document) Then
		
		StructureData = GetDataDocumentOnChange(TabularSectionRow.Document);
		
		TabularSectionRow.SettlementsAmount = StructureData.SettlementsAmount;
		TabularSectionRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.SettlementsAmount,
			ExchangeRateMethod,
			Object.ContractCurrencyExchangeRate,
			Object.ExchangeRate,
			Object.ContractCurrencyMultiplicity,
			Object.Multiplicity,
			PricesPrecision);
		
		ParametersStructure = GetAdvanceExchangeRateParameters(TabularSectionRow.Document, TabularSectionRow.Order);
		
		TabularSectionRow.ExchangeRate = GetCalculatedAdvanceExchangeRate(ParametersStructure);
		
		CalculatePrepaymentPaymentAmount(TabularSectionRow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PrepaymentOrderOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.Document) And ValueIsFilled(TabularSectionRow.Order) Then
		
		ParametersStructure = GetAdvanceExchangeRateParameters(TabularSectionRow.Document, TabularSectionRow.Order);
		
		TabularSectionRow.ExchangeRate = GetCalculatedAdvanceExchangeRate(ParametersStructure);
		
		CalculatePrepaymentPaymentAmount(TabularSectionRow);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetDataDocumentOnChange(Document)
	
	StructureData = New Structure();
	
	DocMetadata = Document.Metadata();
	
	If DocMetadata.TabularSections.Find("PaymentDetails") <> Undefined Then
		StructureData.Insert("SettlementsAmount", Document.PaymentDetails.Total("SettlementsAmount"));
	ElsIf DocMetadata.Attributes.Find("DocumentAmount") <> Undefined Then
		StructureData.Insert("SettlementsAmount", Document.DocumentAmount);
	Else
		StructureData.Insert("SettlementsAmount", 0);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure PrepaymentExchangeRateOnChange(Item)
	
	CalculatePrepaymentPaymentAmount();
	
EndProcedure

&AtClient
Procedure PrepaymentMultiplicityOnChange(Item)
	
	CalculatePrepaymentPaymentAmount();
	
EndProcedure

#EndRegion

#EndRegion 

#Region FormCommandsEventHandlers

&AtClient
Procedure InventoryPick(Command)
	
	SelectionParameters = DriveClient.GetSelectionParameters(ThisObject,
		"Inventory",
		NStr("en = 'Subcontractor invoice received'; ru = 'Полученный инвойс переработчика';pl = 'Otrzymana faktura podwykonawcy';es_ES = 'Factura del Subcontratista recibida';es_CO = 'Factura del Subcontratista recibida';tr = 'Alınan alt yüklenici faturası';it = 'Fattura subfornitore ricevuta';de = 'Subunternehmerrechnung erhalten'"),
		False,
		False);
	
	SelectionParameters.Insert("Company", Company);
	SelectionParameters.Insert("StructuralUnit", Object.StructuralUnit);
	
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
		SelectionParameters,
		ThisObject,
		True,,,
		New NotifyDescription("OnCloseSelection", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ProductsPick(Command)
	
	SelectionParameters = DriveClient.GetSelectionParameters(ThisObject,
		"Products",
		NStr("en = 'Subcontractor invoice received'; ru = 'Полученный инвойс переработчика';pl = 'Otrzymana faktura podwykonawcy';es_ES = 'Factura del Subcontratista recibida';es_CO = 'Factura del Subcontratista recibida';tr = 'Alınan alt yüklenici faturası';it = 'Fattura subfornitore ricevuta';de = 'Subunternehmerrechnung erhalten'"),
		False,
		False,
		False);
	
	SelectionParameters.Insert("Company", Company);
	
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
		SelectionParameters,
		ThisObject,
		True,,,
		New NotifyDescription("OnCloseSelection", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		MessagesToUserClient.ShowMessageSelectBaseDocument();
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'Do you want to repopulate the data for the Subcontractor invoice received?'; ru = 'Данные в полученном инвойсе переработчика будут перезаполнены. Продолжить?';pl = 'Czy chcesz ponownie wypełnić dane dla Otrzymanej faktury podwykonawcy?';es_ES = '¿Quiere rellenar los datos de la Factura del subcontratista recibida?';es_CO = '¿Quiere rellenar los datos de la Factura del subcontratista recibida?';tr = 'Alınan alt yüklenici faturası için verileri yeniden doldurmak istiyor musunuz?';it = 'Ricompilare i dati per la fattura di subfornitura ricevuta?';de = 'Möchten Sie die Daten für die Subunternehmerrechnung erhalten neu füllen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure LoadFromFileInventory(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.SubcontractorInvoiceReceived.TabularSection.Inventory";
	
	DataLoadSettings.Insert("TabularSectionFullName", "SubcontractorInvoiceReceived.Inventory");
	DataLoadSettings.Insert("Title", NStr("en = 'Import inventory from file'; ru = 'Загрузить данные запасов из файла';pl = 'Import zapasów z pliku';es_ES = 'Importar el inventario del archivo';es_CO = 'Importar el inventario del archivo';tr = 'Stoku dosyadan içe aktar';it = 'Importare inventario da file';de = 'Bestand aus Datei importieren'"));
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffset(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en = 'Please specify the customer.'; ru = 'Укажите покупателя.';pl = 'Określ nabywcę.';es_ES = 'Por favor, especifique el cliente.';es_CO = 'Por favor, especifique el cliente.';tr = 'Lütfen müşteri belirtin.';it = 'Si prega di specificare il cliente.';de = 'Bitte geben Sie den Kunden an.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Contract) Then
		ShowMessageBox(, NStr("en = 'Please specify the contract.'; ru = 'Укажите договор.';pl = 'Określ kontrakt.';es_ES = 'Por favor, especifique el contrato.';es_CO = 'Por favor, especifique el contrato.';tr = 'Lütfen, sözleşmeyi belirtin.';it = 'Si prega di specificare il contratto.';de = 'Bitte geben Sie den Vertrag an.'"));
		Return;
	EndIf;
	
	AddressPrepaymentInStorage = PlacePrepaymentToStorage();
	
	SelectionParameters = New Structure;
	SelectionParameters.Insert("AddressPrepaymentInStorage", AddressPrepaymentInStorage);
	SelectionParameters.Insert("Pick", True);
	SelectionParameters.Insert("IsOrder", True);
	SelectionParameters.Insert("OrderInHeader", True);
	SelectionParameters.Insert("Company", Company);
	SelectionParameters.Insert("Order", ?(CounterpartyAttributes.DoOperationsByOrders, Object.BasisDocument, Undefined));
	SelectionParameters.Insert("Date", Object.Date);
	SelectionParameters.Insert("Ref", Object.Ref);
	SelectionParameters.Insert("Counterparty", Object.Counterparty);
	SelectionParameters.Insert("Contract", Object.Contract);
	SelectionParameters.Insert("ContractCurrencyExchangeRate", Object.ContractCurrencyExchangeRate);
	SelectionParameters.Insert("ContractCurrencyMultiplicity", Object.ContractCurrencyMultiplicity);
	SelectionParameters.Insert("DocumentCurrency", Object.DocumentCurrency);
	SelectionParameters.Insert("ExchangeRate", Object.ExchangeRate);
	SelectionParameters.Insert("Multiplicity", Object.Multiplicity);
	SelectionParameters.Insert("DocumentAmount", Object.Products.Total("Total"));
	
	ReturnCode = Undefined;
	OpenForm("CommonForm.SelectAdvancesReceivedFromTheCustomer",
		SelectionParameters,,,,,
		New NotifyDescription("EditPrepaymentOffsetEnd",
			ThisObject,
			New Structure("AddressPrepaymentInStorage, SelectionParameters", AddressPrepaymentInStorage, SelectionParameters)));
	
EndProcedure

&AtClient
Procedure FillBySpecification(Command)
	
	If Not CheckBOMFilling() Then
		Return;
	EndIf;
	
	If Object.Inventory.Count() > 0 Then
		ShowQueryBox(New NotifyDescription("FillBySpecificationEnd", ThisObject),
			NStr("en = 'Components will be repopulated. Do you want to continue?'; ru = 'Компоненты будут перезаполнены. Продолжить?';pl = 'Komponenty zostaną ponownie wypełnione. Czy chcesz kontynuować?';es_ES = 'Los componentes serán rellenados. ¿Quiere continuar?';es_CO = 'Los componentes serán rellenados. ¿Quiere continuar?';tr = 'Malzemeler yeniden doldurulacak. Devam etmek istiyor musunuz?';it = 'Le Componenti saranno ricompilate. Continuare?';de = 'Komponenten werden neu füllt. Möchten Sie fortfahren?'"),
			QuestionDialogMode.YesNo);
	Else
		FillBySpecificationFragment();
	EndIf;
	
EndProcedure

&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	NotifyDescription = New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode));
	ShowInputValue(NotifyDescription, CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserire codice a barre';de = 'Geben Sie den Barcode ein'"));
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		InformationRegisters.Barcodes.ConvertWeightBarcode(CurBarcode);
		
	EndDo;
	
	DataByBarCodes = InformationRegisters.Barcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined And BarcodeData.Count() <> 0 Then
			
			StructureProductsData = New Structure;
			StructureProductsData.Insert("Company", StructureData.Company);
			StructureProductsData.Insert("Counterparty", StructureData.Counterparty);
			StructureProductsData.Insert("VATTaxation", StructureData.VATTaxation);
			StructureProductsData.Insert("ProcessingDate", StructureData.DocumentDate);
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsData.Insert("UseDefaultTypeOfAccounting", StructureData.UseDefaultTypeOfAccounting);
			StructureProductsData.Insert("TabName", StructureData.TabName);
			StructureProductsData.Insert("RevenueItem", Undefined);
			StructureProductsData.Insert("CostOfSalesItem", Undefined);
			
			IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInBarcodeData(
				StructureProductsData, StructureData.Object, "SubcontractorInvoiceIssued");
				
			If StructureData.UseDefaultTypeOfAccounting Then
				
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(StructureProductsData,
					StructureData.Object,
					"SubcontractorInvoiceIssued",
					StructureData.TabName);
					
			EndIf;
			
			If StructureData.TabName = "Products" Then
				StructureProductsData = GetDataProductsOnChange(StructureProductsData, StructureData.DocumentDate);
			Else
				StructureProductsData = GetDataProductsOnChange(StructureProductsData);
			EndIf;
			
			BarcodeData.Insert("StructureProductsData", StructureProductsData);
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit = StructureProductsData.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	If Items.Pages.CurrentPage = Items.GroupProducts Then
		TableName = "Products";
	Else
		TableName = "Inventory";
	EndIf;

	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	StructureData.Insert("Object", Object);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Counterparty", Object.Counterparty);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("DocumentDate", Object.Date);
	StructureData.Insert("TabName", TableName);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined And BarcodeData.Count() = 0 Then
			
			UnknownBarcodes.Add(CurBarcode);
			
		Else
			
			SearchStructure = New Structure;
			SearchStructure.Insert("Products", BarcodeData.Products);
			SearchStructure.Insert("Characteristic", BarcodeData.Characteristic);
			SearchStructure.Insert("MeasurementUnit", BarcodeData.MeasurementUnit);
			
			TSRowsArray = Object[TableName].FindRows(SearchStructure);
			If TSRowsArray.Count() = 0 Then
				
				NewRow = Object[TableName].Add();
				FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
				
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = BarcodeData.MeasurementUnit;
				
			Else
				
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				
			EndIf;
			
			If TableName = "Products" Then
				ProductsRowCalculateAmount(NewRow);
			EndIf;
			
			Items[TableName].CurrentRow = NewRow.GetID();
			
			Modified = True;
		EndIf;
		
	EndDo;
	
	If TableName = "Products" And Modified Then
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
	EndIf;
	
	Return UnknownBarcodes;
	
EndFunction

&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		NotifyDescription = New NotifyDescription("BarcodesAreReceivedEnd", ThisObject, UnknownBarcodes);
		
		OpenForm("InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes),
			ThisObject,,,,
			NotifyDescription);
		
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
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Barcode data is not found: %1; quantity: %2'; ru = 'Данные по штрихкоду не найдены: %1; количество: %2';pl = 'Nie znaleziono danych kodu kreskowego: %1; ilość: %2';es_ES = 'Datos del código de barras no encontrados: %1; cantidad: %2';es_CO = 'Datos del código de barras no encontrados: %1; cantidad: %2';tr = 'Barkod verisi bulunamadı: %1; miktar: %2';it = 'I dati del codice a barre non sono stati trovati: %1; quantità: %2';de = 'Barcode-Daten wurden nicht gefunden: %1; Menge: %2'"),
			CurUndefinedBarcode.Barcode,
			CurUndefinedBarcode.Quantity);
		
		CommonClientServer.MessageToUser(MessageText);
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, DoOperationsByOrders";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	PerInvoiceVATRoundingRule = AccountingPolicy.PerInvoiceVATRoundingRule;
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);
	
EndProcedure

&AtServer
Procedure FillVATRateByCompanyVATTaxation(IsCounterpartyOnChange = False)
	
	If Not WorkWithVAT.VATTaxationTypeIsValid(Object.VATTaxation, RegisteredForVAT, False)
		Or Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT
		Or IsCounterpartyOnChange Then
		
		TaxationBeforeChange = Object.VATTaxation;
		
		Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty,
			DriveServer.VATTaxation(Object.Company, Object.Date),
			False);
		
		If TaxationBeforeChange <> Object.VATTaxation Then
			FillVATRateByVATTaxation();
			SetTaxItemsVisible();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
		
		For Each Row In Object.Products Do
			
			If ValueIsFilled(Row.Products.VATRate) Then
				Row.VATRate = Row.Products.VATRate;
			Else
				Row.VATRate = DefaultVATRate;
			EndIf;
			
			VATRate = DriveReUse.GetVATRateValue(Row.VATRate);
			
			Row.VATAmount = ?(Object.AmountIncludesVAT,
				Row.Amount - Row.Amount * 100 / (VATRate + 100),
				Row.Amount * VATRate / 100);
			Row.Total = Row.Amount + ?(Object.AmountIncludesVAT, 0, Row.VATAmount);
			
		EndDo;
		
	Else
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
		
		For Each Row In Object.Products Do
			Row.VATRate = DefaultVATRate;
			Row.VATAmount = 0;
			Row.Total = Row.Amount;
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetTaxItemsVisible()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		Items.ProductsVATRate.Visible = True;
		Items.ProductsVATAmount.Visible = True;
		Items.ProductsTotal.Visible = True;
		Items.DocumentTax.Visible = True;
		Items.PaymentCalendarPaymentVATAmount.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
	Else
		Items.ProductsVATRate.Visible = False;
		Items.ProductsVATAmount.Visible = False;
		Items.ProductsTotal.Visible = False;
		Items.DocumentTax.Visible = False;
		Items.PaymentCalendarPaymentVATAmount.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateLabelPricesAndCurrency(Form)
	
	Object = Form.Object;
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",		Form.SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate",				Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",			Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	Form.ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation",				Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",			Form.RegisteredForVAT);
	
	Form.PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company);
	
EndFunction

&AtClient
Procedure ProcessContractChange(ContractData = Undefined)
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		If Object.Prepayment.Count() > 0 Then
			
			NotifyDescription = New NotifyDescription("ProcessContractChangeEnd",
				ThisObject,
				New Structure("ContractBeforeChange, ContractData", ContractBeforeChange, ContractData));
			
			ShowQueryBox(NotifyDescription,
				NStr("en = 'The advance set-off will be canceled. Do you want to continue?'; ru = 'Зачет аванса будет отменен. Продолжить?';pl = 'Zaliczkowe potrącenia zostaną anulowane. Czy chcesz kontynuować?';es_ES = 'Se cancelará la compensación del anticipo. ¿Quiere continuar?';es_CO = 'Se cancelará la compensación del anticipo. ¿Quiere continuar?';tr = 'Avans mahsubu iptal edilecek. Devam etmek istiyor musunuz?';it = 'La compensazione anticipata sarà annullata. Continuare?';de = 'Die Aufrechnung der Vorauszahlung wird abgebrochen. Möchten Sie fortfahren?'"),
				QuestionDialogMode.YesNo);
			
			Return;
			
		EndIf;
		
		ProcessContractChangeFragment(ContractBeforeChange, ContractData);
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
		SetVisibleEnablePaymentTermItems();
		
	Else
		
		Object.Contract = Contract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessContractChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Object.Prepayment.Clear();
	Else
		Object.Contract = AdditionalParameters.ContractBeforeChange;
		Contract = AdditionalParameters.ContractBeforeChange;
		Return;
	EndIf;
	
	ProcessContractChangeFragment(AdditionalParameters.ContractBeforeChange, AdditionalParameters.ContractData);
	
EndProcedure

&AtClient
Procedure ProcessContractChangeFragment(ContractBeforeChange, ContractData = Undefined)
	
	If ContractData = Undefined Then
		
		ContractData = GetDataContractOnChange(Object.Date, Object.Contract, Object.Company);
		
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillProducts", False);
	
	FillAddedColumns(ParametersStructure);
	
	SettlementsCurrency = ContractData.SettlementsCurrency;
	
	OpenFormPricesAndCurrencies = (ValueIsFilled(Object.Contract)
		And ValueIsFilled(SettlementsCurrency)
		And Object.DocumentCurrency <> ContractData.SettlementsCurrency
		And Object.Products.Count() > 0);
	
	DocumentParameters = New Structure;
	DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
	DocumentParameters.Insert("ContractData", ContractData);
	DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
	
	ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters);
	
	SetPrepaymentColumnsProperties();
	
EndProcedure

&AtServer
Function GetDataContractOnChange(Date, Contract, Company)
	
	StructureData = New Structure("SettlementsCurrency, SettlementsCurrencyRateRepetition, AmountIncludesVAT");
	
	If ValueIsFilled(Contract) Then
		AttributesValues = Common.ObjectAttributesValues(Contract, "SettlementsCurrency, SupplierPriceTypes");
		StructureData.SettlementsCurrency = AttributesValues.SettlementsCurrency;
		If ValueIsFilled(AttributesValues.SupplierPriceTypes) Then
			StructureData.AmountIncludesVAT = Common.ObjectAttributeValue(AttributesValues.SupplierPriceTypes, "PriceIncludesVAT");
		EndIf;
	Else
		StructureData.SettlementsCurrency = Catalogs.Currencies.EmptyRef();
		StructureData.AmountIncludesVAT = Undefined;
	EndIf;
	
	FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Date, StructureData.SettlementsCurrency, Company);
	StructureData.SettlementsCurrencyRateRepetition = CurrencyRateRepetition;
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure SetEditInListEndOption(Response, AdditionalParameters) Export
	
	LineCount = AdditionalParameters.LineCount;
	
	If Response = DialogReturnCode.No Then
		SwitchTypeListOfPaymentCalendar = 1;
		Return;
	EndIf;
	
	While LineCount > 1 Do
		Object.PaymentCalendar.Delete(Object.PaymentCalendar[LineCount - 1]);
		LineCount = LineCount - 1;
	EndDo;
	
	Items.PaymentCalendar.CurrentRow = Object.PaymentCalendar[0].GetID();
	
	SetVisiblePaymentCalendar();
	
EndProcedure

&AtServer
Procedure SetContractVisible()
	
	Items.Contract.Visible = CounterpartyAttributes.DoOperationsByContracts;
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.ProductsPrice);
	
	Return Fields;
	
EndFunction

&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText,
	Document,
	Company,
	Counterparty,
	Contract,
	IsOperationsByContracts,
	Cancel)
	
	If Not DriveReUse.CounterpartyContractsControlNeeded() Or Not IsOperationsByContracts Then
		Return;
	EndIf;
	
	CatalogManager = Catalogs.CounterpartyContracts;
	
	ContractKindsList = CatalogManager.GetContractTypesListForDocument(Document);
	
	If Not CatalogManager.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList)
		And Constants.CheckContractsOnPosting.Get() Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange(Object.Ref,
		Object.Date,
		Object.DocumentCurrency,
		SettlementsCurrency);
	
	If ValueIsFilled(SettlementsCurrency) Then
		RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
	EndIf;
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Function GetDataDateOnChange(DocumentRef, DateNew, DocumentCurrency, SettlementsCurrency)
	
	SetAccountingPolicyValues();
	SetAutomaticVATCalculation();
	
	SetTaxInvoiceTextVisible();
	
	ProcessingCompanyVATNumbers();
	
	FillVATRateByCompanyVATTaxation();
	
	PaymentTermsServer.ShiftPaymentCalendarDates(Object, ThisObject);
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(DateNew, DocumentCurrency, Object.Company);
	
	StructureData = New Structure;
	StructureData.Insert("CurrencyRateRepetition", CurrencyRateRepetition);
	
	If DocumentCurrency <> SettlementsCurrency Then
		
		SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(DateNew, SettlementsCurrency, Object.Company);
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", SettlementsCurrencyRateRepetition);
		
	Else
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", CurrencyRateRepetition);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	CurRateRepetition = StructureData.CurrencyRateRepetition;
	SettlCurRateRepetition = StructureData.SettlementsCurrencyRateRepetition;
	
	NewExchangeRate = ?(CurRateRepetition.Rate = 0, 1, CurRateRepetition.Rate);
	NewRatio = ?(CurRateRepetition.Repetition = 0, 1, CurRateRepetition.Repetition);
	
	NewContractCurrencyExchangeRate = ?(SettlCurRateRepetition.Rate = 0, 1, SettlCurRateRepetition.Rate);
	NewContractCurrencyRatio = ?(SettlCurRateRepetition.Repetition = 0, 1, SettlCurRateRepetition.Repetition);
	
	If Object.ExchangeRate <> NewExchangeRate
		Or Object.Multiplicity <> NewRatio
		Or Object.ContractCurrencyExchangeRate <> NewContractCurrencyExchangeRate
		Or Object.ContractCurrencyMultiplicity <> NewContractCurrencyRatio Then
		
		QuestionParameters = New Structure;
		QuestionParameters.Insert("NewExchangeRate",					NewExchangeRate);
		QuestionParameters.Insert("NewRatio",							NewRatio);
		QuestionParameters.Insert("NewContractCurrencyExchangeRate",	NewContractCurrencyExchangeRate);
		QuestionParameters.Insert("NewContractCurrencyRatio",			NewContractCurrencyRatio);
		
		NotifyDescription = New NotifyDescription("RecalculatePaymentCurrencyRateConversionFactorEnd",
			ThisObject, 
			QuestionParameters);
		
		MessageText = MessagesToUserClientServer.GetApplyRatesOnNewDateQuestionText();
		
		ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo);
		
		Return;
		
	EndIf;
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		Object.ContractCurrencyExchangeRate = AdditionalParameters.NewContractCurrencyExchangeRate;
		Object.ContractCurrencyMultiplicity = AdditionalParameters.NewContractCurrencyRatio;
		
		For Each TabularSectionRow In Object.Prepayment Do
			TabularSectionRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				ExchangeRateMethod,
				Object.ContractCurrencyExchangeRate,
				Object.ExchangeRate,
				Object.ContractCurrencyMultiplicity,
				Object.Multiplicity,
				PricesPrecision);
		EndDo;
		
	EndIf;
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
EndProcedure

&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Object.Company));
	StructureData.Insert("ExchangeRateMethod", DriveServer.GetExchangeMethod(Object.Company));
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillProducts", True);
	
	FillAddedColumns(ParametersStructure);
	
	SetAccountingPolicyValues();
	SetAutomaticVATCalculation();
	
	SetTaxInvoiceTextVisible();
	
	ProcessingCompanyVATNumbers(False);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetDataCounterpartyOnChange(Date, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	StructureData = GetDataContractOnChange(Date, ContractByDefault, Company);
	StructureData.Insert("Contract", ContractByDefault);
	
	FillVATRateByCompanyVATTaxation(True);
	FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillProducts", False);
	
	FillAddedColumns(ParametersStructure);
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetChoiceFormOfContractParameters(Document, Company, Counterparty, Contract)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", True);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange = Undefined, RecalculatePrices = False, WarningText = "")
	
	If AttributesBeforeChange = Undefined Then
		AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
			Object.DocumentCurrency,
			Object.ExchangeRate,
			Object.Multiplicity);
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",					Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation",					Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",				Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty",					Object.Counterparty);
	ParametersStructure.Insert("Contract",						Object.Contract);
	ParametersStructure.Insert("ContractCurrencyExchangeRate",	Object.ContractCurrencyExchangeRate);
	ParametersStructure.Insert("ContractCurrencyMultiplicity",	Object.ContractCurrencyMultiplicity);
	ParametersStructure.Insert("Company",						Company);
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("RefillPrices",					False);
	ParametersStructure.Insert("RecalculatePrices",				RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",				False);
	ParametersStructure.Insert("WarningText",					WarningText);
	ParametersStructure.Insert("AutomaticVATCalculation",		Object.AutomaticVATCalculation);
	ParametersStructure.Insert("PerInvoiceVATRoundingRule",		PerInvoiceVATRoundingRule);
	
	NotifyDescription = New NotifyDescription("ProcessChangesOnButtonPricesAndCurrenciesEnd", ThisObject, AttributesBeforeChange);
	
	OpenForm("CommonForm.PricesAndCurrency",
		ParametersStructure,
		ThisObject,,,,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrenciesEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") AND ClosingResult.WereMadeChanges Then
		
		DocCurRecalcStructure = New Structure;
		DocCurRecalcStructure.Insert("DocumentCurrency", ClosingResult.DocumentCurrency);
		DocCurRecalcStructure.Insert("Rate", ClosingResult.ExchangeRate);
		DocCurRecalcStructure.Insert("Repetition", ClosingResult.Multiplicity);
		DocCurRecalcStructure.Insert("PrevDocumentCurrency", AdditionalParameters.DocumentCurrency);
		DocCurRecalcStructure.Insert("InitRate", AdditionalParameters.ExchangeRate);
		DocCurRecalcStructure.Insert("RepetitionBeg", AdditionalParameters.Multiplicity);
		
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.ExchangeRate;
		Object.Multiplicity = ClosingResult.Multiplicity;
		Object.ContractCurrencyExchangeRate = ClosingResult.SettlementsRate;
		Object.ContractCurrencyMultiplicity = ClosingResult.SettlementsMultiplicity;
		Object.VATTaxation = ClosingResult.VATTaxation;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		Object.AutomaticVATCalculation = ClosingResult.AutomaticVATCalculation;
		
		// Recalculate prices by currency.
		If ClosingResult.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Products", PricesPrecision);
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			FillVATRateByVATTaxation();
			SetTaxItemsVisible();
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If ClosingResult.AmountIncludesVAT <> ClosingResult.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Products", PricesPrecision);
		EndIf;
		
		For Each TabularSectionRow In Object.Prepayment Do
			TabularSectionRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				ExchangeRateMethod,
				Object.ContractCurrencyExchangeRate,
				Object.ExchangeRate,
				Object.ContractCurrencyMultiplicity,
				Object.Multiplicity,
				PricesPrecision);
		EndDo;
		
	EndIf;
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	RecalculateSubtotal();
	
	ProcessChangesOnButtonPricesAndCurrenciesEndAtServer();
	
EndProcedure

&AtServer
Procedure ProcessChangesOnButtonPricesAndCurrenciesEndAtServer() 
	
	SetPrepaymentColumnsProperties();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillProducts", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure RecalculateSubtotal()
	
	AmountTotal = Object.Products.Total("Total");
	VATAmountTotal = Object.Products.Total("VATAmount");
	
	Object.DocumentTax = VATAmountTotal;
	Object.DocumentSubtotal = AmountTotal - VATAmountTotal;
	Object.DocumentAmount = AmountTotal;
	
EndProcedure

&AtServer
Procedure SetAutomaticVATCalculation()
	
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
	
EndProcedure

&AtServer
Procedure FillPaymentCalendar(TypeListOfPaymentCalendar, IsEnabledManually = False)
	
	If ValueIsFilled(Object.Order) Then
		PaymentTermsServer.FillPaymentCalendarFromDocument(Object, Object.Order);
	Else
		PaymentTermsServer.FillPaymentCalendarFromContract(Object, IsEnabledManually);
	EndIf;
	
	TypeListOfPaymentCalendar = Number(Object.PaymentCalendar.Count() > 1);
	Modified = True;
	
EndProcedure

&AtClient
Procedure SetVisibleEnablePaymentTermItems()
	
	SetEnableGroupPaymentCalendarDetails();
	SetVisiblePaymentCalendar();
	SetVisiblePaymentMethod();
	
EndProcedure

&AtServer
Procedure SetInventoryEnabled()
	
	// If Specification is filled in any line of Products, user can't edit Inventory
	SpecificationIsFilled = False;
	
	// If Products are not filled, user can't edit Inventory
	ProductsAreFilled = True;
	
	IsInventoryEnabled = True;
	
	For Each ProductsLine In Object.Products Do
		
		If ValueIsFilled(ProductsLine.Specification) Then
			SpecificationIsFilled = True;
			Break;
		EndIf;
		
	EndDo;
	
	If Object.Products.Count() = 0 Then
		
		ProductsAreFilled = False;
		
	EndIf;
	
	If Not ProductsAreFilled
		Or SpecificationIsFilled Then
	
		IsInventoryEnabled = False;
	
	EndIf;
	
	WorkWithForm.SetReadOnlyForTableColumn(Items.InventoryProducts, Not IsInventoryEnabled);
	WorkWithForm.SetReadOnlyForTableColumn(Items.InventoryCharacteristic, Not IsInventoryEnabled);
	Items.InventoryQuantity.ReadOnly = Not IsInventoryEnabled;
	Items.InventoryMeasurementUnit.ReadOnly = Not IsInventoryEnabled;
	
	Items.GroupInventoryCommandBar.Enabled = IsInventoryEnabled;
	Items.Inventory.ChangeRowOrder = IsInventoryEnabled;
	Items.Inventory.ChangeRowSet = IsInventoryEnabled;
	
EndProcedure 

&AtClient
Procedure SetEnableGroupPaymentCalendarDetails()
	
	Items.GroupPaymentCalendarDetails.Enabled = Object.SetPaymentTerms;
	
EndProcedure

&AtClient
Procedure SetVisiblePaymentCalendar()
	
	If SwitchTypeListOfPaymentCalendar Then
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupPaymentCalendarList;
	Else
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupBillingCalendarString;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVisiblePaymentMethod()
	
	If Object.CashAssetType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		Items.BankAccount.Visible = False;
		Items.PettyCash.Visible = True;
	ElsIf Object.CashAssetType = PredefinedValue("Enum.CashAssetTypes.Noncash") Then
		Items.BankAccount.Visible = True;
		Items.PettyCash.Visible = False;
	Else
		Items.BankAccount.Visible = False;
		Items.PettyCash.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting Then
		
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
		
		If ParametersStructure.FillHeader Then
			
			Header = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Header", Object);
			GLAccountsInDocuments.CompleteCounterpartyStructureData(Header, ObjectParameters, "Header");
			StructureArray.Add(Header);
			
		EndIf;
		
	EndIf;
	
	If ParametersStructure.FillProducts Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Products");
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Products");
		StructureArray.Add(StructureData);
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
	If UseDefaultTypeOfAccounting
		And ParametersStructure.FillHeader Then
		GLAccounts = Header.GLAccounts;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetPrepaymentColumnsProperties()
	
	Items.PrepaymentSettlementsAmount.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Clearing amount (%1)'; ru = 'Сумма зачета (%1)';pl = 'Kwota rozliczenia (%1)';es_ES = 'Importe de liquidaciones (%1)';es_CO = 'Importe de liquidaciones (%1)';tr = 'Mahsup edilen tutar (%1)';it = 'Importo compensazione (%1)';de = 'Ausgleichsbetrag (%1)'"),
		SettlementsCurrency);
	
	If Object.DocumentCurrency = SettlementsCurrency Then
		Items.PrepaymentAmountDocCur.Visible = False;
	Else
		Items.PrepaymentAmountDocCur.Visible = True;
		Items.PrepaymentAmountDocCur.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Amount (%1)'; ru = 'Сумма (%1)';pl = 'Wartość (%1)';es_ES = 'Importe (%1)';es_CO = 'Cantidad (%1)';tr = 'Tutar (%1)';it = 'Importo (%1)';de = 'Betrag (%1)'"),
			Object.DocumentCurrency);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function PaymentMethodCashAssetType(PaymentMethod)
	
	Return Common.ObjectAttributeValue(PaymentMethod, "CashAssetType");
	
EndFunction

&AtClient
Procedure ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters)
	
	ContractBeforeChange = DocumentParameters.ContractBeforeChange;
	ContractData = DocumentParameters.ContractData;
	OpenFormPricesAndCurrencies = DocumentParameters.OpenFormPricesAndCurrencies;
	
	If ContractData.AmountIncludesVAT <> Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
		Object.DocumentCurrency,
		Object.ExchangeRate,
		Object.Multiplicity);
	
	If ValueIsFilled(Object.Contract) Then 
		
		CurrencyRateRepetition = ContractData.SettlementsCurrencyRateRepetition;
		
		Object.ExchangeRate = ?(CurrencyRateRepetition.Rate = 0, 1, CurrencyRateRepetition.Rate);
		Object.Multiplicity = ?(CurrencyRateRepetition.Repetition = 0, 1, CurrencyRateRepetition.Repetition);
		
		Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
		Object.ContractCurrencyMultiplicity = Object.Multiplicity;
		
	EndIf;
	
	If ValueIsFilled(SettlementsCurrency) Then
		Object.DocumentCurrency = SettlementsCurrency;
	EndIf;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = MessagesToUserClientServer.GetSettleCurrencyOnChangeWarningText();
		
		ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, True, WarningText);
		
	Else
		
		GenerateLabelPricesAndCurrency(ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			TabularSectionName = "";
			If Items.Pages.CurrentPage = Items.GroupProducts Then
				TabularSectionName = "Products";
			ElsIf Items.Pages.CurrentPage = Items.GroupInventory Then
				TabularSectionName = "Inventory";
			EndIf;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, False);
			
			Modified = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		FillByDocument();
		SetVisibleEnablePaymentTermItems();
		
		GenerateLabelPricesAndCurrency(ThisObject);
		
		RecalculateSubtotal();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByDocument(Attribute = "BasisDocument")
	
	Document = FormAttributeToValue("Object");
	Document.Fill(Object[Attribute]);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillProducts", True);
	
	FillAddedColumns(ParametersStructure);
	
	SetTaxItemsVisible();
	SetContractVisible();
	SetSwitchTypeListOfPaymentCalendar();
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure FillByBillsOfMaterialsAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillTabularSectionBySpecification();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

&AtClient
Procedure FillBySpecificationEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillBySpecificationFragment();
	
EndProcedure

&AtClient
Procedure FillBySpecificationFragment()
	
	FillByBillsOfMaterialsAtServer();
	
	Modified = True;
	
EndProcedure

&AtClient
Function CheckBOMFilling()
	
	Result = True;
	
	MessageTemplate = NStr("en = 'Bill of materials is required on line %1'; ru = 'В строке %1 требуется спецификация';pl = 'Specyfikacja materiałowa jest wymagana w wierszu %1';es_ES = 'Se requiere una lista de materiales en línea%1';es_CO = 'Se requiere una lista de materiales en línea%1';tr = '%1 satırında ürün reçetesi gerekli';it = 'La Distinta base è richiesta nella riga %1';de = 'Stückliste ist in der Zeile %1 erforderlich'");
	
	For Each ProductsRow In Object.Products Do
		
		If Not ValueIsFilled(ProductsRow.Specification) Then
			
			Result = False;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageTemplate,
				ProductsRow.LineNumber);
			
			CommonClientServer.MessageToUser(
				MessageText,
				,
				CommonClientServer.PathToTabularSection("Object.Products", ProductsRow.LineNumber, "Specification"));
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SetSwitchTypeListOfPaymentCalendar()
	
	If Object.PaymentCalendar.Count() > 1 Then
		SwitchTypeListOfPaymentCalendar = 1;
	Else
		SwitchTypeListOfPaymentCalendar = 0;
	EndIf;
	
EndProcedure

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
		
		If TabularSectionName = "Products" Then
			
			IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, TabularSectionName);
			
			If UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OnCloseVariantsSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If ClosingResult.WereMadeChanges And Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			CurrentPagesProducts = (Items.Pages.CurrentPage = Items.PageProducts);
			
			TabularSectionName = "";
			If Items.Pages.CurrentPage = Items.PageProducts Then
				TabularSectionName = "Products";
			ElsIf Items.Pages.CurrentPage = Items.PageInventory Then
				TabularSectionName = "Inventory";
			EndIf;
			
			If Not IsBlankString(TabularSectionName) Then
				
				Filter = New Structure;
				Filter.Insert("Products", ClosingResult.FilterProducts);
				
				RowsToDelete = Object[TabularSectionName].FindRows(Filter);
				For Each RowToDelete In RowsToDelete Do
					Object[TabularSectionName].Delete(RowToDelete);
				EndDo;
				
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillPrepayment(CurrentObject)
	
	CurrentObject.FillPrepayment();
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		GetPrepaymentFromStorage(AdditionalParameters.AddressPrepaymentInStorage);
		Modified = True;
		PrepaymentWasChanged = True;
	EndIf;
	
EndProcedure

&AtServer
Function PlacePrepaymentToStorage()
	
	PrepaymentTable = Object.Prepayment.Unload(,
		"Document,
		|Order,
		|SettlementsAmount,
		|AmountDocCur,
		|ExchangeRate,
		|Multiplicity,
		|PaymentAmount");
	
	Return PutToTempStorage(PrepaymentTable, UUID);
	
EndFunction

&AtServer
Procedure GetPrepaymentFromStorage(AddressPrepaymentInStorage)
	
	Object.Prepayment.Load(GetFromTempStorage(AddressPrepaymentInStorage));
	
EndProcedure

&AtServer
Procedure SetTaxInvoiceTextVisible()
	
	Items.TaxInvoiceText.Visible = WorkWithVAT.GetUseTaxInvoiceForPostingVAT(Object.Date, Object.Company)
	
EndProcedure

&AtClientAtServerNoContext
Procedure AddTabRowDataToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("TabName",				TabName);
	StructureData.Insert("Object",				Form.Object);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
		StructureData.Insert("ProductGLAccounts",	True);
		
		If StructureData.TabName = "Products" Then
			StructureData.Insert("CostOfSalesGLAccount", TabRow.CostOfSalesGLAccount);
			StructureData.Insert("ConsumptionGLAccount", TabRow.ConsumptionGLAccount);
			StructureData.Insert("RevenueGLAccount", TabRow.RevenueGLAccount);
			StructureData.Insert("VATOutputGLAccount", TabRow.VATOutputGLAccount);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetDataProductsOnChange(StructureData, ObjectDate = Undefined)
	
	StuctureProduct = Common.ObjectAttributesValues(StructureData.Products,
		"MeasurementUnit, ProductsType, VATRate");
	
	StructureData.Insert("ProductsType", StuctureProduct.ProductsType);
	StructureData.Insert("MeasurementUnit", StuctureProduct.MeasurementUnit);
	
	If StructureData.Property("VATTaxation") Then
		
		If StructureData.VATTaxation <> Enums.VATTaxationTypes.SubjectToVAT Then
			
			If StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
				StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
			Else
				StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
			EndIf;
			
		ElsIf ValueIsFilled(StuctureProduct.VATRate) Then
			StructureData.Insert("VATRate", StuctureProduct.VATRate);
		Else
			StructureData.Insert("VATRate",
				InformationRegisters.AccountingPolicy.GetDefaultVATRate(StructureData.ProcessingDate, StructureData.Company));
		EndIf;
		
	EndIf;
	
	StructureData.Insert("Price", 0);
	
	If ObjectDate <> Undefined Then
		
		If StructureData.Property("Characteristic") Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Production);
		Else
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				Catalogs.ProductsCharacteristics.EmptyRef(),
				Enums.OperationTypesProductionOrder.Production);
		EndIf;
		
		StructureData.Insert("Specification", Specification);
		
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	If StructureData.UseDefaultTypeOfAccounting And StructureData.Property("Object") Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData, ObjectDate)
	
	Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
		ObjectDate,
		StructureData.Characteristic,
		Enums.OperationTypesProductionOrder.Production);
	
	StructureData.Insert("Specification", Specification);
	
	Return StructureData;
	
EndFunction

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

&AtClient
Procedure ProductsRowCalculateAmount(Row = Undefined)
	
	If Row = Undefined Then
		Row = Items.Products.CurrentData;
	EndIf;
	
	Row.Amount = Row.Quantity * Row.Price;
	
	CalculateVATAmount(Row);
	
	Row.Total = Row.Amount + ?(Object.AmountIncludesVAT, 0, Row.VATAmount);
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

&AtClient
Procedure CalculateVATAmount(Row)
	
	VATRate = DriveReUse.GetVATRateValue(Row.VATRate);
	
	If Object.AmountIncludesVAT Then
		Row.VATAmount = Row.Amount - Row.Amount / (VATRate + 100) * 100
	Else
		Row.VATAmount = Row.Amount * VATRate / 100;
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined, ResetFlagDiscountsAreCalculated = True, RecalcSalesTax = True)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Products.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

&AtClient
Procedure CalculatePrepaymentPaymentAmount(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Prepayment.CurrentData;
	EndIf;
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		ExchangeRateMethod,
		TabularSectionRow.ExchangeRate,
		1,
		TabularSectionRow.Multiplicity,
		1,
		PricesPrecision);
	
EndProcedure

&AtClient
Function GetAdvanceExchangeRateParameters(DocumentParam, OrderParam)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Ref", Object.Ref);
	ParametersStructure.Insert("Company", Company);
	ParametersStructure.Insert("Counterparty", Object.Counterparty);
	ParametersStructure.Insert("Contract", Object.Contract);
	ParametersStructure.Insert("Document", DocumentParam);
	ParametersStructure.Insert("Order", OrderParam);
	ParametersStructure.Insert("Period", EndOfDay(Object.Date) + 1);
	
	Return ParametersStructure;
	
EndFunction

&AtServerNoContext
Function GetCalculatedAdvanceExchangeRate(ParametersStructure)
	
	Return DriveServer.GetCalculatedAdvanceReceivedExchangeRate(ParametersStructure);
	
EndFunction

#Region LibrariesHandlers

// StandardSubsystems.DataImportFromExternalSource

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		ProcessPreparedData(ImportResult);
		
		// Cash flow projection.
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillProducts", False);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

// End StandardSubsystems.DataImportFromExternalSource

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

// End StandardSubsystems.AttachableCommand

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

#Region Initialize

ThisIsNewRow = False;

#EndRegion