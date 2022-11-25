
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	False);
	ParametersStructure.Insert("FillHeader",	False);
	ParametersStructure.Insert("FillInventory",	True);
	ParametersStructure.Insert("FillExpenses",	True);
	ParametersStructure.Insert("FillMaterials",	True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UseVAT	= DriveServer.GetFunctionalOptionValue("UseVAT");
	
	// Cross-references visible.
	UseCrossReferences = Constants.UseProductCrossReferences.Get();
	
	DriveServer.FillDocumentHeader(
		Object,,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	If Not ValueIsFilled(Object.Ref)
		AND ValueIsFilled(Object.Counterparty)
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = DriveServer.GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
		EndIf;
		
		If ValueIsFilled(Object.Contract) And Not ValueIsFilled(Object.DocumentCurrency) Then
			
			If Object.DocumentCurrency <> Object.Contract.SettlementsCurrency Then	
				
				Object.DocumentCurrency				= Object.Contract.SettlementsCurrency;
				SettlementsCurrencyRateRepetition	= CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.Contract.SettlementsCurrency, Object.Company);
				Object.ExchangeRate					= ?(SettlementsCurrencyRateRepetition.Rate = 0, 1, SettlementsCurrencyRateRepetition.Rate);
				Object.Multiplicity					= ?(SettlementsCurrencyRateRepetition.Repetition = 0, 1, SettlementsCurrencyRateRepetition.Repetition);
				
			EndIf;
			
			If Not ValueIsFilled(Object.SupplierPriceTypes) Then
				Object.SupplierPriceTypes = Object.Contract.SupplierPriceTypes;
			EndIf;
			
		EndIf;
		
		If ValueIsFilled(Object.Contract) Then
			
			If Object.PaymentCalendar.Count() = 0 Then
				FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(ThisObject, "ExpensesRegisterExpense");
	
	If Not ValueIsFilled(Object.Ref) Then
		
		If Parameters.FillingValues.Property("Inventory") Then
			
			For Each RowData In Parameters.FillingValues.Inventory Do
				
				FilterStructure = New Structure;
				FilterStructure.Insert("Products", RowData.Products);
				If RowData.Property("Characteristic") And ValueIsFilled(RowData.Characteristic) Then
					FilterStructure.Insert("Characteristic", RowData.Characteristic);
				EndIf;
				Rows = Object.Inventory.FindRows(FilterStructure);
				
				For Each InventoryRow In Rows Do
					
					StructureData = New Structure;
					StructureData.Insert("Company", Object.Company);
					StructureData.Insert("Products", InventoryRow.Products);
					StructureData.Insert("Characteristic", InventoryRow.Characteristic);
					StructureData.Insert("VATTaxation", Object.VATTaxation);
					StructureData.Insert("TabName", "Inventory");
					StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
					
					If UseCrossReferences Then
						StructureData.Insert("Counterparty", Object.Counterparty);
					EndIf;
					
					If UseDefaultTypeOfAccounting Then
						AddGLAccountsToStructure(ThisObject, "Inventory", StructureData, InventoryRow);
					EndIf;
					
					StructureData = GetDataProductsOnChange(StructureData);
					
					FillPropertyValues(InventoryRow, StructureData);
					
				EndDo;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	If NOT ValueIsFilled(Object.IncomingDocumentDate) Then
		Object.IncomingDocumentDate = DocumentDate;
	EndIf;
	
	Company						= DriveServer.GetCompany(Object.Company);
	Counterparty				= Object.Counterparty;
	Contract					= Object.Contract;
	Order						= Object.Order;
	IncomingDocumentDate		= Object.IncomingDocumentDate;
	SettlementsCurrency			= Object.Contract.SettlementsCurrency;
	FunctionalCurrency			= Constants.FunctionalCurrency.Get();
	StructureByCurrency			= CurrencyRateOperations.GetCurrencyRate(Object.Date, FunctionalCurrency, Object.Company);
	RateNationalCurrency		= StructureByCurrency.Rate;
	RepetitionNationalCurrency	= StructureByCurrency.Repetition;
	ExchangeRateMethod          = DriveServer.GetExchangeMethod(Object.Company);
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	SetAccountingPolicyValues();
	
	If Not ValueIsFilled(Object.Ref) Then 
		If Not ValueIsFilled(Parameters.Basis) AND Not ValueIsFilled(Parameters.CopyingValue) Then
			FillVATRateByCompanyVATTaxation();
		EndIf;
	EndIf;
	
	// Update the form footer.
	RecalculateSubtotalAtServer();
	
	// Generate price and currency label.
	ForeignExchangeAccounting	= Constants.ForeignExchangeAccounting.Get();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("SupplierPriceTypes",				Object.SupplierPriceTypes);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
	LabelStructure.Insert("SupplierDiscountKind",			Object.DiscountType);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	ProcessingCompanyVATNumbers();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader",	True);
	ParametersStructure.Insert("FillInventory",	True);
	ParametersStructure.Insert("FillExpenses",	True);
	ParametersStructure.Insert("FillMaterials",	True);
	
	FillAddedColumns(ParametersStructure);
	
	WorkWithVAT.SetTextAboutTaxInvoiceReceived(ThisObject);
	
	DriveServer.OverrideStandartGenerateGoodsIssueCommand(ThisObject);
	DriveServer.OverrideStandartGenerateGoodsIssueReturnCommand(ThisObject, UseGoodsReturnToSupplier);
	
	SetVisibleAndEnabled();
	SetPrepaymentColumnsProperties();
	
	// Conditional appearance
	SetConditionalAppearance();
	
	User = Users.CurrentUser();
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
	MainWarehouse = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainWarehouse);
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	
	FillVATValidationAttributes();
	
	// Setting contract visible.
	SetContractVisible();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.SupplierInvoice.TabularSections.Inventory, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
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
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	SetTaxInvoiceText();
	
	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
	OldOperationKind = Object.OperationKind;
	
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
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	SetSwitchTypeListOfPaymentCalendar();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	False);
	ParametersStructure.Insert("FillHeader",	True);
	ParametersStructure.Insert("FillInventory",	True);
	ParametersStructure.Insert("FillExpenses",	True);
	ParametersStructure.Insert("FillMaterials",	True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Object.Posted And Not WriteParameters.WriteMode = DocumentWriteMode.UndoPosting Then
			
		If CheckReservedProductsChange() And Object.AdjustedReserved Then
			
			ShowQueryBoxCheckReservedProductsChange();
			Cancel = True;
			Return;
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	OrderIsFilled = False;
	FilledOrderReturn = False;
	For Each TSRow In Object.Inventory Do
		If ValueIsFilled(TSRow.Order) Then
			If TypeOf(TSRow.Order) = Type("DocumentRef.PurchaseOrder") Then
				OrderIsFilled = True;
			Else
				FilledOrderReturn = True;
			EndIf;
			Break;
		EndIf;
	EndDo;
	
	If OrderIsFilled Then
		Notify("Record_SupplierInvoice", Object.Ref);
	EndIf;
	
	If FilledOrderReturn Then
		Notify("Record_SupplierInvoiceReturn", Object.Ref);
	EndIf;
	
	Notify("NotificationAboutChangingDebt");
	Notify("RefreshAccountingTransaction");
	
	PrepaymentWasChanged = False;
	
EndProcedure

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
// 
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(
			MessageText,
			Object.Contract,
			Object.Ref,
			Object.Company,
			Object.Counterparty,
			Cancel,
			CounterpartyAttributes.DoOperationsByContracts);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en = 'Document is not posted.'; ru = 'Документ не проведен.';pl = 'Dokument niezaksięgowany.';es_ES = 'El documento no se ha publicado.';es_CO = 'El documento no se ha publicado.';tr = 'Belge kaydedilmedi.';it = 'Il documento non è pubblicato.';de = 'Dokument ist nicht gebucht.'") + " " + MessageText, MessageText);
			
			If Cancel Then
				Message.DataPath = "Object";
				Message.Field = "Contract";
				Message.Message();
				Return;
			Else
				Message.Message();
			EndIf;
		EndIf;
		
	EndIf;
	
	If DriveReUse.GetAdvanceOffsettingSettingValue() = Enums.YesNo.Yes And CurrentObject.Prepayment.Count() = 0 Then
		FillPrepayment(CurrentObject);
	ElsIf PrepaymentWasChanged Then
		WorkWithVAT.FillPrepaymentVATFromVATInput(CurrentObject);
	EndIf;
	
	CalculationParameters = New Structure;
	If Object.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		
		CalculationParameters.Insert("ReverseChargeVATIsCalculated", True);
		CalculationParameters.Insert("AmountIncludesVAT", False);
		CalculationParameters.Insert("RecalculateTotal", False);
		CalculationParameters.Insert("VATRateName", "ReverseChargeVATRate");
		CalculationParameters.Insert("VATAmountName", "ReverseChargeVATAmount");
		
		If Object.IncludeExpensesInCostPrice Then
			CalculationParameters.Insert("AdditionalAmountName", "AmountExpense");
		Else
			TabularSectionNames = New Array;
			TabularSectionNames.Add("Inventory");
			TabularSectionNames.Add("Expenses");
			CalculationParameters.Insert("TabularSectionNames", TabularSectionNames);
		EndIf;
		
		WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject, CalculationParameters);
		
	Else
		
		TabularSectionNames = New Array;
		TabularSectionNames.Add("Inventory");
		TabularSectionNames.Add("Expenses");
		CalculationParameters.Insert("TabularSectionNames", TabularSectionNames);
		
		AmountsHaveChanged = WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject, CalculationParameters);
		If AmountsHaveChanged Then
			PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(CurrentObject);
			RefillDiscountAmountOfEPDNoContext(CurrentObject);
		EndIf;
		
	EndIf;
	
	If NOT CheckEarlyPaymentDiscounts() Then
		Cancel = True;
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
		
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisObject, "BarCodeScanner");
	// End Peripherals
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	PrepaymentWasChanged = False;
	
	SetVisibleEnablePaymentTermItems();
	SetVisibleEarlyPaymentDiscounts();
	SetAdvanceInvoiceEnabled();
	SetVisibleAccordingToInvoiceType();
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
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
	
	If EventName = "RefreshTaxInvoiceText" 
		AND TypeOf(Parameter) = Type("Structure") 
		AND Not Parameter.BasisDocuments.Find(Object.Ref) = Undefined Then
		
		TaxInvoiceText = Parameter.Presentation;
	
	ElsIf EventName = "AfterRecordingOfCounterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Parameter);
		SetContractVisible();
		
	ElsIf EventName = "Write_Counterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		FillVATValidationAttributes();
		
	ElsIf EventName = "VATNumberWasChecked"
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		FillVATValidationAttributes();
		
	ElsIf EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		ChangedCount = GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		If ChangedCount Then
			CalculateAmountInTabularSectionLine("Inventory");
		EndIf; 		
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.TaxInvoiceReceived.Form.DocumentForm" Then
		TaxInvoiceText = SelectedValue;
	ElsIf ChoiceSource.FormName = "CommonForm.SelectionFromOrders" Then
		OrderedProductsSelectionProcessingAtClient(SelectedValue.TempStorageInventoryAddress);
	ElsIf ChoiceSource.FormName = "Document.GoodsReceipt.Form.SelectionForm" Then
		Items.Inventory.CurrentData.GoodsReceipt = SelectedValue;
	ElsIf GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf ChoiceSource.FormName = "Catalog.BillsOfMaterials.Form.ChoiceForm" Then
		Modified = True;
	ElsIf ChoiceSource.FormName = "CommonForm.InventoryReservation" Then
		EditReservationProcessingAtClient(SelectedValue.TempStorageInventoryReservationAddress);
	EndIf;

	SetAdvanceInvoiceEnabled();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

&AtServer
// Procedure-handler of the FillCheckProcessingAtServer event.
//
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OperationKindOnChange(Item)
	
	If Object.OperationKind = OldOperationKind Then
		Return;
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	True);
	ParametersStructure.Insert("FillHeader",	False);
	ParametersStructure.Insert("FillInventory",	True);
	ParametersStructure.Insert("FillExpenses",	True);
	ParametersStructure.Insert("FillMaterials",	False);
	
	StringOperationKind = "";
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.ZeroInvoice") Then
		StringOperationKind = NStr("en = 'Zero invoice'; ru = 'Нулевой инвойс';pl = 'Faktura zerowa';es_ES = 'Factura con importe cero';es_CO = 'Factura con importe cero';tr = 'Sıfır bedelli fatura';it = 'Fattura a zero';de = 'Null-Rechnung'");
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.DropShipping") Then
		StringOperationKind = NStr("en = 'Drop shipping'; ru = 'Дропшиппинг';pl = 'Dropshipping';es_ES = 'Envío directo';es_CO = 'Envío directo';tr = 'Stoksuz satış';it = 'Dropshipping';de = 'Streckengeschäft'");
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.Invoice") 
		And OldOperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.DropShipping") Then
		StringOperationKind = NStr("en = 'Invoice'; ru = 'Инвойс';pl = 'Faktura';es_ES = 'Factura';es_CO = 'Factura';tr = 'Fatura';it = 'Fattura';de = 'Rechnung'");
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.AdvanceInvoice")
		And OldOperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.DropShipping") Then
		StringOperationKind = NStr("en = 'Advance invoice'; ru = 'Авансовый инвойс';pl = 'Faktura zaliczkowa';es_ES = 'Factura avanzada';es_CO = 'Factura avanzada';tr = 'Avans faturası';it = 'Fattura anticipata';de = 'Vorausrechnung'");
	EndIf;
	
	If StringOperationKind <> "" Then
		
		Mode = QuestionDialogMode.YesNo;
		Notification = New NotifyDescription("OperationKindOnChangeEnd", ThisObject, ParametersStructure);
		TextQuery = NStr("en = 'If you change the invoice type to %1, 
			|the details specified on the invoice tabs will be cleared.
			|Do you want to continue?'; 
			|ru = 'Если изменить тип инвойса на %1,
			|описание, указанное на вкладках, будет удалено.
			|Продолжить?';
			|pl = 'Jeśli zmieniasz typ faktury na %1, 
			|szczegóły określone na kartach faktura zostaną wyczyszczone.
			|Czy chcesz kontynuować?';
			|es_ES = 'Si cambia el tipo de factura a %1, 
			|los detalles especificados en las pestañas de la factura se borrarán.
			|¿Quiere continuar?';
			|es_CO = 'Si cambia el tipo de factura a %1, 
			|los detalles especificados en las pestañas de la factura se borrarán.
			|¿Quiere continuar?';
			|tr = 'Fatura türünü %1 olarak değiştirirseniz 
			|fatura sekmelerinde belirtilen bilgiler temizlenir.
			|Devam edilsin mi?';
			|it = 'In caso di modifica del tipo di fattura in %1, 
			|i dettagli specificati nelle schede della fattura saranno cancellati. 
			|Continuare?';
			|de = 'Wenn Sie den Rechnungstyp auf %1 ändern, 
			|werden die auf den Registerkarten Rechnungen angegebenen Details gelöscht.
			|Möchten Sie fortsetzen?'");
		TextQuery = StringFunctionsClientServer.SubstituteParametersToString(TextQuery, StringOperationKind);
		ShowQueryBox(Notification, TextQuery, Mode, 0);
		
	Else
		
		SetMeasurementUnits();
		
		FillAddedColumns(ParametersStructure);
		
		OldOperationKind = Object.OperationKind; 
		
		SetVisibleAccordingToInvoiceType();
		
		SetVisibleEarlyPaymentDiscounts();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OperationKindOnChangeEnd(Result, ParametersStructure) Export
	
	If Result = DialogReturnCode.No Then
		
		Object.OperationKind = OldOperationKind;
		
		SetVisibleAccordingToInvoiceType();
		
		Return;
		
	EndIf; 
	
	SetZeroInvoiceData(ParametersStructure);
	
	OldOperationKind = Object.OperationKind;
	
	RecalculateSubtotal();
	
	SetVisibleAccordingToInvoiceType();
	
	SetVisibleEarlyPaymentDiscounts();
	
EndProcedure

// Procedure - event handler OnChange of the Date input field.
// In procedure situation is determined when date change document is
// into document numbering another period and in this case
// assigns to the document new unique number.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

// Procedure - event handler OnChange of the Company input field.
// In procedure is executed document
// number clearing and also make parameter set of the form functional options.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData 		= GetCompanyDataOnChange();
	Company             = StructureData.Company;
	ExchangeRateMethod  = StructureData.ExchangeRateMethod;
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	GenerateLabelPricesAndCurrency();
	
	SetTaxInvoiceText();
	
	If Object.SetPaymentTerms And ValueIsFilled(Object.PaymentMethod) Then
		PaymentTermsServerCall.FillPaymentTypeAttributes(
			Object.Company, Object.CashAssetType, Object.BankAccount, Object.PettyCash);
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	True);
	ParametersStructure.Insert("FillHeader",	False);
	ParametersStructure.Insert("FillInventory",	True);
	ParametersStructure.Insert("FillExpenses",	True);
	ParametersStructure.Insert("FillMaterials",	True);
	
	FillAddedColumns(ParametersStructure);
	
	SetVisibleAndEnabled();
	
EndProcedure

// Procedure - event handler OnChange of the input field IncludeExpensesInCostPrice.
//
&AtClient
Procedure IncludeExpensesInCostPriceOnChange(Item)
	
	If Object.IncludeExpensesInCostPrice Then
		
		Items.ExpensesOrder.Visible = False;
		Items.ExpensesStructuralUnit.Visible = False;
		Items.ExpensesBusinessLine.Visible = False;
		Items.ExpensesProject.Visible = False;
		Items.AllocateExpenses.Visible = True;
		
		Items.ExpensesReverseChargeVATRate.Visible = False;
		Items.ExpensesReverseChargeVATAmount.Visible = False;
		
		Items.InventoryAmountExpenses.Visible = True;
		Items.ExpensesGLAccounts.Visible = False;
		
		Items.ExpensesIncomeAndExpenseItems.Visible = False;
		Items.ExpensesRegisterExpense.Visible = False;
		
		For Each RowsExpenses In Object.Expenses Do
			RowsExpenses.ReverseChargeVATAmount = 0;
			RowsExpenses.RegisterExpense = False;
		EndDo;
		
	Else
		
		Items.ExpensesOrder.Visible = True;
		Items.ExpensesStructuralUnit.Visible = True;
		Items.ExpensesBusinessLine.Visible = True;
		Items.ExpensesProject.Visible = True;
		Items.AllocateExpenses.Visible = False;
		
		IsReverseChargeVATTaxation = Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ReverseChargeVAT");
		Items.ExpensesReverseChargeVATRate.Visible = IsReverseChargeVATTaxation;
		Items.ExpensesReverseChargeVATAmount.Visible = IsReverseChargeVATTaxation;
		
		Items.InventoryAmountExpenses.Visible = False;
		Items.ExpensesGLAccounts.Visible = UseDefaultTypeOfAccounting;
		
		Items.ExpensesIncomeAndExpenseItems.Visible = True;
		Items.ExpensesRegisterExpense.Visible = Not UseDefaultTypeOfAccounting;
		
		For Each StringInventory In Object.Inventory Do
			StringInventory.AmountExpense = 0;
			CalculateReverseChargeVATAmount(StringInventory);
		EndDo;
		
		For Each RowsExpenses In Object.Expenses Do
			IsIncomeAndExpenseGLA = GLAccountsInDocumentsServerCall.IsIncomeAndExpenseGLA(RowsExpenses.InventoryGLAccount);
			RowsExpenses.RegisterExpense = ?(UseDefaultTypeOfAccounting, IsIncomeAndExpenseGLA, True);

			RowsExpenses.StructuralUnit = MainDepartment;
			CalculateReverseChargeVATAmount(RowsExpenses);
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	CounterpartyDoSettlementsByOrdersBeforeChange = CounterpartyDoSettlementsByOrders;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Counterparty);
		
		ClearBasisOnChangeCounterpartyContract();
		
		ContractVisibleBeforeChange = Items.Contract.Visible;
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		
		Object.Contract = StructureData.Contract;
		
		ContractBeforeChange = Contract;
		Contract = Object.Contract;
		
		If Object.Prepayment.Count() > 0
			AND Object.Contract <> ContractBeforeChange Then
			
			ShowQueryBox(New NotifyDescription("CounterpartyOnChangeEnd", ThisObject, New Structure("CounterpartyBeforeChange, ContractBeforeChange, CounterpartyDoSettlementsByOrdersBeforeChange, ContractVisibleBeforeChange, StructureData", CounterpartyBeforeChange, ContractBeforeChange, CounterpartyDoSettlementsByOrdersBeforeChange, ContractVisibleBeforeChange, StructureData)),
				NStr("en = 'Advance clearing will be canceled. Continue?'; ru = 'Зачет аванса будет отменен. Продолжить?';pl = 'Rozliczenia zostaną anulowane. Kontynuować?';es_ES = 'Se cancelará la compensación de pago anticipado. ¿Continuar?';es_CO = 'Se cancelará la compensación de pago anticipado. ¿Continuar?';tr = 'Avans mahsubu iptal edilecek. Devam edilsin mi?';it = 'La compensazione anticipo verrà annullata. Continuare?';de = 'Vorschußverrechnung wird gelöscht. Weiter?'"),
				QuestionDialogMode.YesNo);
			Return;
			
		EndIf;
		
		ProcessContractChangeFragment(ContractBeforeChange, StructureData);
		
		SetPrepaymentColumnsProperties();
		SetVisibleEnablePaymentTermItems();
		SetCrossReferenceVisible(True);
		
		CounterpartyOnChangeFragmentServer(StructureData);
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		Object.Order = Order;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CounterpartyOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Object.Prepayment.Clear();
	Else 
		Object.Counterparty = AdditionalParameters.CounterpartyBeforeChange;
		Counterparty = AdditionalParameters.CounterpartyBeforeChange;
		Object.Contract = AdditionalParameters.ContractBeforeChange;
		Contract = AdditionalParameters.ContractBeforeChange;
		Object.Order = Order;
		CounterpartyDoSettlementsByOrders = AdditionalParameters.CounterpartyDoSettlementsByOrdersBeforeChange;
		Items.Contract.Visible = AdditionalParameters.ContractVisibleBeforeChange;
		Return;
	EndIf;
	
	ProcessContractChangeFragment(AdditionalParameters.ContractBeforeChange, AdditionalParameters.StructureData);
	
EndProcedure

// The OnChange event handler of the Contract field.
// It updates the currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

// Procedure - event handler StartChoice of the Contract input field.
//
&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormParameters(
		Object.Ref,
		Object.Company,
		Object.Counterparty,
		Object.Contract,
		CounterpartyAttributes.DoOperationsByContracts);
		
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the input field Order.
//
&AtClient
Procedure OrderOnChange(Item)
	
	OrderBefore = Order;
	Order = Object.Order;
	
	If Object.Prepayment.Count() > 0
		AND OrderBefore <> Object.Order Then
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("OrderOnChangeEnd", ThisObject, New Structure("OrderBefore", OrderBefore)), NStr("en = 'Advance clearing will be canceled. Continue?'; ru = 'Зачет аванса будет отменен. Продолжить?';pl = 'Rozliczenia zostaną anulowane. Kontynuować?';es_ES = 'Se cancelará la compensación de pago anticipado. ¿Continuar?';es_CO = 'Se cancelará la compensación de pago anticipado. ¿Continuar?';tr = 'Avans mahsubu iptal edilecek. Devam edilsin mi?';it = 'La compensazione anticipo verrà annullata. Continuare?';de = 'Vorschußverrechnung wird gelöscht. Weiter?'"), Mode, 0);
	EndIf;
	
EndProcedure

&AtClient
Procedure OrderOnChangeEnd(Result, AdditionalParameters) Export
	
	OrderBefore = AdditionalParameters.OrderBefore;
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		Object.Prepayment.Clear();
	Else
		Object.Order = OrderBefore;
		Order = OrderBefore;
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

// Procedure fills advances.
//
&AtServer
Procedure FillPrepayment(CurrentObject)
	
	CurrentObject.FillPrepayment();
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
		
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False);
	
EndFunction

&AtServer
Procedure SetTaxInvoiceText()
	Items.TaxInvoiceText.Visible = WorkWithVAT.GetUseTaxInvoiceForPostingVAT(Object.Date, Object.Company)
EndProcedure

&AtClient
Procedure GLAccountsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	GLAccountsInDocumentsClient.OpenCounterpartyGLAccountsForm(ThisObject, Object, "");
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersInventory

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow AND Copy Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;
	
	If Item.CurrentItem.Name = "SerialNumbersInventory" Then
		OpenSerialNumbersSelection();
	EndIf;
	
	If Not NewRow Or Copy Then
		Return;
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the "Invetory" tabular section.
//
&AtClient
Procedure InventoryOnChange(Item)
	
	RecalculateSubtotal();
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RefillDiscountAmountOfEPD();
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Items.Inventory.CurrentData;
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData,,UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		StandardProcessing = False;
		IsReadOnly = (Object.OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.ZeroInvoice"));
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory", , IsReadOnly);
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
		If TableCurrentColumn.Name = "InventoryGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Inventory.CurrentRow;
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	
EndProcedure

&AtClient
Procedure InventoryGoodsReceiptChoiceEnd(SelectedValue, AdditionalParameters = Undefined) Export
	
	If SelectedValue = Undefined Then
		Return;
	EndIf;
	
	TabRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	AddGLAccountsToStructure(ThisObject, "Inventory", StructureData);
	
	StructureData.Insert("Products",		TabRow.Products);
	StructureData.Insert("GoodsReceipt",	SelectedValue);

	InventoryGoodsReceiptOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
	SetAdvanceInvoiceEnabled();
	
EndProcedure

&AtServer
Procedure InventoryGoodsReceiptOnChangeAtServer(StructureData)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	StructureData.Insert("ObjectParameters", ObjectParameters);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryGoodsReceiptOnChange(Item)
	
	TabRow = Items.Inventory.CurrentData;
	InventoryGoodsReceiptChoiceEnd(TabRow.GoodsReceipt);
	
	SetAdvanceInvoiceEnabled();
	
EndProcedure

&AtClient
Procedure InventoryGoodsReceiptChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	InventoryGoodsReceiptChoiceEnd(SelectedValue);
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.ZeroInvoice") Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillHeader",	False);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillExpenses",	True);
		ParametersStructure.Insert("FillMaterials",	False);
		
		FillAddedColumns(ParametersStructure);
		
		Return;
		
	EndIf;
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Counterparty", Object.Counterparty);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("DiscountType", Object.DiscountType);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If ValueIsFilled(Object.SupplierPriceTypes) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
		StructureData.Insert("Factor", 1);
		
	EndIf;
	
	AddGLAccountsToStructure(ThisObject, "Inventory", StructureData);
	StructureData = GetDataProductsOnChange(StructureData, Object.Date);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Content = "";
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,,UseSerialNumbersBalance);
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

// Procedure - event handler OnChange of the variant input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
		
	StructureData = New Structure;
	StructureData.Insert("Counterparty", 	Object.Counterparty);
	StructureData.Insert("Company", 		Object.Company);
	StructureData.Insert("Products",	 TabularSectionRow.Products);
	StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		
	If ValueIsFilled(Object.SupplierPriceTypes) Then
	
		StructureData.Insert("ProcessingDate",		Object.Date);
		StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
		StructureData.Insert("VATRate",				TabularSectionRow.VATRate);
		StructureData.Insert("Price",				TabularSectionRow.Price);
		StructureData.Insert("SupplierPriceTypes",	Object.SupplierPriceTypes);
		StructureData.Insert("MeasurementUnit",		TabularSectionRow.MeasurementUnit);
		
	EndIf;
	
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date);
	If StructureData.Property("Specification") Then
		TabularSectionRow.Specification = StructureData.Specification;
	EndIf;
	
	StructureData.Property("CrossReference", TabularSectionRow.CrossReference);
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.Content = "";
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.Inventory.CurrentData;
	
	If DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "Inventory";
		SelectionParameters	= DriveClient.GetMatrixParameters(ThisObject, TabularSectionName, False);
		NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseVariantsSelection", ThisObject);
		OpenForm("Catalog.ProductsCharacteristics.Form.MatrixChoiceForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the CrossReference input field.
//
&AtClient
Procedure InventoryCrossReferenceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Counterparty", Object.Counterparty);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("CrossReference", TabularSectionRow.CrossReference);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	If ValueIsFilled(Object.SupplierPriceTypes) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
		StructureData.Insert("Factor", 1);
		
	EndIf;
	
	AddGLAccountsToStructure(ThisObject, "Inventory", StructureData);
	StructureData = GetDataCrossReferenceOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Content = "";
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,,UseSerialNumbersBalance);
	
	CalculateAmountInTabularSectionLine("Inventory");
	
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
	
	CalculateAmountInTabularSectionLine("Inventory");
	
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
	
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

&AtClient
Procedure InventoryDiscountPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

&AtClient
Procedure InventoryDiscountAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.DiscountAmount;
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.DiscountPercent = 100 Then
		TabularSectionRow.DiscountAmount = TabularSectionRow.Amount;
	Else
		TabularSectionRow.DiscountAmount = (TabularSectionRow.Amount / (100 - TabularSectionRow.DiscountPercent))
											* TabularSectionRow.DiscountPercent;
	EndIf;
	
	AmountWithoutDiscount = TabularSectionRow.Amount + TabularSectionRow.DiscountAmount;
	
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = AmountWithoutDiscount / TabularSectionRow.Quantity;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
	RefillDiscountAmountOfEPD();
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
	RefillDiscountAmountOfEPD();
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
	RefillDiscountAmountOfEPD();
	
EndProcedure

&AtClient
Procedure InventoryAmountExpensesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure InventoryReverseChargeVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure InventoryGoodsReceiptStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ParametersStructure = New Structure;
	
	If Object.PurchaseOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
		ParametersStructure.Insert("OrderFilter", Object.Order);
	Else
		ParametersStructure.Insert("OrderFilter", Items.Inventory.CurrentData.Order);
	EndIf;
	
	NotifyDescription = New NotifyDescription("InventoryGoodsReceiptChoiceEnd", ThisObject);
	
	OpenForm("Document.GoodsReceipt.ChoiceForm", ParametersStructure, ThisObject,,,, NotifyDescription);

EndProcedure

&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	RefillDiscountAmountOfEPD();
	
	If Object.Inventory.Count() = 0 Then
		SetAdvanceInvoiceEnabled();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersExpenses

// Procedure - event handler OnChange of the "Costs" tabular section.
//
&AtClient
Procedure ExpensesOnChange(Item)
	
	RecalculateSubtotal();
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RefillDiscountAmountOfEPD();
	
EndProcedure

// Procedure - event handler AtStartEdit of the "Costs" tabular section.
//
&AtClient
Procedure ExpensesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		TabularSectionRow = Items.Expenses.CurrentData;
		TabularSectionRow.StructuralUnit = MainDepartment;
		
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
	
	If Items.Inventory.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Inventory.CurrentItem;
		
		CurrentData = Items.Expenses.CurrentData;
		
		If TableCurrentColumn.Name = "ExpensesGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			
			SelectedRow = Items.Expenses.CurrentRow;
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Expenses");
			
		ElsIf TableCurrentColumn.Name = "ExpensesIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			
			SelectedRow = Items.Expenses.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Expenses");
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure ExpensesGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectedRow = Items.Expenses.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Expenses");
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure ExpensesProductsOnChange(Item)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.ZeroInvoice") Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillHeader",	False);
		ParametersStructure.Insert("FillInventory",	True);
		ParametersStructure.Insert("FillExpenses",	True);
		ParametersStructure.Insert("FillMaterials",	False);
		
		FillAddedColumns(ParametersStructure);
		
		Return;
		
	EndIf;
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Counterparty", Object.Counterparty);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", PredefinedValue("Catalog.ProductsCharacteristics.EmptyRef"));
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("TabName", "Expenses");
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	StructureData.Insert("RegisterExpense", TabularSectionRow.RegisterExpense);
	StructureData.Insert("ExpenseItem", TabularSectionRow.ExpenseItem);
	StructureData.Insert("IncomeAndExpenseItems",	TabularSectionRow.IncomeAndExpenseItems);
	StructureData.Insert("IncomeAndExpenseItemsFilled", TabularSectionRow.IncomeAndExpenseItemsFilled);
	
	AddGLAccountsToStructure(ThisObject, "Expenses", StructureData);
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	
	TabularSectionRow.Price = 0;
	TabularSectionRow.Amount = 0;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.VATAmount = 0;
	TabularSectionRow.Total = 0;
	TabularSectionRow.ReverseChargeVATRate = StructureData.ReverseChargeVATRate;
	TabularSectionRow.ReverseChargeVATAmount = 0;
	TabularSectionRow.Content = ""; 
	
	If Object.OperationKind <> PredefinedValue("Enum.OperationTypesSupplierInvoice.ZeroInvoice") Then
	
		TabularSectionRow.Quantity = 1;
		TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	
	EndIf;
	
	If StructureData.ClearOrderAndDepartment Then
		TabularSectionRow.StructuralUnit = Undefined;
		TabularSectionRow.Order = Undefined;
	ElsIf Not ValueIsFilled(TabularSectionRow.StructuralUnit) Then
		TabularSectionRow.StructuralUnit = MainDepartment;
	EndIf;
	
	If StructureData.ClearBusinessLine Then
		TabularSectionRow.BusinessLine = Undefined;
	Else
		TabularSectionRow.BusinessLine = StructureData.BusinessLine;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the CrossReference input field.
//
&AtClient
Procedure ExpensesCrossReferenceOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Counterparty", Object.Counterparty);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("CrossReference", TabularSectionRow.CrossReference);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("TabName", "Expenses");
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	StructureData.Insert("RegisterExpense", TabularSectionRow.RegisterExpense);
	StructureData.Insert("ExpenseItem", TabularSectionRow.ExpenseItem);
	StructureData.Insert("IncomeAndExpenseItems",	TabularSectionRow.IncomeAndExpenseItems);
	StructureData.Insert("IncomeAndExpenseItemsFilled", TabularSectionRow.IncomeAndExpenseItemsFilled);
	
	If ValueIsFilled(Object.SupplierPriceTypes) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
		StructureData.Insert("Factor", 1);
		
	EndIf;
	
	AddGLAccountsToStructure(ThisObject, "Expenses", StructureData);
	StructureData = GetDataCrossReferenceOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Content = "";
	
	CalculateAmountInTabularSectionLine("Expenses");
	
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
	
	CalculateAmountInTabularSectionLine("Expenses");
	
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
		StructureData = GetDataMeasurementUnitOnChange(, ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine("Expenses");
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure ExpensesPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Expenses");
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure AmountExpensesOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
	RefillDiscountAmountOfEPD();
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure ExpensesVATRateOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
	RefillDiscountAmountOfEPD();
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure AmountExpensesVATOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
	RefillDiscountAmountOfEPD();
	
EndProcedure

&AtClient
Procedure ExpensesReverseChargeVATRateOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
EndProcedure

// Procedure - SelectionStart event handler of the ExpensesBusinessLine input field.
//
&AtClient
Procedure ExpensesBusinessLineStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = GetDataBusinessLineStartChoice(TabularSectionRow.ExpenseItem);
	
	If Not StructureData.AvailabilityOfPointingLinesOfBusiness Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("en = 'Business line is not required for this type of expenses.'; ru = 'Для этого типа расходов направление деятельности не указывается.';pl = 'Rodzaj działalności nie jest wymagany dla tego typu rozchodów.';es_ES = 'No se requiere línea de negocio para este tipo de gastos.';es_CO = 'No se requiere línea de negocio para este tipo de gastos.';tr = 'Bu tür harcamalar için iş kolu gerekli değil.';it = 'Non è richiesta la linea di business per questo tipo di spesa.';de = 'Der Geschäftsbereich wird für diese Art von Ausgaben nicht benötigt.'"));
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler SelectionStart of the StructuralUnit input field.
//
Procedure ExpensesBusinessUnitstartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = GetDataBusinessUnitstartChoice(TabularSectionRow.ExpenseItem);
	
	If Not StructureData.AbilityToSpecifyDepartments Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("en = 'Department is not required for this type of expenses.'; ru = 'Для этого типа расходов подразделение не указывается.';pl = 'Dział nie jest wymagany dla tego typu rozchodów.';es_ES = 'No se requiere departamento para este tipo de gastos.';es_CO = 'No se requiere departamento para este tipo de gastos.';tr = 'Bu tür harcamalar için bölüm gerekli değil.';it = 'Non è richiesto il reparto per questo tipo di spesa.';de = 'Für diesen Typ von Ausgaben ist keine Abteilung erforderlich.'"));
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler SelectionStart of input field Order.
//
Procedure ExpensesOrderStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = GetDataOrderStartChoice(TabularSectionRow.ExpenseItem);
	
	If Not StructureData.AbilityToSpecifyOrder Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("en = 'Order is not required for this type of expenses.'; ru = 'Для этого типа расходов заказ не указывается.';pl = 'Zamówienie nie jest wymagane dla tego typu rozchodów.';es_ES = 'No se requiere pedido para este tipo de gastos.';es_CO = 'No se requiere pedido para este tipo de gastos.';tr = 'Bu tür harcamalar için sipariş gerekli değil.';it = 'Non è richiesto l''ordine per questo tipo di spesa.';de = 'Für diesen Typ von Ausgaben ist kein Auftrag erforderlich.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesAfterDeleteRow(Item)
	
	RefillDiscountAmountOfEPD();
	
EndProcedure

&AtClient
Procedure ExpensesIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Expenses", StandardProcessing);
	
EndProcedure

&AtClient
Procedure ExpensesRegisterExpenseOnChange(Item)
	
	CurrentData = Items.Expenses.CurrentData;
	
	If CurrentData <> Undefined And Not CurrentData.RegisterExpense Then
		CurrentData.ExpenseItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	False);
		ParametersStructure.Insert("FillHeader",	False);
		ParametersStructure.Insert("FillInventory",	False);
		ParametersStructure.Insert("FillExpenses",	True);
		ParametersStructure.Insert("FillMaterials",	False);
		
		FillAddedColumns(ParametersStructure);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesDiscountAmountOnChange(Item)
	TabularSectionRow = Items.Expenses.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.DiscountAmount;
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
EndProcedure

&AtClient
Procedure ExpensesDiscountPercentOnChange(Item)
	CalculateAmountInTabularSectionLine("Expenses");
EndProcedure
#EndRegion

#Region FormTableItemsEventHandlersMaterials

&AtClient
Procedure MaterialsOnStartEdit(Item, NewRow, Copy)
	
	If Not NewRow Or Copy Then
		Return;
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
EndProcedure

&AtClient
Procedure MaterialsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "MaterialsGLAccounts" Then
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Materials");
	EndIf;
	
EndProcedure

&AtClient
Procedure MaterialsOnActivateCell(Item)
	
	CurrentData = Items.Materials.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Materials.CurrentItem;
		
		If TableCurrentColumn.Name = "MaterialsGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			
			SelectedRow = Items.Materials.CurrentRow;
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Materials");
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MaterialsOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure MaterialsGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectedRow = Items.Materials.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Materials");
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure MaterialsProductsOnChange(Item)
	
	TabularSectionRow = Items.Materials.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddGLAccountsToStructure(ThisObject, "Materials", StructureData);
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.Quantity = 1;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPrepayment

&AtClient
Procedure PrepaymentAccountsAmountOnChange(Item)
	
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
Procedure PrepaymentRateOnChange(Item)
	
	CalculatePrepaymentPaymentAmount();
	
EndProcedure

&AtClient
Procedure PrepaymentMultiplicityOnChange(Item)
	
	CalculatePrepaymentPaymentAmount();
	
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

&AtClient
Procedure PrepaymentOnChange(Item)
	PrepaymentWasChanged = True;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPaymentCalendar

// Procedure - event handler OnChange of the ReflectInPaymentCalendar input field.
//
&AtClient
Procedure SetPaymentTermsOnChange(Item)
	
	If Object.SetPaymentTerms Then
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar, True);
		SetVisibleEnablePaymentTermItems();
		
	Else
		
		Notify = New NotifyDescription("ClearPaymentCalendarContinue", ThisObject);
		
		QueryText = NStr("en = 'The payment terms will be cleared. Do you want to continue?'; ru = 'Условия оплаты будут очищены. Продолжить?';pl = 'Warunki płatności zostaną wyczyszczone. Czy chcesz kontynuować?';es_ES = 'Los términos de pagos se eliminarán. ¿Quiere continuar?';es_CO = 'Los términos de pagos se eliminarán. ¿Quiere continuar?';tr = 'Ödeme şartları silinecek. Devam etmek istiyor musunuz?';it = 'I termini di pagamento saranno cancellati. Continuare?';de = 'Die Zahlungsbedingungen werden gelöscht. Möchten Sie fortfahren?'");
		ShowQueryBox(Notify, QueryText,  QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field SwitchTypeListOfPaymentCalendar.
//
&AtClient
Procedure FieldSwitchTypeListOfPaymentCalendarOnChange(Item)
	
	LineCount = Object.PaymentCalendar.Count();
	
	If Not SwitchTypeListOfPaymentCalendar AND LineCount > 1 Then
		Response = Undefined;
		ShowQueryBox(
			New NotifyDescription("SetEditInListEndOption", ThisObject, New Structure("LineCount", LineCount)),
			NStr("en = 'All lines except for the first one will be deleted. Continue?'; ru = 'Все строки кроме первой будут удалены. Продолжить?';pl = 'Wszystkie wiersze za wyjątkiem pierwszego zostaną usunięte. Kontynuować?';es_ES = 'Todas las líneas a excepción de la primera se eliminarán. ¿Continuar?';es_CO = 'Todas las líneas a excepción de la primera se eliminarán. ¿Continuar?';tr = 'İlki haricinde tüm satırlar silinecek. Devam edilsin mi?';it = 'Tutte le linee eccetto la prima saranno cancellate. Continuare?';de = 'Alle Zeilen bis auf die erste werden gelöscht. Fortsetzen?'"),
			QuestionDialogMode.YesNo);
		Return;
	EndIf;
	
	SetVisiblePaymentCalendar();
	
EndProcedure

&AtClient
Procedure PaymentMethodOnChange(Item)
	
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	SetVisiblePaymentMethod();
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPaymentPercent input field.
//
&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	CurrentRow.PaymentAmount = Round(AmountForPaymentCalendar(Object) * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(VATForPaymentCalendar(Object) * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPaymentAmount input field.
//
&AtClient
Procedure PaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotal = AmountForPaymentCalendar(Object);
	
	CurrentRow.PaymentPercentage = ?(InventoryTotal = 0, 0, Round(CurrentRow.PaymentAmount / InventoryTotal * 100, 2, 1));
	CurrentRow.PaymentVATAmount = Round(VATForPaymentCalendar(Object) * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPayVATAmount input field.
//
&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotal = VATForPaymentCalendar(Object);
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	
	If PaymentCalendarTotal > InventoryTotal Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - InventoryTotal);
	EndIf;
	
EndProcedure

// Procedure - OnStartEdit event handler of the .PaymentCalendar list
//
&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Copy)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	If NewRow Then
		CurrentRow.PaymentBaselineDate = PredefinedValue("Enum.BaselineDateForPayment.InvoicePostingDate");
		CurrentRow.CashFlowItem = ContractCashFlowItem(Object.Contract);
	EndIf;
	
	If CurrentRow.PaymentPercentage = 0 Then
		CurrentRow.PaymentPercentage = 100 - Object.PaymentCalendar.Total("PaymentPercentage");
		CurrentRow.PaymentAmount = AmountForPaymentCalendar(Object) - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = VATForPaymentCalendar(Object) - Object.PaymentCalendar.Total("PaymentVATAmount");
	EndIf;
	
EndProcedure

// Procedure - BeforeDeletion event handler of the PaymentCalendar tabular section.
//
&AtClient
Procedure PaymentCalendarBeforeDelete(Item, Cancel)
	
	If Object.PaymentCalendar.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersEarlyPaymentDiscounts

&AtClient
Procedure EarlyPaymentDiscountsPeriodOnChange(Item)
	
	CalculateRowDueDateOfEPD(Object.Date);
	
EndProcedure

&AtClient
Procedure EarlyPaymentDiscountsDiscountOnChange(Item)
	
	TotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total");
	
	DiscountRow = Items.EarlyPaymentDiscounts.CurrentData;
	CalculateRowDiscountAmountOfEPD(TotalAmount, DiscountRow);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CheckVATNumber(Command)
	
	CheckVATNumberAtServer();
	Notify("VATNumberWasChecked", Object.Counterparty);
	
EndProcedure

&AtClient
Procedure EditReservation(Command)
	
	If Modified And Object.Posted Then
		
		Cancel = False;
		CheckReservedProductsChangeClient(Cancel);
		
		If Not Cancel Then
			OpenInventoryReservation();
		EndIf;
		Return;
		
	ElsIf (Modified Or Not Object.Posted) Then 
		
		MessagesToUserClient.ShowMessageCannotOpenInventoryReservationWindow();
		Return;
		
	EndIf;

	OpenInventoryReservation();
	
EndProcedure

&AtClient
Procedure OpenInventoryReservation()
	
	FormParameters = New Structure;
	FormParameters.Insert("TempStorageAddress", PutEditReservationDataToTempStorage());
	FormParameters.Insert("AdjustedReserved", Object.AdjustedReserved);
	FormParameters.Insert("UseAdjustedReserve", ChangeAdjustedReserved() And Object.AdjustedReserved);
	
	OpenForm("CommonForm.InventoryReservation", FormParameters, ThisObject);
	
EndProcedure

#EndRegion

#Region Private

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

#Region InteractiveActionResultHandlers

// Procedure-handler of the result of opening the "Prices and currencies" form
//
&AtClient
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	// 3. Refill the tabular section "Inventory" if changes were made to the form "Prices and Currency".
	If TypeOf(ClosingResult) = Type("Structure") And ClosingResult.WereMadeChanges Then
		
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
		Object.SupplierPriceTypes = ClosingResult.SupplierPriceTypes;
		Object.RegisterVendorPrices = ClosingResult.RegisterVendorPrices;
		Object.DiscountType = ClosingResult.SupplierDiscountKind;
		
		If Not RegisteredForSalesTax Then
			
			Object.VATTaxation = ClosingResult.VATTaxation;
			Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
			Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
			Object.AutomaticVATCalculation = ClosingResult.AutomaticVATCalculation;
			
			// Recalculate the amount if VAT taxation flag is changed.
			If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
				FillVATRateByVATTaxation();
			EndIf;
			
		EndIf;
		
		// DiscountCards
		If ValueIsFilled(ClosingResult.DiscountCard)
			And ValueIsFilled(ClosingResult.Counterparty)
			And Not Object.Counterparty.IsEmpty() Then
			
			If ClosingResult.Counterparty = Object.Counterparty Then
				Object.DiscountCard = ClosingResult.DiscountCard;
			Else
				CommonClientServer.MessageToUser(
					DiscountCardsClient.GetDiscountCardInapplicableMessage(),
					,
					"Counterparty",
					"Object");
			EndIf;
			
		Else
			Object.DiscountCard = ClosingResult.DiscountCard;
		EndIf;
		// End DiscountCards
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			DriveClient.RefillTabularSectionPricesBySupplierPriceTypes(ThisObject, "Inventory", True);
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices And ClosingResult.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Inventory", PricesPrecision);
		EndIf;
		
		If ClosingResult.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Expenses", PricesPrecision);
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices And ClosingResult.AmountIncludesVAT <> ClosingResult.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Inventory", PricesPrecision);
		EndIf;
		
		If ClosingResult.AmountIncludesVAT <> ClosingResult.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Expenses", PricesPrecision);
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
		
		Modified = True;
		
		RecalculateSubtotal();
	
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RefillDiscountAmountOfEPD();
		OpenPricesAndCurrencyFormEndAtServer();
		
	EndIf;
	
	GenerateLabelPricesAndCurrency();	
	
EndProcedure

&AtServer
Procedure OpenPricesAndCurrencyFormEndAtServer() 
	
	SetPrepaymentColumnsProperties();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	True);
	ParametersStructure.Insert("FillHeader",	True);
	ParametersStructure.Insert("FillInventory",	True);
	ParametersStructure.Insert("FillExpenses",	True);
	ParametersStructure.Insert("FillMaterials",	True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

#EndRegion

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileServices(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.SupplierInvoice.TabularSection.Expenses";
	
	DataLoadSettings.Insert("TabularSectionFullName", "SupplierInvoice.Expenses");
	DataLoadSettings.Insert("Title", NStr("en = 'Import services from file'; ru = 'Загрузка услуг из файла';pl = 'Import usług z pliku';es_ES = 'Importar los servicios del archivo';es_CO = 'Importar los servicios del archivo';tr = 'Hizmetleri dosyadan içe aktar';it = 'Servizi di importazione da file';de = 'Importieren Sie Dienstleistungen aus der Datei'"));
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure LoadFromFileInventory(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.SupplierInvoice.TabularSection.Inventory";
	
	DataLoadSettings.Insert("TabularSectionFullName",	"SupplierInvoice.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import inventory from file'; ru = 'Загрузка запасов из файла';pl = 'Import zapasów z pliku';es_ES = 'Importar el inventario del archivo';es_CO = 'Importar el inventario del archivo';tr = 'Stoku dosyadan içe aktar';it = 'Importazione delle scorte da file';de = 'Bestand aus Datei importieren'"));
	DataLoadSettings.Insert("OrderPositionInDocument",	Object.PurchaseOrderPosition);
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

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
	
	If ImportResult.DataLoadSettings.TabularSectionFullName = "SupplierInvoice.Inventory" Then
		IsInventory = True;
	Else
		IsInventory = False;
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	True);
	ParametersStructure.Insert("FillHeader",	False);
	ParametersStructure.Insert("FillInventory",	IsInventory);
	ParametersStructure.Insert("FillExpenses",	Not IsInventory);
	ParametersStructure.Insert("FillMaterials",	False);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure
#EndRegion

#Region CopyPasteRows

&AtClient
Procedure InventoryCopyRows(Command)
	CopyRowsTabularPart("Inventory");
EndProcedure

&AtClient
Procedure CopyRowsTabularPart(TabularPartName)
	
	If TabularPartCopyClient.CanCopyRows(Object[TabularPartName],Items[TabularPartName].CurrentData) Then
		
		CountOfCopied = 0;
		CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied);
		TabularPartCopyClient.NotifyUserCopyRows(CountOfCopied);
		
	EndIf;
	
EndProcedure

&AtServer 
Procedure CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied)
	
	TabularPartCopyServer.Copy(Object[TabularPartName], Items[TabularPartName].SelectedRows, CountOfCopied);
	
EndProcedure

&AtClient
Procedure InventoryPasteRows(Command)
	PasteRowsTabularPart("Inventory");   
EndProcedure

&AtClient
Procedure PasteRowsTabularPart(TabularPartName)
	
	CountOfCopied = 0;
	CountOfPasted = 0;
	PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted);
	ProcessPastedRows(TabularPartName, CountOfPasted);
	TabularPartCopyClient.NotifyUserPasteRows(CountOfCopied, CountOfPasted);
	
EndProcedure

&AtServer
Procedure PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted)
	
	TabularPartCopyServer.Paste(Object, TabularPartName, Items, CountOfCopied, CountOfPasted);
	ProcessPastedRowsAtServer(TabularPartName, CountOfPasted);
	
EndProcedure

&AtClient
Procedure ProcessPastedRows(TabularPartName, CountOfPasted)
	
	If TabularPartName = "Inventory" Then
		
		Count = Object[TabularPartName].Count();
		
		For iterator = 1 To CountOfPasted Do
			
			Row = Object[TabularPartName][Count - iterator];
			CalculateAmountInTabularSectionLine(TabularPartName,Row);
			
		EndDo; 
		
	EndIf;
	           	
EndProcedure

&AtServer
Procedure ProcessPastedRowsAtServer(TabularPartName, CountOfPasted)
	
	Count = Object[TabularPartName].Count();
	
	For iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - iterator];
		
		StructureData = New Structure;
		StructureData.Insert("Company", Object.Company);
		StructureData.Insert("Products", Row.Products);
		StructureData.Insert("VATTaxation", Object.VATTaxation);
		StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
		If TabularPartName = "Expenses" Then
			StructureData.Insert("RegisterExpense", Row.RegisterExpense);
			StructureData.Insert("ExpenseItem", Row.ExpenseItem);
			StructureData.Insert("IncomeAndExpenseItems",	Row.IncomeAndExpenseItems);
			StructureData.Insert("IncomeAndExpenseItemsFilled", Row.IncomeAndExpenseItemsFilled);
		EndIf;
		
		AddGLAccountsToStructure(ThisObject, TabularPartName, StructureData, Row);
		StructureData = GetDataProductsOnChange(StructureData);
		
		If TabularPartName = "Inventory" Then
			
			Row.VATRate = StructureData.VATRate;
			
		ElsIf TabularPartName = "Expenses" Then
			
			Row.MeasurementUnit = MainDepartment;
			
		EndIf;
		
		If Not ValueIsFilled(Row.MeasurementUnit) Then
			Row.MeasurementUnit = StructureData.MeasurementUnit;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ExpensesCopyRows(Command)
	CopyRowsTabularPart("Expenses"); 
EndProcedure

&AtClient
Procedure ExpensesPasteRows(Command)
	PasteRowsTabularPart("Expenses"); 
EndProcedure

#EndRegion

#Region GeneralPurposeProceduresAndFunctionsOfPaymentCalendar

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

// Procedure sets availability of the form items.
//
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

&AtServerNoContext
Function PaymentMethodCashAssetType(PaymentMethod)
	
	Return Common.ObjectAttributeValue(PaymentMethod, "CashAssetType");
	
EndFunction

&AtServer
Procedure DatesChangeProcessing()
	PaymentTermsServer.ShiftPaymentCalendarDates(Object, ThisObject);
EndProcedure

&AtClient
Procedure ClearPaymentCalendarContinue(Answer, Parameters) Export
	If Answer = DialogReturnCode.Yes Then
		Object.PaymentCalendar.Clear();
		SetEnableGroupPaymentCalendarDetails();
	ElsIf Answer = DialogReturnCode.No Then
		Object.SetPaymentTerms = True;
	EndIf;
EndProcedure

&AtClient
Procedure SetEditInListEndOption(Result, AdditionalParameters) Export
	
	LineCount = AdditionalParameters.LineCount;
	
	If Result = DialogReturnCode.No Then
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
Procedure SetSwitchTypeListOfPaymentCalendar()
	
	If Object.PaymentCalendar.Count() > 1 Then
		SwitchTypeListOfPaymentCalendar = 1;
	Else
		SwitchTypeListOfPaymentCalendar = 0;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function VATForPaymentCalendar(Object)
	
	VATForPaymentCalendar = Object.Inventory.Total("VATAmount") + Object.Expenses.Total("VATAmount");
	
	Return VATForPaymentCalendar;
	
EndFunction

&AtClientAtServerNoContext
Function AmountForPaymentCalendar(Object)
	
	AmountForPaymentCalendar = Object.Inventory.Total("Amount") + Object.Expenses.Total("Amount");
	
	Return AmountForPaymentCalendar;
	
EndFunction

#EndRegion

#Region EarlyPaymentDiscount

&AtServerNoContext
Function GetVisibleFlagForEPD(Counterparty, Contract)
	
	If ValueIsFilled(Contract) Then
		ContractKind		= Common.ObjectAttributeValue(Contract, "ContractKind");
		ContractKindFlag	= (ContractKind = Enums.ContractType.WithVendor);
	Else
		ContractKindFlag	= False;
	EndIf;
	
	Return (ValueIsFilled(Counterparty) AND ContractKindFlag);
	
EndFunction

&AtServer
Function CheckEarlyPaymentDiscounts()
	
	Return EarlyPaymentDiscountsServer.CheckEarlyPaymentDiscounts(Object.EarlyPaymentDiscounts, Object.ProvideEPD);
	
EndFunction

&AtServer
Procedure FillEarlyPaymentDiscounts()
	
	EarlyPaymentDiscountsServer.FillEarlyPaymentDiscounts(Object, Enums.ContractType.WithVendor);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	False);
	ParametersStructure.Insert("FillHeader",	False);
	ParametersStructure.Insert("FillInventory",	True);
	ParametersStructure.Insert("FillExpenses",	True);
	ParametersStructure.Insert("FillMaterials",	True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure CalculateRowDueDateOfEPD(DateForCalc, DiscountRow = Undefined)
	
	If DiscountRow = Undefined Then
		DiscountRow = Items.EarlyPaymentDiscounts.CurrentData;
	EndIf;
	
	If DiscountRow = Undefined Then
		Return;
	EndIf;
	
	DiscountRow.DueDate = DateForCalc + DiscountRow.Period * 86400;
	
EndProcedure

&AtClient
Procedure RefillDiscountAmountOfEPD()
	RefillDiscountAmountOfEPDNoContext(Object);
EndProcedure

&AtClientAtServerNoContext
Procedure RefillDiscountAmountOfEPDNoContext(Object)
	
	TotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total");
	
	For Each DiscountRow In Object.EarlyPaymentDiscounts Do
		
		CalculateRowDiscountAmountOfEPD(TotalAmount, DiscountRow);
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure CalculateRowDiscountAmountOfEPD(TotalAmount, DiscountRow)
	
	If DiscountRow = Undefined Then
		Return;
	EndIf;
	
	DiscountRow.DiscountAmount = Round(TotalAmount * DiscountRow.Discount / 100, 2);
	
EndProcedure

#EndRegion

#Region EventHandlersOfIncomingDocument

&AtClient
Procedure IncomingDocumentDateOnChange(Item)
	
	If IncomingDocumentDate <> Object.IncomingDocumentDate Then
		DatesChangeProcessing();
	EndIf;
	
EndProcedure

#EndRegion

#Region Service

&AtServerNoContext
Function ContractCashFlowItem(Contract)
	
	CashFlowItem = Common.ObjectAttributeValue(Contract, "CashFlowItem");
	If Not ValueIsFilled(CashFlowItem) Then
		CashFlowItem = Catalogs.CashFlowItems.PaymentToVendor;
	EndIf;
	
	Return CashFlowItem;
	
EndFunction

&AtServer
Procedure CheckVATNumberAtServer()
	
	VATNumber = Common.ObjectAttributeValue(Object.Counterparty, "VATNumber");
	
	If ValueIsFilled(VATNumber) Then
		
		VIESStructure 		= WorkWithVIESServer.VATCheckingResult(VATNumber);
		VIESClientAddress	= VIESStructure.VIESClientAddress;
		VIESClientName		= VIESStructure.VIESClientName;
		VIESQueryDate		= VIESStructure.VIESQueryDate;
		VIESValidationState	= VIESStructure.VIESValidationState;
		WorkWithVIESServer.SetGroupVATState(Items.GroupVATState, VIESValidationState);
		
		WorkWithVIESServer.WriteVIESValidationResult(ThisObject, Object.Counterparty);
		
	Else
		
		WorkWithVIESServer.SetEmptyState(ThisObject);
		CommonClientServer.MessageToUser(NStr("en = 'VAT ID is not filled'; ru = 'Номер плательщика НДС не заполнен';pl = 'Nie wypełniono numeru VAT';es_ES = 'No se ha rellenado el identificador del IVA';es_CO = 'No se ha rellenado el identificador del IVA';tr = 'KDV kodu doldurulmadı';it = 'L''Id IVA non è compilato';de = 'USt.- IdNr. ist nicht ausgefüllt'"));
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

&AtClient
Procedure GenerateLabelPricesAndCurrency()
	
	LabelStructure = New Structure;
	LabelStructure.Insert("SupplierPriceTypes",			Object.SupplierPriceTypes);
	LabelStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",		SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate",				Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",			Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",		RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",				Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",			RegisteredForVAT);
	LabelStructure.Insert("SupplierDiscountKind",		Object.DiscountType);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

&AtServer
Procedure CounterpartyOnChangeFragmentServer(StructureData)
	
	FillVATValidationAttributes();
	
	If UseCrossReferences Then
		
		StructureCrossReference = New Structure("Counterparty", Object.Counterparty);
			
		For Each LineInventory In Object.Inventory Do
			
			StructureCrossReference.Insert("Products", LineInventory.Products);
			StructureCrossReference.Insert("Characteristic", LineInventory.Characteristic);
				
			Catalogs.SuppliersProducts.FindCrossReferenceByParameters(StructureCrossReference);
			
			LineInventory.CrossReference = StructureCrossReference.CrossReference;
			
		EndDo;
		
		For Each LineExpenses In Object.Expenses Do
			
			StructureCrossReference.Insert("Products", LineExpenses.Products);
			
			Catalogs.SuppliersProducts.FindCrossReferenceByParameters(StructureCrossReference);
			
			LineExpenses.CrossReference = StructureCrossReference.CrossReference;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillVATValidationAttributes()
	
	If GetFunctionalOption("UseVIESVATNumberValidation") Then
		WorkWithVIESServer.FillVATValidationAttributes(ThisObject, Object.Counterparty);
	EndIf;
	
EndProcedure

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	False);
	ParametersStructure.Insert("FillHeader",	True);
	ParametersStructure.Insert("FillInventory",	True);
	ParametersStructure.Insert("FillExpenses",	True);
	ParametersStructure.Insert("FillMaterials",	True);
	
	FillAddedColumns(ParametersStructure);
	
	SetVATTaxationDependantItemsVisibility();
	
	SetContractVisible();
	
	SetSwitchTypeListOfPaymentCalendar();
	
EndProcedure

// Procedure clears the document basis by communication: counterparty, contract.
//
&AtClient
Procedure ClearBasisOnChangeCounterpartyContract()
	
	Object.BasisDocument = Undefined;
	
EndProcedure

// Procedure fills the column "Payment sum", etc. Inventory.
//
&AtServer
Procedure DistributeTabSectExpensesByQuantity()
	
	Document = FormAttributeToValue("Object");
	Document.DistributeTabSectExpensesByQuantity();
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	False);
	ParametersStructure.Insert("FillHeader",	False);
	ParametersStructure.Insert("FillInventory",	True);
	ParametersStructure.Insert("FillExpenses",	True);
	ParametersStructure.Insert("FillMaterials",	True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

// Procedure fills the column "Payment sum", etc. Inventory.
//
&AtServer
Procedure DistributeTabSectExpensesByAmount()
	
	Document = FormAttributeToValue("Object");
	Document.DistributeTabSectExpensesByAmount();
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	False);
	ParametersStructure.Insert("FillHeader",	False);
	ParametersStructure.Insert("FillInventory",	True);
	ParametersStructure.Insert("FillExpenses",	True);
	ParametersStructure.Insert("FillMaterials",	True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange();
	
	If ValueIsFilled(SettlementsCurrency) Then
		RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
	EndIf;
	
	GenerateLabelPricesAndCurrency();
	
	DocumentDate = Object.Date;
	
EndProcedure

// It receives data set from server for the DateOnChange procedure.
//
&AtServer
Function GetDataDateOnChange()
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
	
	StructureData = New Structure;
	StructureData.Insert("CurrencyRateRepetition", CurrencyRateRepetition);
	
	If Object.DocumentCurrency <> SettlementsCurrency Then
		
		SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, SettlementsCurrency, Object.Company);
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", SettlementsCurrencyRateRepetition);
		
	Else
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", CurrencyRateRepetition);
		
	EndIf;
	
	SetAccountingPolicyValues();
	
	DatesChangeProcessing();
	EarlyPaymentDiscountsClientServer.ShiftEarlyPaymentDiscountsDates(Object);
	
	ProcessingCompanyVATNumbers();
	
	FillVATRateByCompanyVATTaxation();
	SetAutomaticVATCalculation();
	SetTaxInvoiceText();
	SetVisibleAndEnabled();
	RecalculateSubtotalAtServer();
	
	Return StructureData;
	
EndFunction

// Gets data set from server.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure;
	
	StructureData.Insert("Company", DriveServer.GetCompany(Object.Company));
	StructureData.Insert("ExchangeRateMethod", DriveServer.GetExchangeMethod(Object.Company));
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	True);
	ParametersStructure.Insert("FillHeader",	True);
	ParametersStructure.Insert("FillInventory",	True);
	ParametersStructure.Insert("FillExpenses",	True);
	ParametersStructure.Insert("FillMaterials",	True);
	
	FillAddedColumns(ParametersStructure);
	
	SetAccountingPolicyValues();
	
	ProcessingCompanyVATNumbers(False);
	
	FillVATRateByCompanyVATTaxation();
	SetAutomaticVATCalculation();
	SetVisibleAndEnabled();
	RecalculateSubtotalAtServer();
	
	InformationRegisters.AccountingSourceDocuments.CheckNotifyTypesOfAccountingProblems(
		Object.Ref,
		Object.Company,
		DocumentDate);

	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData, ObjectDate = Undefined)
	
	Catalogs.SuppliersProducts.FindCrossReferenceByParameters(StructureData);
	
	AttributeArray = New Array;
	AttributeArray.Add("MeasurementUnit");
	AttributeArray.Add("VATRate");
	AttributeArray.Add("BusinessLine");
	AttributeArray.Add("ReplenishmentMethod");
	
	If StructureData.UseDefaultTypeOfAccounting Then
		AttributeArray.Add("ExpensesGLAccount.TypeOfAccount");
	EndIf;
	
	ProductData = Common.ObjectAttributesValues(StructureData.Products, StrConcat(AttributeArray, ","));
	
	StructureData.Insert("MeasurementUnit", ProductData.MeasurementUnit);
	
	If ValueIsFilled(ProductData.VATRate) Then
		ProductVATRate = ProductData.VATRate;
	Else
		ProductVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company);
	EndIf;
	
	StructureData.Insert("ReverseChargeVATRate", ProductVATRate);
	
	If Not StructureData.Property("VATTaxation")
		Or StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		StructureData.Insert("VATRate", ProductVATRate);
		
	ElsIf StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		
		StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		
	Else
		
		StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		
	EndIf;
	
	If Not ObjectDate = Undefined Then
		
		Specification = Undefined;
		
		If ProductData.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Assembly);
		ElsIf ProductData.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Production);
		EndIf;
		StructureData.Insert("Specification", Specification);
		
	EndIf;
	
	If StructureData.Property("SupplierPriceTypes") Then
		
		Price = DriveServer.GetPriceProductsBySupplierPriceTypes(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	StructureData.Insert("ClearOrderAndDepartment", False);
	StructureData.Insert("ClearBusinessLine", False);
	StructureData.Insert("BusinessLine", ProductData.BusinessLine);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		If ProductData.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Expenses
			And ProductData.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Revenue
			And ProductData.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.WorkInProgress
			And ProductData.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
			
			StructureData.ClearOrderAndDepartment = True;
		EndIf;
		
		If ProductData.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Expenses
			And ProductData.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.CostOfSales
			And ProductData.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Revenue Then
			
			StructureData.ClearBusinessLine = True;
		EndIf;
		
	EndIf;
	
	If StructureData.Property("DiscountType") Then
		StructureData.Insert("DiscountPercent", Common.ObjectAttributeValue(StructureData.DiscountType, "Percent"));
	Else
		StructureData.Insert("DiscountPercent", 0);
	EndIf;
	
	If StructureData.Property("TabName") And StructureData.TabName = "Expenses" Then
		IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	EndIf;
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData, ObjectDate = Undefined)
	
	Catalogs.SuppliersProducts.FindCrossReferenceByParameters(StructureData);
	
	If StructureData.Property("SupplierPriceTypes") Then
		
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
			StructureData.Insert("Factor", 1);
		Else
			StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
		EndIf;		
		
		Price = DriveServer.GetPriceProductsBySupplierPriceTypes(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
				
	EndIf;
	
	If Not ObjectDate = Undefined Then
		
		Specification = Undefined;
		EnumReplenishmentMethod = Common.ObjectAttributeValue(StructureData.Products, "ReplenishmentMethod");
		
		If EnumReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Assembly);
		ElsIf EnumReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Production);
		EndIf;
		StructureData.Insert("Specification", Specification);
		
	EndIf;
		
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataCrossReferenceOnChange(StructureData)
	
	AttributeArray = New Array;
	AttributeArray.Add("Products");
	AttributeArray.Add("Characteristic");
	AttributeArray.Add("Products.MeasurementUnit");
	AttributeArray.Add("Products.VATRate");
	AttributeArray.Add("Products.BusinessLine");
	
	If StructureData.UseDefaultTypeOfAccounting Then
		AttributeArray.Add("Products.ExpensesGLAccount.TypeOfAccount");
	EndIf;
	
	CrossReferenceData = Common.ObjectAttributesValues(StructureData.CrossReference, AttributeArray);
	
	If CrossReferenceData.Products = Undefined Then
		StructureData.Insert("Products", Catalogs.Products.EmptyRef());
	Else
		StructureData.Insert("Products", CrossReferenceData.Products);
	EndIf;
	
	StructureData.Insert("Characteristic", CrossReferenceData.Characteristic);
	StructureData.Insert("MeasurementUnit", CrossReferenceData.ProductsMeasurementUnit);
	
	If ValueIsFilled(CrossReferenceData.ProductsVATRate) Then
		ProductVATRate = CrossReferenceData.ProductsVATRate;
	Else
		ProductVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company);
	EndIf;
	
	StructureData.Insert("ReverseChargeVATRate", ProductVATRate);
	
	If Not StructureData.Property("VATTaxation")
		Or StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		StructureData.Insert("VATRate", ProductVATRate);
		
	ElsIf StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		
		StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		
	Else
		
		StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		
	EndIf;
	
	If StructureData.Property("SupplierPriceTypes") Then
		
		Price = DriveServer.GetPriceProductsBySupplierPriceTypes(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	StructureData.Insert("ClearOrderAndDepartment", False);
	StructureData.Insert("ClearBusinessLine", False);
	StructureData.Insert("BusinessLine", CrossReferenceData.ProductsBusinessLine);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		If CrossReferenceData.ProductsExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Expenses
			And CrossReferenceData.ProductsExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Revenue
			And CrossReferenceData.ProductsExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.WorkInProgress
			And CrossReferenceData.ProductsExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
			
			StructureData.ClearOrderAndDepartment = True;
		EndIf;
		
		If CrossReferenceData.ProductsExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Expenses
			And CrossReferenceData.ProductsExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.CostOfSales
			And CrossReferenceData.ProductsExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Revenue Then
			
			StructureData.ClearBusinessLine = True;
		EndIf;
		
	EndIf;
	
	If StructureData.Property("DiscountType") Then
		StructureData.Insert("DiscountPercent", Common.ObjectAttributeValue(StructureData.DiscountType, "Percent"));
	Else
		StructureData.Insert("DiscountPercent", 0);
	EndIf;
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure;
	
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

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataBusinessLineStartChoice(ExpenseItem)
	
	StructureData = New Structure;
	
	AvailabilityOfPointingLinesOfBusiness = True;
	
	If ExpenseItem.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses
		And ExpenseItem.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.CostOfSales Then
		
		AvailabilityOfPointingLinesOfBusiness = False;
	EndIf;
	
	StructureData.Insert("AvailabilityOfPointingLinesOfBusiness", AvailabilityOfPointingLinesOfBusiness);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataBusinessUnitstartChoice(ExpenseItem)
	
	StructureData = New Structure;
	
	AbilityToSpecifyDepartments = True;
	
	If ExpenseItem.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses
		And ExpenseItem.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.ManufacturingOverheads Then
		
		AbilityToSpecifyDepartments = False;
	EndIf;
	
	StructureData.Insert("AbilityToSpecifyDepartments", AbilityToSpecifyDepartments);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataOrderStartChoice(ExpenseItem)
	
	StructureData = New Structure;
	
	AbilityToSpecifyOrder = True;
	
	If ExpenseItem.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses
		And ExpenseItem.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.ManufacturingOverheads Then
		
		AbilityToSpecifyOrder = False;
	EndIf;
	
	StructureData.Insert("AbilityToSpecifyOrder", AbilityToSpecifyOrder);
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	FillVATRateByCompanyVATTaxation(True);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	True);
	ParametersStructure.Insert("FillHeader",	True);
	ParametersStructure.Insert("FillInventory",	False);
	ParametersStructure.Insert("FillExpenses",	False);
	ParametersStructure.Insert("FillMaterials",	False);
	
	FillAddedColumns(ParametersStructure);
	
	SetContractVisible();
	
	Return DriveServer.GetDataCounterpartyOnChange(Object.Ref, Date, Counterparty, Company);
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	True);
	ParametersStructure.Insert("FillHeader",	True);
	ParametersStructure.Insert("FillInventory",	False);
	ParametersStructure.Insert("FillExpenses",	False);
	ParametersStructure.Insert("FillMaterials",	False);
	
	FillAddedColumns(ParametersStructure);
	
	Return DriveServer.GetDataContractOnChange(Date, DocumentCurrency, Contract, Object.Company);
	
EndFunction

// Procedure fills VAT Rate in tabular section
// by company taxation system.
// 
&AtServer
Procedure FillVATRateByCompanyVATTaxation(IsCounterpartyOnChange = False)
	
	If Not WorkWithVAT.VATTaxationTypeIsValid(Object.VATTaxation, RegisteredForVAT, False)
		Or IsCounterpartyOnChange Then
		
		TaxationBeforeChange = Object.VATTaxation;
		
		Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty,
			DriveServer.VATTaxation(Object.Company, Object.Date),
			False);
		
		If Not TaxationBeforeChange = Object.VATTaxation Then
			
			FillVATRateByVATTaxation();
			RecalculateSubtotalAtServer();
			
			If TaxationBeforeChange = Enums.VATTaxationTypes.SubjectToVAT
				And Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
				
				MessageText = NStr("en = 'On %1, company %2 is not registered for VAT. The Tax category was changed from ""%3"" to ""%4"".'; ru = 'На %1 в организации %2 не ведется учет НДС. Налогообложение было изменено с ""%3"" на ""%4"".';pl = 'W %1, firma %2 jest zarejestrowana jako płatnik VAT. Kategoria opodatkowania została zmieniona z ""%3"" na ""%4"".';es_ES = 'En %1, la empresa %2 no está registrada para el IVA. La categoría fiscal se ha cambiado de ""%3"" a ""%4"".';es_CO = 'En %1, la empresa %2 no está registrada para el IVA. La categoría fiscal se ha cambiado de ""%3"" a ""%4"".';tr = '%1 alanında, %2 iş yeri KDV''ye kayıtlı değil. Vergi kategorisi ""%3"" değerinden ""%4"" değerine değiştirildi.';it = 'Su %1, l''azienda %2 non è registrata per l''IVA. La categoria fiscale è stata modificata da ""%3"" a ""%4"".';de = 'Auf %1, ist die Firma %2 für USt. nicht angemeldet. Die Steuerkategorie wurde von ""%3"" auf ""%4"" geändert.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					MessageText,
					Format(Object.Date, "DLF=D"),
					Object.Company,
					TaxationBeforeChange,
					Object.VATTaxation);
				CommonClientServer.MessageToUser(MessageText);
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
&AtServer
Procedure FillVATRateByVATTaxation()
	
	SetVATTaxationDependantItemsVisibility();
	
	DefaultVATRate = Undefined;
	DefaultVATRateIsRead = False;
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		For Each TabularSectionRow In Object.Inventory Do
			
			ProductVATRate = Common.ObjectAttributeValue(TabularSectionRow.Products, "VATRate");
			
			If ValueIsFilled(ProductVATRate) Then
				TabularSectionRow.VATRate = ProductVATRate;
			Else
				If Not DefaultVATRateIsRead Then
					DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
					DefaultVATRateIsRead = True;
				EndIf;
				TabularSectionRow.VATRate = DefaultVATRate;
			EndIf;
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT,
											TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
											TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
		For Each TabularSectionRow In Object.Expenses Do
			
			ProductVATRate = Common.ObjectAttributeValue(TabularSectionRow.Products, "VATRate");
			
			If ValueIsFilled(ProductVATRate) Then
				TabularSectionRow.VATRate = ProductVATRate;
			Else
				If Not DefaultVATRateIsRead Then
					DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
					DefaultVATRateIsRead = True;
				EndIf;
				TabularSectionRow.VATRate = DefaultVATRate;
			EndIf;
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT,
											TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
											TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
	Else
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			VATRateByTaxation = Catalogs.VATRates.Exempt;
		Else
			VATRateByTaxation = Catalogs.VATRates.ZeroRate;
		EndIf;
		
		IsReverseChargeVATTaxation = Object.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.ForExport Then
			Object.OperationKind = Enums.OperationTypesSupplierInvoice.AdvanceInvoice;
		EndIf;
		
		For Each TabularSectionRow In Object.Inventory Do
		
			TabularSectionRow.VATRate = VATRateByTaxation;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
			If IsReverseChargeVATTaxation Then
				
				ProductVATRate = Common.ObjectAttributeValue(TabularSectionRow.Products, "VATRate");
				
				If ValueIsFilled(ProductVATRate) Then
					TabularSectionRow.ReverseChargeVATRate = ProductVATRate;
				Else
					If Not DefaultVATRateIsRead Then
						DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
						DefaultVATRateIsRead = True;
					EndIf;
					TabularSectionRow.ReverseChargeVATRate = DefaultVATRate;
				EndIf;
				
				VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.ReverseChargeVATRate);
				TabularSectionRow.ReverseChargeVATAmount = TabularSectionRow.Total * VATRate / 100;
				
			EndIf;
			
		EndDo;
		
		For Each TabularSectionRow In Object.Expenses Do
			
			TabularSectionRow.VATRate = VATRateByTaxation;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
			If IsReverseChargeVATTaxation Then
				
				ProductVATRate = Common.ObjectAttributeValue(TabularSectionRow.Products, "VATRate");
				
				If ValueIsFilled(ProductVATRate) Then
					TabularSectionRow.ReverseChargeVATRate = ProductVATRate;
				Else
					If Not DefaultVATRateIsRead Then
						DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
						DefaultVATRateIsRead = True;
					EndIf;
					TabularSectionRow.ReverseChargeVATRate = DefaultVATRate;
				EndIf;
				
				VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.ReverseChargeVATRate);
				TabularSectionRow.ReverseChargeVATAmount = TabularSectionRow.Total * VATRate / 100;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
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

&AtClient
Procedure CalculateReverseChargeVATAmount(TabularSectionRow)
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ReverseChargeVAT") Then
		
		If TabularSectionRow.Property("AmountExpense") Then
		
			If Object.IncludeExpensesInCostPrice Then
				
				VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.ReverseChargeVATRate);
				TabularSectionRow.ReverseChargeVATAmount = (TabularSectionRow.Total + TabularSectionRow.AmountExpense) * VATRate / 100;
				
			Else
				
				VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.ReverseChargeVATRate);
				TabularSectionRow.ReverseChargeVATAmount = TabularSectionRow.Total * VATRate / 100;
				
			EndIf;
			
		Else
			
			If Object.IncludeExpensesInCostPrice Then
				
				TabularSectionRow.ReverseChargeVATAmount = 0;
				
			Else
				
				VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.ReverseChargeVATRate);
				TabularSectionRow.ReverseChargeVATAmount = TabularSectionRow.Total * VATRate / 100;
				
			EndIf;
			
		EndIf;
		
	Else
		
		TabularSectionRow.ReverseChargeVATAmount = 0;
		
	EndIf;
	
EndProcedure

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionName, TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items[TabularSectionName].CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	If TabularSectionName = "Inventory" Or TabularSectionName = "Expenses" Then
		TabularSectionRow.DiscountAmount = TabularSectionRow.DiscountPercent * TabularSectionRow.Amount / 100;
		TabularSectionRow.Amount = TabularSectionRow.Amount - TabularSectionRow.DiscountAmount;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
	RefillDiscountAmountOfEPD();
	
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined AND TabularSectionName="Inventory" Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow);
	EndIf;
	
EndProcedure

// Recalculates the exchange rate and exchange rate multiplier of
// the payment currency when the document date is changed.
//
&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	CurrencyRateRepetition = StructureData.CurrencyRateRepetition;
	SettlementsCurrencyRateRepetition = StructureData.SettlementsCurrencyRateRepetition;
	
	NewExchangeRate	= ?(CurrencyRateRepetition.Rate = 0, 1, CurrencyRateRepetition.Rate);
	NewRatio		= ?(CurrencyRateRepetition.Repetition = 0, 1, CurrencyRateRepetition.Repetition);
	
	NewContractCurrencyExchangeRate = ?(SettlementsCurrencyRateRepetition.Rate = 0,
		1,
		SettlementsCurrencyRateRepetition.Rate);
	
	NewContractCurrencyRatio = ?(SettlementsCurrencyRateRepetition.Repetition = 0,
		1,
		SettlementsCurrencyRateRepetition.Repetition);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio
		OR Object.ContractCurrencyExchangeRate <> NewContractCurrencyExchangeRate
		OR Object.ContractCurrencyMultiplicity <> NewContractCurrencyRatio Then
		
		QuestionText = MessagesToUserClientServer.GetApplyRatesOnNewDateQuestionText();
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewExchangeRate",					NewExchangeRate);
		AdditionalParameters.Insert("NewRatio",							NewRatio);
		AdditionalParameters.Insert("NewContractCurrencyExchangeRate",	NewContractCurrencyExchangeRate);
		AdditionalParameters.Insert("NewContractCurrencyRatio",			NewContractCurrencyRatio);
		
		NotifyDescription = New NotifyDescription("RecalculatePaymentCurrencyRateConversionFactorEnd", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		Return;
		
	EndIf;
	
	RecalculatePaymentCurrencyRateConversionFactorFragment();
	
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
	
	RecalculatePaymentCurrencyRateConversionFactorFragment();
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorFragment()
	
	// Generate price and currency label.
	GenerateLabelPricesAndCurrency();
	
EndProcedure

// Procedure executes recalculate in the document tabular section
// after changes in "Prices and currency" form.Column recalculation is executed:
// price, discount, amount, VAT amount, total.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange = Undefined, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	If AttributesBeforeChange = Undefined Then
		AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
			Object.DocumentCurrency,
			Object.ExchangeRate,
			Object.Multiplicity);
	EndIf;
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",					Object.Multiplicity);
	ParametersStructure.Insert("Counterparty",					Object.Counterparty);
	ParametersStructure.Insert("Contract",						Object.Contract);
	ParametersStructure.Insert("ContractCurrencyExchangeRate",	Object.ContractCurrencyExchangeRate);
	ParametersStructure.Insert("ContractCurrencyMultiplicity",	Object.ContractCurrencyMultiplicity);
	ParametersStructure.Insert("Company",						Company);
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("RefillPrices",					RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",				RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",				False);
	ParametersStructure.Insert("SupplierPriceTypes", 			Object.SupplierPriceTypes);
	ParametersStructure.Insert("RegisterVendorPrices",			Object.RegisterVendorPrices);
	ParametersStructure.Insert("WarningText",					WarningText);
	ParametersStructure.Insert("SupplierDiscountKind",			Object.DiscountType);
	ParametersStructure.Insert("OperationKind",					Object.OperationKind);
	
	If Not RegisteredForSalesTax Then
		
		ParametersStructure.Insert("VATTaxation",					Object.VATTaxation);
		ParametersStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		ParametersStructure.Insert("IncludeVATInPrice",				Object.IncludeVATInPrice);
		ParametersStructure.Insert("AutomaticVATCalculation",		Object.AutomaticVATCalculation);
		ParametersStructure.Insert("PerInvoiceVATRoundingRule",		PerInvoiceVATRoundingRule);
		ParametersStructure.Insert("ReverseChargeVATIsCalculated",	True);
		
	EndIf;
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, AttributesBeforeChange);
	
	OpenForm("CommonForm.PricesAndCurrency",
		ParametersStructure,
		ThisObject, , , ,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure recalculates subtotal the document on client.
&AtClient
Procedure RecalculateSubtotal()
	
	TotalsResult = CalculateSubtotals(Object.Inventory, Object.Expenses, Object.AmountIncludesVAT);
	InventoryTotals = TotalsResult[0];
	ExpensesTotals = TotalsResult[1];
	
	FillPropertyValues(ThisObject, InventoryTotals);
	DocumentSubtotal = DocumentSubtotal + ExpensesTotals.DocumentSubtotal;
	DocumentTax = DocumentTax + ExpensesTotals.DocumentTax;
	DocumentAmount = DocumentAmount + ExpensesTotals.DocumentAmount;
	DocumentDiscount = DocumentDiscount + ExpensesTotals.DocumentDiscount;
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ReverseChargeVAT") Then
		TotalReverseChargeVATAmount = Object.Inventory.Total("ReverseChargeVATAmount");
		If Not Object.IncludeExpensesInCostPrice Then
			TotalReverseChargeVATAmount = TotalReverseChargeVATAmount + Object.Expenses.Total("ReverseChargeVATAmount");
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure RecalculateSubtotalAtServer()
	
	InventoryTotals = DriveServer.CalculateSubtotalPurchases(Object.Inventory.Unload(), Object.AmountIncludesVAT);
	ExpensesTotals = DriveServer.CalculateSubtotalPurchases(Object.Expenses.Unload(), Object.AmountIncludesVAT);
	
	FillPropertyValues(ThisObject, InventoryTotals);
	DocumentSubtotal = DocumentSubtotal + ExpensesTotals.DocumentSubtotal;
	DocumentTax = DocumentTax + ExpensesTotals.DocumentTax;
	DocumentAmount = DocumentAmount + ExpensesTotals.DocumentAmount;
	
	If Object.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		TotalReverseChargeVATAmount = Object.Inventory.Total("ReverseChargeVATAmount");
		If Not Object.IncludeExpensesInCostPrice Then
			TotalReverseChargeVATAmount = TotalReverseChargeVATAmount + Object.Expenses.Total("ReverseChargeVATAmount");
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CalculateSubtotals(Val TabularSectionInventory, Val TabularSectionExpenses, AmountIncludesVAT)
	
	Result = New Array;
	Result.Add(DriveServer.CalculateSubtotalPurchases(TabularSectionInventory.Unload(), AmountIncludesVAT));
	Result.Add(DriveServer.CalculateSubtotalPurchases(TabularSectionExpenses.Unload(), AmountIncludesVAT));
	
	Return Result;
	
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
		
		If BarcodeData <> Undefined 
			And BarcodeData.Count() <> 0 Then
			
			StructureProductsData = New Structure();
			StructureProductsData.Insert("Company", StructureData.Company);
			StructureProductsData.Insert("Counterparty", StructureData.Counterparty);
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsData.Insert("VATTaxation", StructureData.VATTaxation);
			StructureProductsData.Insert("Object", StructureData.Object);
			StructureProductsData.Insert("TabName", StructureData.TabName);
			StructureProductsData.Insert("GoodsReceipt", Undefined);
			StructureProductsData.Insert("UseDefaultTypeOfAccounting", StructureData.UseDefaultTypeOfAccounting);
			
			If ValueIsFilled(StructureData.SupplierPriceTypes) Then
				StructureProductsData.Insert("ProcessingDate", StructureData.Date);
				StructureProductsData.Insert("DocumentCurrency", StructureData.DocumentCurrency);
				StructureProductsData.Insert("AmountIncludesVAT", StructureData.AmountIncludesVAT);
				StructureProductsData.Insert("SupplierPriceTypes", StructureData.SupplierPriceTypes);
				StructureProductsData.Insert("DiscountType", StructureData.DiscountType);
				
				If ValueIsFilled(BarcodeData.MeasurementUnit)
					And TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
					StructureProductsData.Insert("Factor", BarcodeData.MeasurementUnit.Factor);
				Else
					StructureProductsData.Insert("Factor", 1);
				EndIf;
				
			EndIf;
			
			If StructureData.UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(StructureProductsData, StructureData.Object, "SupplierInvoice");
			EndIf;
			
			BarcodeData.Insert("StructureProductsData", GetDataProductsOnChange(StructureProductsData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit = BarcodeData.Products.MeasurementUnit;
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
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Counterparty", Object.Counterparty);
	StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("Object", Object);
	StructureData.Insert("DiscountType", Object.DiscountType);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,Batch,MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsData.Price;
				NewRow.VATRate = BarcodeData.StructureProductsData.VATRate;
				NewRow.DiscountPercent = BarcodeData.StructureProductsData.DiscountPercent;
				CalculateAmountInTabularSectionLine("Inventory", NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine("Inventory", NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			EndIf;
			
			If BarcodeData.Property("SerialNumber") AND ValueIsFilled(BarcodeData.SerialNumber) Then
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object);
			EndIf;
			
			Modified = True;
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;
	
EndFunction

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisObject, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisObject,,,,Notification
		);
		
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
		
		MessageString = NStr("en = 'Barcode data is not found: %1%; quantity: %2%'; ru = 'Данные по штрихкоду не найдены: %1%; количество: %2%';pl = 'Nie znaleziono danych kodu kreskowego: %1%; ilość: %2%';es_ES = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';es_CO = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';tr = 'Barkod verisi bulunamadı: %1%; miktar: %2%';it = 'Il codice a barre non è stato trovato: %1%; quantità: %2%';de = 'Barcode-Daten wurden nicht gefunden: %1%; Menge: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

// End Peripherals

// Procedure sets the contract visible depending on the parameter set to the counterparty.
//
&AtServer
Procedure SetContractVisible()
	
	CounterpartyDoSettlementsByOrders = CounterpartyAttributes.DoOperationsByOrders;
	Items.Contract.Visible = CounterpartyAttributes.DoOperationsByContracts;
	
EndProcedure

// Procedure sets the cross-reference visible.
//
&AtClient
Procedure SetCrossReferenceVisible(IsCounterpartyChanged = False)
	
	VisibleRegularInvoice = True;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.ZeroInvoice") Then
		
		VisibleRegularInvoice = False;
		
	EndIf;
	
	IsCrossReferenceVisible = VisibleRegularInvoice And UseCrossReferences;
	
	If IsCrossReferenceVisible 
		And IsCounterpartyChanged Then
		
		FillCrossReference(IsCounterpartyChanged);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillCrossReference(IsCounterpartyChanged)
	
	For Each LineInventory In Object.Inventory Do
		
		If ValueIsFilled(LineInventory.CrossReference) 
			And Not IsCounterpartyChanged Then
			
			Return;
			
		EndIf;
		
		StructureInventory = New Structure("Counterparty, Products, Characteristic",
			Counterparty,
			LineInventory.Products,
			LineInventory.Characteristic);
		
		GetCrossReferenceToStructure(StructureInventory);
		
		LineInventory.CrossReference = StructureInventory.CrossReference;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure GetCrossReferenceToStructure(StructureInventory)
	
	Catalogs.SuppliersProducts.FindCrossReferenceByParameters(StructureInventory);
	
EndProcedure

// Checks the match of the "Company" and "ContractKind" contract attributes to the terms of the document.
//
&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText, Contract, Document, Company, Counterparty, Cancel, IsOperationsByContracts)
	
	If Not DriveReUse.CounterpartyContractsControlNeeded()
		OR Not IsOperationsByContracts Then
		
		Return;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractKindsList = ManagerOfCatalog.GetContractTypesListForDocument(Document);
	
	If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList)
		AND Constants.CheckContractsOnPosting.Get() Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract, IsOperationsByContracts)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", IsOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

// Gets the default contract depending on the billing details.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company);
	
EndFunction

// Performs actions when counterparty contract is changed.
//
&AtClient
Procedure ProcessContractChange()
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		ClearBasisOnChangeCounterpartyContract();
		
		If Object.Prepayment.Count() > 0
		   AND Object.Contract <> ContractBeforeChange Then
			
			ShowQueryBox(New NotifyDescription("ProcessContractChangeEnd", ThisObject, New Structure("ContractBeforeChange", ContractBeforeChange)),
				NStr("en = 'Prepayment setoff will be cleared, continue?'; ru = 'Зачет аванса будет очищен, продолжить?';pl = 'Zaliczenie płatności będzie anulowane, kontynuować?';es_ES = 'Compensación del prepago se liquidará, ¿continuar?';es_CO = 'Compensación del prepago se liquidará, ¿continuar?';tr = 'Ön ödeme mahsuplaştırılması silinecek, devam mı?';it = 'Pagamento anticipato compensazione verrà cancellata, continuare?';de = 'Anzahlungsverrechnung wird gelöscht, fortsetzen?'"),
				QuestionDialogMode.YesNo
			);
			Return;
			
		EndIf;
		
		ProcessContractChangeFragment(ContractBeforeChange);
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
		FillEarlyPaymentDiscounts();
		SetVisibleEnablePaymentTermItems();
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		Order = Object.Order;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessContractChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Object.Prepayment.Clear();
	Else
		Object.Contract = AdditionalParameters.ContractBeforeChange;
		Contract = AdditionalParameters.ContractBeforeChange;
		Object.Order = Order;
		Return;
	EndIf;
	
	ProcessContractChangeFragment(AdditionalParameters.ContractBeforeChange);
	
EndProcedure

&AtClient
Procedure ProcessContractChangeFragment(ContractBeforeChange, StructureData = Undefined)
	
	If StructureData = Undefined Then
		StructureData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
	EndIf;
	
	SettlementsCurrency = StructureData.SettlementsCurrency;
	
	If Not StructureData.AmountIncludesVAT = Undefined Then
		Object.AmountIncludesVAT = StructureData.AmountIncludesVAT;
	EndIf;
	
	AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
		Object.DocumentCurrency,
		Object.ExchangeRate,
		Object.Multiplicity);
	
	If ValueIsFilled(Object.Contract) Then 
		Object.ExchangeRate = ?(StructureData.SettlementsCurrencyRateRepetition.Rate = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Rate);
		Object.Multiplicity = ?(StructureData.SettlementsCurrencyRateRepetition.Repetition = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Repetition);
		Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
		Object.ContractCurrencyMultiplicity = Object.Multiplicity;
	EndIf;
	
	PriceKindChanged = Object.SupplierPriceTypes <> StructureData.SupplierPriceTypes
		And ValueIsFilled(StructureData.SupplierPriceTypes);
	ModifiedDiscountType = Object.DiscountType <> StructureData.DiscountType;
	OpenFormPricesAndCurrencies = ValueIsFilled(Object.Contract)
		And Object.Contract <> ContractBeforeChange
		And ValueIsFilled(SettlementsCurrency)
		And Object.DocumentCurrency <> SettlementsCurrency
		And (Object.Inventory.Count() > 0 Or Object.Expenses.Count() > 0);
	
	StructureData.Insert("PriceKindChanged", PriceKindChanged);
	
	If PriceKindChanged Then
		Object.SupplierPriceTypes = StructureData.SupplierPriceTypes;
	EndIf;
	
	If ModifiedDiscountType Then
		Object.DiscountType = StructureData.DiscountType;
	EndIf;
	
	// If the contract has changed and the kind of counterparty prices is selected, automatically register incoming prices
	Object.RegisterVendorPrices = StructureData.PriceKindChanged AND Not Object.SupplierPriceTypes.IsEmpty();
	Order = Object.Order;
	
	If ValueIsFilled(SettlementsCurrency) Then
		Object.DocumentCurrency = SettlementsCurrency;
		SetPrepaymentColumnsProperties();
	EndIf;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		
		If PriceKindChanged Then
			WarningText = MessagesToUserClientServer.GetPriceTypeOnChangeWarningText();
		EndIf;
		
		WarningText = WarningText
			+ ?(IsBlankString(WarningText), "", Chars.LF + Chars.LF)
			+ MessagesToUserClientServer.GetSettleCurrencyOnChangeWarningText();
		
		ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, True, PriceKindChanged, WarningText);
		
	ElsIf ValueIsFilled(Object.Contract) 
		AND (PriceKindChanged Or ModifiedDiscountType) Then
		
		RecalculationRequired = (Object.Inventory.Count() > 0);
		
		Object.SupplierPriceTypes = StructureData.SupplierPriceTypes;
		
		GenerateLabelPricesAndCurrency();
		
		If RecalculationRequired Then
			
			Message = MessagesToUserClientServer.GetDiscountOnChangeText();
			NotifyDescription = New NotifyDescription("ProcessContractChangeFragmentEnd", ThisObject);
			ShowQueryBox(NotifyDescription, Message, QuestionDialogMode.YesNo);
			
			Return;
			
		EndIf;
		
	Else
		
		GenerateLabelPricesAndCurrency();
		
	EndIf;
	
	If ContractBeforeChange <> Object.Contract Then
		FillEarlyPaymentDiscounts();
		SetVisibleEarlyPaymentDiscounts();
	EndIf;
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure ProcessContractChangeFragmentEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		DriveClient.RefillTabularSectionPricesBySupplierPriceTypes(ThisObject, "Inventory", True);
		RecalculateSubtotal();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Object.Date, Object.Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	RegisteredForSalesTax = AccountingPolicy.RegisteredForSalesTax;
	UseGoodsReturnToSupplier = AccountingPolicy.UseGoodsReturnToSupplier;
	PerInvoiceVATRoundingRule = AccountingPolicy.PerInvoiceVATRoundingRule;
	
EndProcedure

&AtServer
Procedure SetAutomaticVATCalculation()
	
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
	
EndProcedure

&AtClientAtServerNoContext
Procedure AddGLAccountsToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("Object", Form.Object);
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("ProductGLAccounts", StructureData.UseDefaultTypeOfAccounting);
	
	If StructureData.TabName = "Inventory" Then
		StructureData.Insert("GoodsReceipt", TabRow.GoodsReceipt);
	EndIf;
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts", TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled", TabRow.GLAccountsFilled);
		
		If StructureData.TabName = "Inventory" Then
			StructureData.Insert("GoodsReceivedNotInvoicedGLAccount", TabRow.GoodsReceivedNotInvoicedGLAccount);
			StructureData.Insert("GoodsInvoicedNotDeliveredGLAccount", TabRow.GoodsInvoicedNotDeliveredGLAccount);
		EndIf;
		
		StructureData.Insert("InventoryGLAccount", TabRow.InventoryGLAccount);
		
		If StructureData.TabName = "Materials" Then 
			StructureData.Insert("InventoryTransferredGLAccount", TabRow.InventoryTransferredGLAccount);
		Else
			StructureData.Insert("VATInputGLAccount", TabRow.VATInputGLAccount);
			StructureData.Insert("VATOutputGLAccount", TabRow.VATOutputGLAccount);
		EndIf;
		
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
		
		If ParametersStructure.FillInventory Then
			
			StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Inventory");
			GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Inventory");
			StructureArray.Add(StructureData);
			
		EndIf;
		
		If ParametersStructure.FillMaterials Then
			
			StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Materials");
			GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Materials");
			StructureArray.Add(StructureData);
			
		EndIf;
		
	EndIf;
	
	If ParametersStructure.FillExpenses Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Expenses");
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Expenses");
		StructureArray.Add(StructureData);
		
	EndIf;
	
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
	If UseDefaultTypeOfAccounting
		And ParametersStructure.FillHeader Then
		GLAccounts = Header.GLAccounts;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByBillsOfMaterialsAtServer()
	
	Document = FormAttributeToValue("Object");
	NodesBillsOfMaterialstack = New Array;
	Document.FillTabularSectionBySpecification(NodesBillsOfMaterialstack);
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	False);
	ParametersStructure.Insert("FillHeader",	False);
	ParametersStructure.Insert("FillInventory",	True);
	ParametersStructure.Insert("FillExpenses",	True);
	ParametersStructure.Insert("FillMaterials",	False);
	
	FillAddedColumns(ParametersStructure);
	
	ParametersStructure.Insert("GetGLAccounts",	True);
	ParametersStructure.Insert("FillHeader",	False);
	ParametersStructure.Insert("FillInventory",	False);
	ParametersStructure.Insert("FillExpenses",	False);
	ParametersStructure.Insert("FillMaterials",	True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtServer
Procedure FillByGoodsBalanceAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillTabularSectionByGoodsBalance();
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	False);
	ParametersStructure.Insert("FillHeader",	False);
	ParametersStructure.Insert("FillInventory",	True);
	ParametersStructure.Insert("FillExpenses",	True);
	ParametersStructure.Insert("FillMaterials",	False);
	
	FillAddedColumns(ParametersStructure);
	
	ParametersStructure.Insert("GetGLAccounts",	True);
	ParametersStructure.Insert("FillHeader",	False);
	ParametersStructure.Insert("FillInventory",	False);
	ParametersStructure.Insert("FillExpenses",	False);
	ParametersStructure.Insert("FillMaterials",	True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, DoOperationsByOrders, VATTaxation";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

#EndRegion

#Region WorkWithSelection

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'supplier invoice'; ru = 'инвойс поставщика';pl = 'faktura zakupu';es_ES = 'factura de proveedor';es_CO = 'factura de proveedor';tr = 'satın alma faturası';it = 'fattura del fornitore';de = 'Lieferantenrechnung'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
	SelectionParameters.Insert("Company", Company);
	SelectionParameters.Insert("Counterparty", Counterparty);
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
	DocumentPresentaion	= NStr("en = 'supplier invoice'; ru = 'инвойс поставщика';pl = 'faktura zakupu';es_ES = 'factura de proveedor';es_CO = 'factura de proveedor';tr = 'satın alma faturası';it = 'fattura del fornitore';de = 'Lieferantenrechnung'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
	SelectionParameters.Insert("Company", Company);
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
		
		If TabularSectionName = "Inventory"
			And NewRow.Price = 0
			And ValueIsFilled(Object.SupplierPriceTypes) Then
			
			StructureData = New Structure;
			StructureData.Insert("Company", 			Object.Company);
			StructureData.Insert("Counterparty",		Object.Counterparty);
			StructureData.Insert("Products",			NewRow.Products);
			StructureData.Insert("Characteristic",		NewRow.Characteristic);
			StructureData.Insert("ProcessingDate",		Object.Date);
			StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
			StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
			StructureData.Insert("VATRate",				NewRow.VATRate);
			StructureData.Insert("Price",				NewRow.Price);
			StructureData.Insert("SupplierPriceTypes",	Object.SupplierPriceTypes);
			StructureData.Insert("MeasurementUnit",		NewRow.MeasurementUnit);
			
			StructureData = GetDataCharacteristicOnChange(StructureData);
			StructureData.Property("CrossReference", NewRow.CrossReference);
			NewRow.DiscountPercent = Common.ObjectAttributeValue(Object.DiscountType, "Percent");
			NewRow.Price = StructureData.Price;
			NewRow.Content = "";
			NewRow.Amount = NewRow.Quantity * NewRow.Price;
			NewRow.DiscountAmount = NewRow.DiscountPercent * NewRow.Amount / 100;
			NewRow.Amount = NewRow.Amount - NewRow.DiscountAmount;
			VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
			NewRow.VATAmount = ?(Object.AmountIncludesVAT, 
				NewRow.Amount - (NewRow.Amount) / ((VATRate + 100) / 100),
				NewRow.Amount * VATRate / 100);
			NewRow.Total = NewRow.Amount + ?(Object.AmountIncludesVAT, 0, NewRow.VATAmount);
			
		EndIf;
		
		If TabularSectionName = "Expenses" Then
			ObjectParameters.Insert("ExpenseItem", NewRow.ExpenseItem);
			IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, TabularSectionName);
		EndIf;
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
		EndIf;
		
	EndDo;
	
EndProcedure

// Function places the list of advances into temporary storage and returns the address
//
&AtServer
Function PlacePrepaymentToStorage()
	
	Return PutToTempStorage(
		Object.Prepayment.Unload(,
			"Document,
			|Order,
			|SettlementsAmount,
			|AmountDocCur,
			|ExchangeRate,
			|Multiplicity,
			|PaymentAmount"),
		UUID
	);
	
EndFunction

// Function gets the list of advances from the temporary storage
//
&AtServer
Procedure GetPrepaymentFromStorage(AddressPrepaymentInStorage)
	
	TableForImport = GetFromTempStorage(AddressPrepaymentInStorage);
	Object.Prepayment.Load(TableForImport);
	
EndProcedure

&AtClient
Procedure OrderedProductsSelectionProcessingAtClient(TempStorageInventoryAddress)
	
	OrderedProductsSelectionProcessingAtServer(TempStorageInventoryAddress);
	RefillDiscountAmountOfEPD();
	RecalculateSubtotal();
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure OrderedProductsSelectionProcessingAtServer(TempStorageInventoryAddress)
	
	TablesStructure = GetFromTempStorage(TempStorageInventoryAddress);
	
	InventorySearchStructure = New Structure("Products, Characteristic, Batch, Order, GoodsReceipt");
	ServiceSearchStructure = New Structure("Products, PurchaseOrder");
	
	ZeroRate = Catalogs.VATRates.ZeroRate;
	TablesStructure.Inventory.Columns.GoodsIssue.Name = "GoodsReceipt";
	
	EmptyGR = Documents.GoodsReceipt.EmptyRef();
	EmptyPO = Documents.PurchaseOrder.EmptyRef();
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	For Each InventoryRow In TablesStructure.Inventory Do
		
		If InventoryRow.ProductsTypeInventory Then
			
			FillPropertyValues(InventorySearchStructure, InventoryRow);
			
			If InventoryRow.GoodsReceipt = Undefined Then
				InventorySearchStructure.GoodsReceipt = EmptyGR;
			EndIf;
			
			If InventoryRow.Order = Undefined Then
				InventorySearchStructure.Order = EmptyPO;
			EndIf;
			
			TS_InventoryRows = Object.Inventory.FindRows(InventorySearchStructure);
			For Each TS_InventoryRow In TS_InventoryRows Do
				Object.Inventory.Delete(TS_InventoryRow);
			EndDo;
			
			TS_InventoryRow = Object.Inventory.Add();
			FillPropertyValues(TS_InventoryRow, InventoryRow);
			
			If UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, TS_InventoryRow, "Inventory");
			EndIf;
			
		Else
			
			ServiceSearchStructure.Products = InventoryRow.Products;
			ServiceSearchStructure.PurchaseOrder = InventoryRow.Order;
			
			TS_ServiceRows = Object.Expenses.FindRows(ServiceSearchStructure);
			For Each TS_ServiceRow In TS_ServiceRows Do
				Object.Expenses.Delete(TS_ServiceRow);
			EndDo;
				
			TS_ServiceRow = Object.Expenses.Add();
			FillPropertyValues(TS_ServiceRow, InventoryRow);
			
			TS_ServiceRow.PurchaseOrder = InventoryRow.Order;
			TS_ServiceRow.ReverseChargeVATRate = ZeroRate;
			
			IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, TS_ServiceRow, "Expenses");
			
			If UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, TS_ServiceRow, "Expenses");
			EndIf;
		
		EndIf;
		
	EndDo;
	
	OrdersTable = TablesStructure.Inventory;
	OrdersTable.GroupBy("Order");
	If OrdersTable.Count() > 1 Then
		Object.Order = Undefined;
		Object.PurchaseOrderPosition = Enums.AttributeStationing.InTabularSection;
	ElsIf OrdersTable.Count() = 1 Then
		Object.Order = OrdersTable[0].Order;
		Object.PurchaseOrderPosition = Enums.AttributeStationing.InHeader;
	EndIf;
	
	SetVisibleFromUserSettings();
	
EndProcedure

&AtClient
Procedure SelectOrderedProducts(Command)

	Try
		LockFormDataForEdit();
	Except
		ShowMessageBox(Undefined, BriefErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	SelectionParameters = New Structure(
		"Ref,
		|Company,
		|StructuralUnit,
		|Counterparty,
		|Contract,
		|DocumentCurrency,
		|AmountIncludesVAT,
		|IncludeVATInPrice,
		|VATTaxation,
		|Order");
	FillPropertyValues(SelectionParameters, Object);
	
	SelectionParameters.Insert("TempStorageInventoryAddress", PutInventoryToTempStorage());
	SelectionParameters.Insert("ShowPurchaseOrders", True);
	SelectionParameters.Insert("ShowGoodsIssue", True);

	OpenForm("CommonForm.SelectionFromOrders", SelectionParameters, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Function PutInventoryToTempStorage()
	
	InventoryTable = Object.Inventory.Unload();
	
	InventoryTable.Columns.Add("Reserve", New TypeDescription("Number"));
	InventoryTable.Columns.Add("GoodsIssue", New TypeDescription("DocumentRef.GoodsIssue"));
	InventoryTable.Columns.Add("SalesInvoice", New TypeDescription("DocumentRef.SalesInvoice"));
	
	If ValueIsFilled(Object.Order) Then
		For Each InventoryRow In InventoryTable Do
			If Not ValueIsFilled(InventoryRow.Order) Then
				InventoryRow.Order = Object.Order;
			EndIf;
		EndDo;
	EndIf;
	
	PurOrdInHeader = Object.PurchaseOrderPosition = Enums.AttributeStationing.InHeader;
	
	For Each ExpenseRow In Object.Expenses Do
		
		NewInventoryRow = InventoryTable.Add();
		
		FillPropertyValues(NewInventoryRow, ExpenseRow);
		
		If PurOrdInHeader Then
			NewInventoryRow.Order = Object.Order;
		Else
			NewInventoryRow.Order = ExpenseRow.PurchaseOrder;
		EndIf;
		
	EndDo;
	
	Return PutToTempStorage(InventoryTable);
	
EndFunction

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			CurrentPageInventory	= Items.Pages.CurrentPage = Items.GroupInventory;
			TabularSectionName 		= ?(CurrentPageInventory, "Inventory", "Expenses");
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, CurrentPageInventory, CurrentPageInventory);
			
			RefillDiscountAmountOfEPD();
			
			RecalculateSubtotal();
			
			Modified = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseVariantsSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If ClosingResult.WereMadeChanges And Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			TabularSectionName = "Inventory";
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			// Clear inventory
			Filter = New Structure;
			Filter.Insert("Products", ClosingResult.FilterProducts);
			
			RowsToDelete = Object[TabularSectionName].FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
					Object.SerialNumbers, RowToDelete,, UseSerialNumbersBalance);
				Object[TabularSectionName].Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
			
			RowsToRecalculate = Object[TabularSectionName].FindRows(Filter);
			For Each RowToRecalculate In RowsToRecalculate Do
				CalculateAmountInTabularSectionLine(TabularSectionName, RowToRecalculate);
			EndDo;
			
			RecalculateSubtotal();
			PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
			RefillDiscountAmountOfEPD();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	ColorTextSpecifiedInDocument = StyleColors.TextSpecifiedInDocument;
		
	//InventorySerialNumbers
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Inventory.GoodsReceipt");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotEqual;
	DataFilterItem.RightValue		= Documents.GoodsReceipt.EmptyRef();
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<Specified in Goods receipt>'; ru = '<Указано в поступлении товаров>';pl = '<Określone w Przyjęciu zewnętrznym>';es_ES = '<Especificado en el recibo de Mercancías>';es_CO = '<Especificado en el recibo de Mercancías>';tr = '<Ambar girişinde belirtilen>';it = '<Specificato nel Documento di Trasporto>';de = '<Im Wareneingang angegeben>'"));
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextSpecifiedInDocument);
	ItemAppearance.Appearance.SetParameterValue("Enabled", False);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("InventorySerialNumbers");
	FieldAppearance.Use = True;
	
	ItemAppearance.Presentation = NStr("en = 'Goods receipt without serial numbers'; ru = 'Поступление товаров без серийных номеров';pl = 'Przyjęcie zewnętrzne bez numerów seryjnych';es_ES = 'Entrada de mercancías sin números de serie';es_CO = 'Entrada de mercancías sin números de serie';tr = 'Seri numarasız ambar girişi';it = 'Ricevuta merci senza numeri di serie';de = 'Wareneingang ohne Seriennummern'");
	
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance);
	
EndProcedure

// Procedure sets availability of the form items.
//
&AtServer
Procedure SetVisibleAndEnabled(ChangedTypeOperations = False)
	
	Items.IncludeExpensesInCostPrice.Visible = True;
	Items.Expenses.Visible = True;
	Items.InventoryAmountExpenses.Visible = True;
	
	If Object.IncludeExpensesInCostPrice Then
		
		Items.ExpensesOrder.Visible = False;
		Items.ExpensesStructuralUnit.Visible = False;
		Items.ExpensesBusinessLine.Visible = False;
		Items.ExpensesProject.Visible = False;
		Items.AllocateExpenses.Visible = True;
		Items.InventoryAmountExpenses.Visible = True;
		Items.ExpensesIncomeAndExpenseItems.Visible = False;
		Items.ExpensesRegisterExpense.Visible = False;
		
	Else
		
		Items.ExpensesOrder.Visible = True;
		Items.ExpensesStructuralUnit.Visible = True;
		Items.ExpensesBusinessLine.Visible = True;
		Items.ExpensesProject.Visible = True;
		Items.AllocateExpenses.Visible = False;
		Items.InventoryAmountExpenses.Visible = False;
		Items.ExpensesIncomeAndExpenseItems.Visible = True;
		Items.ExpensesRegisterExpense.Visible = Not UseDefaultTypeOfAccounting;
		
	EndIf;
	
	NewArray = New Array();
	NewArray.Add(Enums.BusinessUnitsTypes.Warehouse);
	NewArray.Add(Enums.BusinessUnitsTypes.Retail);
	NewArray.Add(Enums.BusinessUnitsTypes.RetailEarningAccounting);
	ArrayOwnInventoryAndGoodsOnCommission = New FixedArray(NewArray);
	NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayOwnInventoryAndGoodsOnCommission);
	NewArray = New Array();
	NewArray.Add(NewParameter);
	NewParameters = New FixedArray(NewArray);
	Items.StructuralUnit.ChoiceParameters = NewParameters;
	
	Items.Order.Visible = True;
	Items.FillByOrder.Visible = True;
	Items.InventoryOrder.Visible = True;
	
	If Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
	 OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		Items.ExpensesOrder.Visible = False;
	Else
		Items.ExpensesOrder.Visible = True;
	EndIf;
	
	If Not ValueIsFilled(Object.StructuralUnit)
		OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		Items.Cell.Visible = False;
	Else
		Items.Cell.Visible = True;
	EndIf;
	
	// VAT Rate, VAT Amount, Total.
	If ChangedTypeOperations Then
		FillVATRateByCompanyVATTaxation();
	Else
		SetVATTaxationDependantItemsVisibility();
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = GetAllowedEditDocumentPrices();
		
	Items.InventoryPrice.ReadOnly		= Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly		= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly	= Not AllowedEditDocumentPrices;
	
	SetVisibleFromUserSettings();
	
	Items.DocumentTax.Visible	= UseVAT;
	
	If NOT WorkWithVAT.GetUseTaxInvoiceForPostingVAT(Object.Date, Object.Company) Then
		Items.TaxInvoiceText.Visible = False;
	Else
		Items.TaxInvoiceText.Visible = True;
	EndIf;
	
EndProcedure

// Procedure sets the form item visible.
//
&AtServer
Procedure SetVisibleFromUserSettings()
	
	VisibleValue = (Object.PurchaseOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader"));
	
	Items.Order.Enabled = VisibleValue;
	If VisibleValue Then
		Items.Order.InputHint = "";
	Else 
		Items.Order.InputHint = NStr("en = '<Multiple orders mode>'; ru = '<Режим нескольких заказов>';pl = '<Tryb wielu zamówień>';es_ES = '<Modo de órdenes múltiples>';es_CO = '<Modo de órdenes múltiples>';tr = '<Birden fazla emir modu>';it = '<Modalità ordini multipli>';de = '<Mehrfach-Bestellungen Modus>'");
	EndIf;
	Items.InventoryOrder.Visible = Not VisibleValue;
	Items.FillByOrder.Visible = VisibleValue;
	OrderInHeader = VisibleValue;
	
EndProcedure

&AtServer
Procedure SetVATTaxationDependantItemsVisibility()
	
	IsSubjectToVATTaxation = Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
	
	Items.InventoryVATRate.Visible = IsSubjectToVATTaxation;
	Items.InventoryVATAmount.Visible = IsSubjectToVATTaxation;
	Items.InventoryAmountTotal.Visible = IsSubjectToVATTaxation;
	
	Items.ExpencesVATRate.Visible = IsSubjectToVATTaxation;
	Items.ExpencesAmountVAT.Visible = IsSubjectToVATTaxation;
	Items.TotalExpences.Visible = IsSubjectToVATTaxation;
	Items.DocumentTax.Visible = IsSubjectToVATTaxation;
	
	Items.PaymentCalendarPayVATAmount.Visible = IsSubjectToVATTaxation;
	Items.PaymentCalendarPaymentVATAmount.Visible = IsSubjectToVATTaxation;
	
	IsReverseChargeVATTaxation = Object.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT;
	
	Items.InventoryReverseChargeVATRate.Visible = IsReverseChargeVATTaxation;
	Items.InventoryReverseChargeVATAmount.Visible = IsReverseChargeVATTaxation;
	Items.ExpensesReverseChargeVATRate.Visible = IsReverseChargeVATTaxation And Not Object.IncludeExpensesInCostPrice;
	Items.ExpensesReverseChargeVATAmount.Visible = IsReverseChargeVATTaxation And Not Object.IncludeExpensesInCostPrice;
	
	Items.InventoryTotalReverseChargeAmountOfVAT.Visible = IsReverseChargeVATTaxation;
	
EndProcedure

&AtClient
Procedure SetVisibleEarlyPaymentDiscounts()
	
	VisibleFlag = GetVisibleFlagForEPD(Object.Counterparty, Object.Contract);
	
	Items.GroupEarlyPaymentDiscounts.Visible = (VisibleFlag
		And Object.OperationKind <> PredefinedValue("Enum.OperationTypesSupplierInvoice.ZeroInvoice"));
	
EndProcedure

&AtServer
Procedure SetPrepaymentColumnsProperties()
	
	Items.PrepaymentSettlementsAmount.Title =
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Clearing amount (%1)'; ru = 'Сумма зачета (%1)';pl = 'Kwota rozliczenia (%1)';es_ES = 'Importe de liquidaciones (%1)';es_CO = 'Importe de liquidaciones (%1)';tr = 'Mahsup edilen tutar (%1)';it = 'Importo di compensazione (%1)';de = 'Ausgleichsbetrag (%1)'"),
			SettlementsCurrency);
	
	If Object.DocumentCurrency = SettlementsCurrency Then
		Items.PrepaymentAmountDocCur.Visible = False;
	Else
		Items.PrepaymentAmountDocCur.Visible = True;
		Items.PrepaymentAmountDocCur.Title =
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Amount (%1)'; ru = 'Сумма (%1)';pl = 'Wartość (%1)';es_ES = 'Importe (%1)';es_CO = 'Cantidad (%1)';tr = 'Tutar (%1)';it = 'Importo (%1)';de = 'Betrag (%1)'"),
				Object.DocumentCurrency);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetAdvanceInvoiceEnabled()
	
	IsAdvanceInvoiceEnabled	= True;
	IsGoodsReceiptEnabled	= True;
	
	For Each LineInventory In Object.Inventory Do
		
		If ValueIsFilled(LineInventory.GoodsReceipt) Then
			IsAdvanceInvoiceEnabled = False;
			Break;
		EndIf;

	EndDo;
	
	If Not (Object.OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.Invoice")
		Or Object.OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.DropShipping"))Then
		IsGoodsReceiptEnabled = False;
	EndIf;
	
	Items.InventoryGoodsReceipt.ReadOnly	= Not IsGoodsReceiptEnabled;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.AdvanceInvoice")
		And IsAdvanceInvoiceEnabled = False Then
		
		Object.OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.Invoice");
		
	EndIf;
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	Fields.Add(Items.ExpencesPrice);
	
	Return Fields;
	
EndFunction

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure is called by clicking the PricesCurrency button of the command bar tabular field.
//
&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies();
		
EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure DistributeExpensesByQuantity(Command)
	
	DistributeTabSectExpensesByQuantity();
		
EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure DistributeExpensesByAmount(Command)
	
	DistributeTabSectExpensesByAmount();
	
EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure EditPrepaymentOffset(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en = 'Please select a counterparty.'; ru = 'Выберите контрагента.';pl = 'Wybierz kontrahenta.';es_ES = 'Por favor, seleccione un contraparte.';es_CO = 'Por favor, seleccione un contraparte.';tr = 'Lütfen, cari hesap seçin.';it = 'Si prega di selezionare una controparte.';de = 'Bitte wählen Sie einen Geschäftspartner aus.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Contract) Then
		ShowMessageBox(, NStr("en = 'Please select a contract.'; ru = 'Выберите договор.';pl = 'Wybierz umowę.';es_ES = 'Por favor, especifique un contrato.';es_CO = 'Por favor, especifique un contrato.';tr = 'Lütfen, sözleşme seçin.';it = 'Si prega di selezionare un contratto.';de = 'Bitte wählen Sie einen Vertrag aus.'"));
		Return;
	EndIf;
	
	OrdersArray = New Array;
	For Each CurItem In Object.Inventory Do
		OrderStructure = New Structure("Order, Total");
		OrderStructure.Order = ?(CurItem.Order = Undefined, PredefinedValue("Document.PurchaseOrder.EmptyRef"), CurItem.Order);
		OrderStructure.Total = CurItem.Total;
		OrdersArray.Add(OrderStructure);
	EndDo;
	For Each CurItem In Object.Expenses Do
		OrderStructure = New Structure("Order, Total");
		OrderStructure.Order = CurItem.PurchaseOrder;
		OrderStructure.Total = CurItem.Total;
		OrdersArray.Add(OrderStructure);
	EndDo;
	
	AddressPrepaymentInStorage = PlacePrepaymentToStorage();
	
	OrderParameter = ?(CounterpartyDoSettlementsByOrders, ?(OrderInHeader, Object.Order, OrdersArray), Undefined);
	
	SelectionParameters = New Structure;
	SelectionParameters.Insert("AddressPrepaymentInStorage", AddressPrepaymentInStorage);
	SelectionParameters.Insert("Pick", True);
	SelectionParameters.Insert("IsOrder", True);
	SelectionParameters.Insert("OrderInHeader", OrderInHeader);
	SelectionParameters.Insert("Company", Company);
	SelectionParameters.Insert("Order", OrderParameter);
	SelectionParameters.Insert("Date", Object.Date);
	SelectionParameters.Insert("Ref", Object.Ref);
	SelectionParameters.Insert("Counterparty", Object.Counterparty);
	SelectionParameters.Insert("Contract", Object.Contract);
	SelectionParameters.Insert("ExchangeRate", Object.ExchangeRate);
	SelectionParameters.Insert("Multiplicity", Object.Multiplicity);
	SelectionParameters.Insert("ContractCurrencyExchangeRate", Object.ContractCurrencyExchangeRate);
	SelectionParameters.Insert("ContractCurrencyMultiplicity", Object.ContractCurrencyMultiplicity);
	SelectionParameters.Insert("DocumentCurrency", Object.DocumentCurrency);
	SelectionParameters.Insert("DocumentAmount", Object.Inventory.Total("Total") + Object.Expenses.Total("Total"));
	
	ReturnCode = Undefined;
	
	NotifyParametersStructure = New Structure("AddressPrepaymentInStorage, SelectionParameters", AddressPrepaymentInStorage, SelectionParameters);
	OpenForm("CommonForm.SelectAdvancesPaidToTheSupplier",
		SelectionParameters,,,,,
		New NotifyDescription("EditPrepaymentOffsetEnd", ThisObject, NotifyParametersStructure));
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetEnd(Result, AdditionalParameters) Export
	
	AddressPrepaymentInStorage = AdditionalParameters.AddressPrepaymentInStorage;
	SelectionParameters = AdditionalParameters.SelectionParameters;
	
	EditPrepaymentOffsetFragment(AddressPrepaymentInStorage, Result);
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetFragment(Val AddressPrepaymentInStorage, Val ReturnCode)
	
	If ReturnCode = DialogReturnCode.OK Then
		GetPrepaymentFromStorage(AddressPrepaymentInStorage);
		Modified = True;
		PrepaymentWasChanged = True;
	EndIf;
	
EndProcedure

// You can call the procedure by clicking
// the button "FillByBasis" of the tabular field command panel.
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		MessagesToUserClient.ShowMessageSelectBaseDocument();
		Return;
	EndIf;
	
	Response = Undefined;
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'Do you want to refill the supplier invoice?'; ru = 'Перезаполнить инвойс поставщика?';pl = 'Czy chcesz uzupełnić fakturę zakupu?';es_ES = '¿Quiere volver a rellenar la factura del proveedor?';es_CO = '¿Quiere volver a rellenar la factura del proveedor?';tr = 'Satın alma faturası yeniden doldurulsun mu?';it = 'Volete ricompilare la fattura del fornitore?';de = 'Möchten Sie die Lieferantenrechnung auffüllen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		
		FillByDocument(Object.BasisDocument);
		
		SetVisibleAndEnabled();
		
		SetVisibleEnablePaymentTermItems();
		
		GenerateLabelPricesAndCurrency();
		
		RecalculateSubtotal();
		
		SetAdvanceInvoiceEnabled();
		
	EndIf;
	
EndProcedure

// You can call the procedure by clicking
// the button "FillByOrder" of the tabular field command panel.
//
&AtClient
Procedure FillByOrder(Command)
	
	If ValueIsFilled(Object.Order) Then
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("FillEndByOrder", ThisObject),
			NStr("en = 'The document will be fully filled out according to the ""Order."" Continue?'; ru = 'Документ будет полностью перезаполнен по ""Заказу""! Продолжить выполнение операции?';pl = 'Dokument zostanie wypełniony w całości zgodnie z ""Zamówieniem"". Dalej?';es_ES = 'El documento se rellenará completamente según el ""Orden"". ¿Continuar?';es_CO = 'El documento se rellenará completamente según el ""Orden"". ¿Continuar?';tr = 'Belge ""Sipariş""e göre tamamen doldurulacak. Devam edilsin mi?';it = 'Il documento sarà interamente compilato secondo l''""Ordine"". Continuare?';de = 'Das Dokument wird entsprechend der ""Bestellung"" vollständig ausgefüllt. Fortsetzen?'"),
			QuestionDialogMode.YesNo);
	Else
		MessagesToUserClient.ShowMessageSelectOrder();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillEndByOrder(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		
		FillByDocument(Object.Order);
		
		SetVisibleAndEnabled();
		
		SetVisibleEnablePaymentTermItems();
		
		GenerateLabelPricesAndCurrency();
		
		RecalculateSubtotal();
		
	EndIf;
	
EndProcedure

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
	EndIf;
	
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
			CalculateAmountInTabularSectionLine("Inventory", TabularSectionRow);
		EndIf;
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
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
		AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

// Procedure - clicking handler on the hyperlink TaxInvoiceText.
//
&AtClient
Procedure TaxInvoiceTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithVATClient.OpenTaxInvoice(ThisObject, True);
	
EndProcedure

// Procedure - command handler DocumentSetup.
//
&AtClient
Procedure DocumentSetup(Command)
	
	// 1. Form parameter structure to fill "Document setting" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("PurchaseOrderPositionInReceiptDocuments",		Object.PurchaseOrderPosition);
	ParametersStructure.Insert("WereMadeChanges", 								False);
	
	StructureDocumentSetting = Undefined;
	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.PurchaseOrderPosition = StructureDocumentSetting.PurchaseOrderPositionInReceiptDocuments;
		
		If Object.PurchaseOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
			If Object.Inventory.Count() Then
				Object.Order = Object.Inventory[0].Order;
			EndIf;
		ElsIf Object.PurchaseOrderPosition = PredefinedValue("Enum.AttributeStationing.InTabularSection") Then
			If ValueIsFilled(Object.Order) Then
				For Each InventoryRow In Object.Inventory Do
					If Not ValueIsFilled(InventoryRow.Order) Then
						InventoryRow.Order = Object.Order;
					EndIf;
				EndDo;
				Object.Order = Undefined;
			EndIf;
		EndIf;
		
		SetVisibleFromUserSettings();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_GenerateGoodsIssueReturn(Command)
	
	InvoicesArray = New Array;
	InvoicesArray.Add(Object.Ref);
	DriveClient.GoodsIssueReturnGenerationBasedOnSupplierInvoice(InvoicesArray);
	
EndProcedure

&AtClient
Procedure Attachable_GenerateGoodsIssue(Command)
	
	InvoicesArray = New Array;
	InvoicesArray.Add(Object.Ref);
	
	DriveClient.GoodsIssueGenerationBasedOnSupplierInvoice(InvoicesArray, IsDropShipping);
	
EndProcedure

#EndRegion

#Region TabularSectionCommandpanelsActions

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CommandFillBySpecification(Command)
	
	If Object.Materials.Count() <> 0 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("CommandToFillBySpecificationEnd", ThisObject),
						NStr("en = 'Tabular section ""Stock provided to third-party"" will be filled in again. Do you want to continue?'; ru = 'Табличная часть ""Материалы, предоставленные сторонним организациям"" будет перезаполнена. Вы хотите продолжить?';pl = 'Sekcja tabelaryczna ""Zapasy dostarczane od strony trzeciej"" zostanie ponownie wypełniona. Czy chcesz kontynuować?';es_ES = 'La sección tabular ""Stock transferido a un tercero"" se rellenará de nuevo. ¿Quieres continuar?';es_CO = 'La sección tabular ""Stock transferido a un tercero"" se rellenará de nuevo. ¿Quieres continuar?';tr = '“Üçüncü taraflara sağlanan stok” başlıklı Tablo bölümü tekrar doldurulacaktır. Devam etmek istiyor musunuz?';it = 'La sezione tabellare ""Merci ricevute da terze parti"" sarà compilata di nuovo. Volete continuare?';de = 'Der tabellarische Teil ""Bestand an Dritte"" wird erneut ausgefüllt. Möchten Sie fortsetzen?'"), 
						QuestionDialogMode.YesNo, 0);
        Return;
		
	EndIf;
	
	CommandToFillBySpecificationFragment();
EndProcedure

&AtClient
Procedure CommandToFillBySpecificationEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    CommandToFillBySpecificationFragment();

EndProcedure

&AtClient
Procedure CommandToFillBySpecificationFragment()
    
    FillByBillsOfMaterialsAtServer();

EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CommandFillByGoodsBalance(Command)
	
	If Object.Materials.Count() <> 0 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("CommandToFillByGoodsBalanceEnd", ThisObject),
						NStr("en = 'Tabular section ""Stock received from third-party"" will be filled in again. Do you want to continue?'; ru = 'Табличная часть ""Материалы, полученные от сторонних организаций"" будет перезаполнена. Вы хотите продолжить?';pl = 'Sekcja tabelaryczna ""Stan zapasów otrzymanych od stron trzecich"" zostanie ponownie wypełniona. Czy chcesz kontynuować?';es_ES = 'La sección tabular ""Stock recibido de un tercero"" se rellenará de nuevo. ¿Quieres continuar?';es_CO = 'La sección tabular ""Stock recibido de un tercero"" se rellenará de nuevo. ¿Quieres continuar?';tr = '“Üçüncü taraflardan alınan stok” başlıklı Tablo bölümü tekrar doldurulacaktır. Devam etmek istiyor musunuz?';it = 'Sezione tabella ""Merci ricevute da terze parti"" sarà compilato nuovamente. Volete continuare?';de = 'Der tabellarische Abschnitt ""Von Dritten erhaltener Bestand"" wird erneut ausgefüllt. Möchten Sie fortsetzen?'"), 
						QuestionDialogMode.YesNo, 0);
        Return;
		
	EndIf;
	
	CommandToFillByGoodsBalanceFragment();
EndProcedure

&AtClient
Procedure CommandToFillByGoodsBalanceEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    CommandToFillByGoodsBalanceFragment();

EndProcedure

&AtClient
Procedure CommandToFillByGoodsBalanceFragment()
    
    FillByGoodsBalanceAtServer();

EndProcedure

#EndRegion

&AtClient
Procedure SetVisibleAccordingToInvoiceType()
	
	ValueAutoMarkIncomplete	= Undefined;
	IsReadOnly				= False;
	VisibleRegularInvoice	= True;
	IsDropShipping			= (Object.OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.DropShipping"));
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.ZeroInvoice") Then
		
		ValueAutoMarkIncomplete = False;
		IsReadOnly				= True;
		VisibleRegularInvoice	= False;
		
	ElsIf IsDropShipping Then
		
		VisibleStructuralUnit	= False;
		
	ElsIf Object.ForOpeningBalancesOnly Then
		
		ValueAutoMarkIncomplete = False;
		
	EndIf;
	
	Items.InventoryAmount.AutoMarkIncomplete			= ValueAutoMarkIncomplete;
	Items.InventoryQuantity.AutoMarkIncomplete			= ValueAutoMarkIncomplete;
	Items.InventoryPrice.AutoMarkIncomplete				= ValueAutoMarkIncomplete;
	Items.InventoryMeasurementUnit.AutoMarkIncomplete	= ValueAutoMarkIncomplete;
	Items.InventoryVATRate.AutoMarkIncomplete			= ValueAutoMarkIncomplete;
	Items.InventoryVATAmount.AutoMarkIncomplete			= ValueAutoMarkIncomplete;
	
	Items.AmountExpense.AutoMarkIncomplete			= ValueAutoMarkIncomplete;
	Items.ExpensesQuantity.AutoMarkIncomplete		= ValueAutoMarkIncomplete;
	Items.ExpencesPrice.AutoMarkIncomplete			= ValueAutoMarkIncomplete;
	Items.CostsMeasurementUnit.AutoMarkIncomplete	= ValueAutoMarkIncomplete;
	Items.ExpencesVATRate.AutoMarkIncomplete		= ValueAutoMarkIncomplete;
	Items.ExpencesAmountVAT.AutoMarkIncomplete		= ValueAutoMarkIncomplete;
	
	Items.GroupMaterials.Visible				= VisibleRegularInvoice;
	Items.GroupPrepayment.Visible				= VisibleRegularInvoice;
	Items.GroupPaymentsCalendar.Visible			= VisibleRegularInvoice;
	Items.FolderOrderBasis.Visible				= VisibleRegularInvoice;
	Items.GroupBasisDocument.Visible			= VisibleRegularInvoice;
	Items.Totals.Visible						= VisibleRegularInvoice;
	
	Items.InventorySearchByBarcode.Visible			= VisibleRegularInvoice;
	Items.InventoryLoadFromFileInventory.Visible	= VisibleRegularInvoice;
	
	// Goods
	Items.InventoryGroupSelect.Visible		= VisibleRegularInvoice;
	Items.AllocateExpenses.Visible			= VisibleRegularInvoice And Object.IncludeExpensesInCostPrice;
	Items.InventoryCrossReference.Visible	= VisibleRegularInvoice;
	
	For Each ItemInventory In Items.Inventory.ChildItems Do
		
		If ItemInventory = Items.InventoryProducts Or ItemInventory = Items.InventoryAmountTotal Then
		
			Continue;
		
		EndIf; 
		
		ItemInventory.ReadOnly = IsReadOnly;
	
	EndDo;
	
	// Services
	Items.ExpensesGroupSelect.Visible	= VisibleRegularInvoice;
	
	For Each ItemExpenses In Items.Expenses.ChildItems Do
		
		If ItemExpenses = Items.ExpensesProducts Or ItemExpenses = Items.TotalExpences Then
		
			Continue;
		
		EndIf; 
		
		ItemExpenses.ReadOnly = IsReadOnly;
	
	EndDo;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = GetAllowedEditDocumentPrices();
	
	If Not AllowedEditDocumentPrices Then
		
		Items.InventoryPrice.ReadOnly		= Not AllowedEditDocumentPrices;
		Items.InventoryAmount.ReadOnly		= Not AllowedEditDocumentPrices;
		Items.InventoryVATAmount.ReadOnly	= Not AllowedEditDocumentPrices;
		
	EndIf;
	
	// Drop shipping restrict
	Items.Warehouse.Visible = Not IsDropShipping;
	
	ArrayOperationTypesPO = New Array();
	ArrayOperationTypesGR = New Array();
	If IsDropShipping Then
		ArrayOperationTypesPO.Add(PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForDropShipping"));
		ArrayOperationTypesGR.Add(PredefinedValue("Enum.OperationTypesGoodsReceipt.DropShipping"));
	Else
		ArrayOperationTypesPO.Add(PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForProcessing"));
		ArrayOperationTypesPO.Add(PredefinedValue("Enum.OperationTypesPurchaseOrder.OrderForPurchase"));
		ArrayOperationTypesGR.Add(PredefinedValue("Enum.OperationTypesGoodsReceipt.PurchaseFromSupplier"));
		ArrayOperationTypesGR.Add(PredefinedValue("Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty"));
		ArrayOperationTypesGR.Add(PredefinedValue("Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty"));
		ArrayOperationTypesGR.Add(PredefinedValue("Enum.OperationTypesGoodsReceipt.SalesReturn"));
		ArrayOperationTypesGR.Add(PredefinedValue("Enum.OperationTypesGoodsReceipt.IntraCommunityTransfer"));
		ArrayOperationTypesGR.Add(PredefinedValue("Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractor"));
		ArrayOperationTypesGR.Add(PredefinedValue("Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor"));
		ArrayOperationTypesGR.Add(PredefinedValue("Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer"));
	EndIf;
	
	FixedArrayParameters = DriveClientServer.GetFixedArrayChoiceParameters(ArrayOperationTypesPO, "Filter.OperationKind");
	Items.Order.ChoiceParameters			= FixedArrayParameters;
	Items.InventoryOrder.ChoiceParameters	= FixedArrayParameters;
	
	FixedArrayParameters = DriveClientServer.GetFixedArrayChoiceParameters(ArrayOperationTypesGR, "Filter.OperationType");
	Items.InventoryGoodsReceipt.ChoiceParameters = FixedArrayParameters;
	
	
	SetAdvanceInvoiceEnabled();
	
EndProcedure

&AtServer
Procedure SetZeroInvoiceData(ParametersStructure)
	
	InventoryAttributes	= Metadata.Documents.SupplierInvoice.TabularSections.Inventory.Attributes;
	ExpensesAttributes	= Metadata.Documents.SupplierInvoice.TabularSections.Expenses.Attributes;
	
	For Each LineInventory In Object.Inventory Do
		
		For Each MetaAttribute In InventoryAttributes Do
			
			If MetaAttribute.Name = "Products" Then
			
				Continue;
			
			EndIf;
			
			LineInventory[MetaAttribute.Name] = Undefined;
			
		EndDo; 
		
	EndDo;
	
	For Each LineExpenses In Object.Expenses Do
	
		For Each MetaAttribute In ExpensesAttributes Do
			
			If MetaAttribute.Name = "Products" Then
			
				Continue;
			
			EndIf;
			
			LineExpenses[MetaAttribute.Name] = Undefined;
			
		EndDo;
	
	EndDo;
	
	Object.Order			= Documents.PurchaseOrder.EmptyRef();
	Object.BasisDocument	= Undefined;
	Object.SetPaymentTerms	= False;
	
	Object.Materials.Clear();
	Object.Prepayment.Clear();
	Object.PaymentCalendar.Clear();
	Object.PrepaymentVAT.Clear();
	Object.EarlyPaymentDiscounts.Clear();
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtServerNoContext
Function GetAllowedEditDocumentPrices()
	
	Return DriveAccessManagementReUse.AllowedEditDocumentPrices() 
		OR IsInRole("AddEditPurchasesSubsystem");
	
EndFunction

&AtClient
Procedure SetMeasurementUnits()
	
	If Not OldOperationKind = PredefinedValue("Enum.OperationTypesSupplierInvoice.ZeroInvoice") Then
		Return;
	EndIf;
	
	For Each LineInventory In Object.Inventory Do
	
		LineInventory.MeasurementUnit = GetMeasurementUnitOfProduct(LineInventory.Products);
	
	EndDo;
	
	For Each LineExpenses In Object.Expenses Do
	
		LineExpenses.MeasurementUnit = GetMeasurementUnitOfProduct(LineExpenses.Products);
	
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetMeasurementUnitOfProduct(RefProducts)
	
	Return Common.ObjectAttributeValue(RefProducts, "MeasurementUnit");
	
EndFunction

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
	
	Return DriveServer.GetCalculatedAdvancePaidExchangeRate(ParametersStructure);
	
EndFunction

#Region Reservation

&AtServer
Function PutEditReservationDataToTempStorage()

	DocObject = FormAttributeToValue("Object");
	DataForOwnershipForm = InventoryReservationServer.GetDataFormInventoryReservationForm(DocObject);
	TempStorageAddress = PutToTempStorage(DataForOwnershipForm, UUID);
	
	Return TempStorageAddress;

EndFunction

&AtServer
Procedure EditReservationProcessingAtServer(TempStorageAddress)
	
	StructureData = GetFromTempStorage(TempStorageAddress);
	
	Object.AdjustedReserved = StructureData.AdjustedReserved;
	
	If StructureData.AdjustedReserved Then
		Object.Reservation.Load(StructureData.ReservationTable);
	EndIf;
	
	ThisObject.Modified = True;
	
EndProcedure

&AtClient
Procedure EditReservationProcessingAtClient(TempStorageAddress)
	
	EditReservationProcessingAtServer(TempStorageAddress);
	
EndProcedure

&AtClient
Procedure CheckReservedProductsChangeClient(Cancel)

	If Object.Posted Then
			
		If CheckReservedProductsChange() Then
			
			If Object.AdjustedReserved Then
				ShowQueryBoxCheckReservedProductsChange(True);
			Else
				MessagesToUserClient.ShowMessageCannotOpenInventoryReservationWindow();
			EndIf;
			
			Cancel = True;
			Return;
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure ShowQueryBoxCheckReservedProductsChange(NeedOpenForm = False)
	
	MessageString = MessagesToUserClient.MessageCleaningWarningInventoryReservation(Object.Ref);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("NeedOpenForm", NeedOpenForm);

	ShowQueryBox(New NotifyDescription("CheckReservedProductsChangeEnd", ThisObject, ParametersStructure),
	MessageString, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure CheckReservedProductsChangeEnd(QuestionResult, AdditionalParameters) Export 
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteMode", DocumentWriteMode.Posting);
	
	If QuestionResult = DialogReturnCode.Yes Then
		
		Object.AdjustedReserved = False;
		Object.Reservation.Clear();
		
		Try
			Write(WriteParameters);
			
			If AdditionalParameters.Property("NeedOpenForm") And AdditionalParameters.NeedOpenForm Then
				OpenInventoryReservation();
			EndIf;
		Except
			ShowMessageBox(Undefined, BriefErrorDescription(ErrorInfo()));
		EndTry;
		
		Return;
	EndIf;

EndProcedure

&AtServer
Function CheckReservedProductsChange()
	
	If Object.Reservation.Count()> 0 Then
		
		DocumentObject = FormAttributeToValue("Object");
		
		ParametersData = New Structure;
		ParametersData.Insert("Ref", Object.Ref);
		ParametersData.Insert("TableName", "Inventory");
		ParametersData.Insert("ProductsChanges", DocumentObject.Inventory.Unload());
		ParametersData.Insert("UseOrder", True);
		
		Return InventoryReservationServer.CheckReservedProductsChange(ParametersData);
		
	EndIf;
	
	Return False;
	
EndFunction

&AtServer
Function ChangeAdjustedReserved()

	Return Object.AdjustedReserved = Common.ObjectAttributeValue(Object.Ref, "AdjustedReserved");

EndFunction

#EndRegion

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion