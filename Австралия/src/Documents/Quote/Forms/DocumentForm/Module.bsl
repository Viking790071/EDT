#Region Variables

&AtClient
Var UpdateSubordinatedInvoice;

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If UsersClientServer.IsExternalUserSession() Then
		If Object.Ref.IsEmpty() Then
			Cancel = True;
		EndIf;
		Return;
	EndIf;
	
	DriveServer.FillDocumentHeader(
		Object,
		,
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
		
		If ValueIsFilled(Object.Contract) Then
			
			ContractData = Common.ObjectAttributesValues(Object.Contract, "SettlementsCurrency, DiscountMarkupKind, PriceKind");
			
			Object.DocumentCurrency 			= ContractData.SettlementsCurrency;
			SettlementsCurrencyRateRepetition	= CurrencyRateOperations.GetCurrencyRate(Object.Date, ContractData.SettlementsCurrency, Object.Company);
			Object.ExchangeRate					= ?(SettlementsCurrencyRateRepetition.Rate = 0, 1, SettlementsCurrencyRateRepetition.Rate);
			Object.Multiplicity					= ?(SettlementsCurrencyRateRepetition.Repetition = 0, 1, SettlementsCurrencyRateRepetition.Repetition);
			Object.DiscountMarkupKind			= ContractData.DiscountMarkupKind;
			Object.PriceKind					= ContractData.PriceKind;
			
			If Object.PaymentCalendar.Count() = 0 Then
				FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Initialization of form attributes.
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	CASE
		|		WHEN Companies.BankAccountByDefault.CashCurrency = &CashCurrency
		|			THEN Companies.BankAccountByDefault
		|		ELSE UNDEFINED
		|	END AS BankAccount
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.Ref = &Company");
		Query.SetParameter("Company", Object.Company);
		Query.SetParameter("CashCurrency", Object.DocumentCurrency);
		QueryResult = Query.Execute();
		Selection = QueryResult.Select();
		If Selection.Next() Then
			Object.BankAccount = Selection.BankAccount;
		EndIf;
		Object.PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Object.Company);
		
	EndIf;
	
	// Default Status
	If GetFunctionalOption("UseKanbanForQuotations") Then
		If ValueIsFilled(Object.Ref) Then
			Status = QuotationStatuses.GetQuotationStatus(Object.Ref);
		Else
			Status = QuotationStatuses.GetQuotationDefaultStatus();
		EndIf;
	Else
		Items.Status.Visible = False;
	EndIf;
	
	// Bundles
	BundlesOnCreateAtServer();
	
	If Not ValueIsFilled(Object.Ref) Then
		
		If Parameters.FillingValues.Property("Inventory") Then
			
			For Each RowData In Parameters.FillingValues.Inventory Do
				
				If RowData.Property("IsBundle") And RowData.IsBundle Then
					
					FilterStructure = New Structure;
					FilterStructure.Insert("Products", RowData.Products);
					If RowData.Property("Characteristic") And ValueIsFilled(RowData.Characteristic) Then
						FilterStructure.Insert("Characteristic", RowData.Characteristic);
					EndIf;
					Rows = Object.Inventory.FindRows(FilterStructure);
					
					For Each BundleRow In Rows Do
						
						StructureData = New Structure();
						StructureData.Insert("Company",			Object.Company);
						StructureData.Insert("Products",		BundleRow.Products);
						StructureData.Insert("Characteristic",	BundleRow.Characteristic);
						StructureData.Insert("VATTaxation",		Object.VATTaxation);
						If ValueIsFilled(Object.PriceKind) Then
							StructureData.Insert("ProcessingDate",		Object.Date);
							StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
							StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
							StructureData.Insert("PriceKind",			Object.PriceKind);
							StructureData.Insert("Factor",				1);
							StructureData.Insert("DiscountMarkupKind",	Object.DiscountMarkupKind);
						EndIf;
						// DiscountCards
						StructureData.Insert("DiscountCard", Object.DiscountCard);
						StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
						// End DiscountCards
						StructureData = GetDataProductsOnChange(StructureData);
						
						If Not StructureData.UseCharacteristics Then
							ReplaceInventoryLineWithBundleData(ThisObject, BundleRow, StructureData);
						EndIf;
						
					EndDo;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		RefreshBundlePictures(Object.Inventory);
		RefreshBundleAttributes(Object.Inventory);
		
	EndIf;
	
	SetBundlePictureVisible();
	SetBundleConditionalAppearance();
	// End Bundles
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	Counterparty				= Object.Counterparty;
	Contract 					= Object.Contract;
	SettlementsCurrency			= Object.Contract.SettlementsCurrency;
	FunctionalCurrency			= Constants.FunctionalCurrency.Get();
	StructureByCurrency			= CurrencyRateOperations.GetCurrencyRate(Object.Date, FunctionalCurrency, Object.Company);
	RateNationalCurrency 		= StructureByCurrency.Rate;
	RepetitionNationalCurrency	= StructureByCurrency.Repetition;
	StatusBeforeChange			= Status;
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	ProcessingCompanyVATNumbers();
	
	SetAccountingPolicyValues();
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		FillVATRateByCompanyVATTaxation();
		FillSalesTaxRate();
		
	EndIf;
	
	SetVisibleTaxAttributes();
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	// Setting contract visible.
	SetContractVisible();
	
	SetConditionalAppearance();
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPrice.ReadOnly 				   = Not AllowedEditDocumentPrices;
	Items.InventoryDiscountPercentMargin.ReadOnly = Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly 			   = Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 			   = Not AllowedEditDocumentPrices;
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// StandardSubsystems.Interactions
	Interactions.PrepareNotifications(ThisObject, Parameters);
	// End StandardSubsystems.Interactions
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.Quote.TabularSections.Inventory, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
	EditingIsAvailable = Not ReadOnly And AccessRight("Edit", Metadata.Documents.Quote);
	
	Items.InventoryDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	PopulateVariantsList(Items.CurrentVariant.ChoiceList,
		Object.VariantsCount,
		Object.PreferredVariant,
		EditingIsAvailable);
	CurrentVariant = Object.PreferredVariant;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If UsersClientServer.IsExternalUserSession() Then
		PrintManagementClientDrive.GeneratePrintFormForExternalUsers(Object.Ref,
			"Document.Quote",
			"Quote",
			NStr("en = 'Quote'; ru = 'Коммерческое предложение';pl = 'Oferta cenowa';es_ES = 'Presupuesto';es_CO = 'Presupuesto';tr = 'Teklif';it = 'Preventivo';de = 'Angebot'"),
			FormOwner,
			UniqueKey);
		Cancel = True;
		Return;
	EndIf;
	
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
	
	SetVisiblePaymentMethod();
	
	If Object.PaymentCalendar.Count() > 0 Then
		Items.PaymentCalendar.CurrentRow = Object.PaymentCalendar[0].GetID();
	EndIf;
	
	SetEditInListFragmentOption();
	SetVisibleEnablePaymentTermItems();
	
	SetVariantsActionsAvailability();
	FillInventoryRelativeLineNumbers();
	SetVariantRowFilter();
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)

	// AutomaticDiscounts
	// Display message about discount calculation if you click the "Post and close" or form closes by the cross with change saving.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification(NStr("en = 'Update:'; ru = 'Изменение:';pl = 'Zaktualizuj:';es_ES = 'Actualizar:';es_CO = 'Actualizar:';tr = 'Güncelle:';it = 'Aggiornamento:';de = 'Aktualisieren:'"), 
										GetURL(Object.Ref), 
										String(Object.Ref) + ". " + NStr("en = 'The automatic discounts are calculated.'; ru = 'Автоматические скидки рассчитаны.';pl = 'Obliczono rabaty automatyczne.';es_ES = 'Los descuentos automáticos se han calculado.';es_CO = 'Los descuentos automáticos se han calculado.';tr = 'Otomatik indirimler hesaplandı.';it = 'Gli sconti automatici sono stati calcolati.';de = 'Die automatischen Rabatte werden berechnet.'"), 
										PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals
	
EndProcedure

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
	   AND IsInputAvailable() AND Not DiscountCardRead Then
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
	
	// DiscountCards
	If DiscountCardRead Then
		DiscountCardRead = False;
	EndIf;
	// End DiscountCards
	
	If EventName = "AfterRecordingOfCounterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Parameter);
		SetContractVisible();
		Items.DocumentTax.Visible = False;
		
	EndIf;
	
	// Bundles
	If BundlesClient.ProcessNotifications(ThisObject, EventName, Source) Then
		RefreshBundleComponents(Parameter.BundleProduct, Parameter.BundleCharacteristic, Parameter.Quantity, Parameter.BundleComponents);
		ActionsAfterDeleteBundleLine();
	EndIf;
	// End Bundles
	
	If EventName = "Write_Quotation" Then
		
		QuotationRef = Undefined;
		NewStatus = Undefined;
		
		If TypeOf(Parameter) = Type("Structure")
			And Parameter.Property("Quotation", QuotationRef)
			And Parameter.Property("Status", NewStatus) Then
			
			If Source <> ThisObject
				And QuotationRef = Object.Ref
				And ValueIsFilled(NewStatus)
				And Status <> NewStatus Then
				Status = NewStatus;
			EndIf;
			
		ElsIf TypeOf(Parameter) = Type("Array") Then
			
			If Parameter.Find(Object.Ref) <> Undefined Then
				NewStatus = GetQuotationStatus(Object.Ref);
				If ValueIsFilled(NewStatus) And Status <> NewStatus Then
					Status = NewStatus;
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
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
	
	// Bundles
	RefreshBundlePictures(Object.Inventory);
	RefreshBundleAttributes(Object.Inventory);
	// End Bundles
	
	SetSwitchTypeListOfPaymentCalendar();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	UpdateSubordinatedInvoice = Modified;
	
	// AutomaticDiscounts
	DiscountsCalculatedBeforeWrite = False;
	// If the document is being posted, we check whether the discounts are calculated.
	If UseAutomaticDiscounts Then
		If Not Object.DiscountsAreCalculated AND DiscountsChanged() Then
			CalculateDiscountsMarkupsClient();
			RecalculateSalesTax();
			PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
			RecalculateSubtotal();
			CalculatedDiscounts = True;
			
			CommonClientServer.MessageToUser(
				NStr("en = 'The automatic discounts are applied.'; ru = 'Рассчитаны автоматические скидки (наценки)!';pl = 'Stosowane są rabaty automatyczne.';es_ES = 'Los descuentos automáticos se han aplicado.';es_CO = 'Los descuentos automáticos se han aplicado.';tr = 'Otomatik indirimler uygulandı.';it = '. Sconti automatici sono stati applicati.';de = 'Die automatischen Rabatte werden angewendet.'"),
				Object.Ref);
			
			DiscountsCalculatedBeforeWrite = True;
		Else
			Object.DiscountsAreCalculated = True;
			RefreshImageAutoDiscountsAfterWrite = True;
		EndIf;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtServer
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
		
		If Not IsBlankString(MessageText) Then
			If Cancel Then
				MessageText = NStr("en = 'Document is not posted.'; ru = 'Документ не проведен.';pl = 'Dokument niezaksięgowany.';es_ES = 'El documento no se ha publicado.';es_CO = 'El documento no se ha publicado.';tr = 'Belge kaydedilmedi.';it = 'Il documento non è pubblicato.';de = 'Dokument ist nicht gebucht.'") + " " + MessageText;
				CommonClientServer.MessageToUser(MessageText, , "Contract", "Object");
			Else
				CommonClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
		
	EndIf;
	
	If Object.VariantsCount = 0 Then
		
		SalesTaxServer.CalculateInventorySalesTaxAmount(CurrentObject.Inventory, CurrentObject.SalesTax.Total("Amount"));
		
		AmountsHaveChanged = WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject);
		If AmountsHaveChanged Then
			PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(CurrentObject);
		EndIf;
		
	Else
		
		For Counter = 1 To Object.VariantsCount Do
			
			SalesTaxTable = CurrentObject.SalesTax.Unload(New Structure("Variant", Counter), "Amount");
			SalesTaxServer.CalculateInventorySalesTaxAmount(CurrentObject.Inventory, SalesTaxTable.Total("Amount"), Counter);
			
			IsPreferredVariant = (Counter = Object.PreferredVariant);
			
			CalculationParameters = New Structure;
			CalculationParameters.Insert("Filter", New Structure("Variant", Counter));
			CalculationParameters.Insert("ShowMessages", IsPreferredVariant);
			
			AmountsHaveChanged = WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject, CalculationParameters);
			If AmountsHaveChanged And IsPreferredVariant Then
				PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(CurrentObject);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
	// Bundles
	RefreshBundleAttributes(Object.Inventory);
	// End Bundles
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// StandardSubsystems.Interactions
	InteractionsClient.InteractionSubjectAfterWrite(ThisObject, Object, WriteParameters, "Quote");
	// End StandardSubsystems.Interactions
	
	Notify();
	Notify("Write_Quotation", Object.Ref, ThisObject);
	FillInventoryRelativeLineNumbers();
	
	// Bundles
	RefreshBundlePictures(Object.Inventory);
	// End Bundles

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

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If ValueIsFilled(Status) Then
		QuotationStatuses.SetQuotationStatus(CurrentObject.Ref, Status);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Counterparty);
		
		StructureData = GetDataCounterpartyOnChange(Object.Date,
			Object.DocumentCurrency,
			Object.Counterparty,
			Object.Company);
		
		Object.Contract = StructureData.Contract;
		
		ProcessContractChange(StructureData);
		
		Object.SalesRep = CounterpartyAttributes.SalesRep;
		
		GenerateLabelPricesAndCurrency(ThisObject);
		SetVisibleEnablePaymentTermItems();
		SetContractVisible();
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		
	EndIf;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("CounterpartyOnChange");
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormOfContractParameters(
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

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	StructureData = GetCompanyDataOnChange();
	ParentCompany = StructureData.ParentCompany;
	If Object.DocumentCurrency = StructureData.BankAccountCashAssetsCurrency Then
		Object.BankAccount = StructureData.BankAccount;
	EndIf;
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	If Object.SetPaymentTerms And ValueIsFilled(Object.PaymentMethod) Then
		PaymentTermsServerCall.FillPaymentTypeAttributes(
			Object.Company, Object.CashAssetType, Object.BankAccount, Object.PettyCash);
	EndIf;
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies();
		
EndProcedure

&AtClient
Procedure CurrentVariantOnChange(Item)
	
	If CurrentVariant > Object.VariantsCount Then
		AddVariant();
	Else
		SetVariantsActionsAvailability();
		FillInventoryRelativeLineNumbers();
		SetVariantRowFilter();
	EndIf;
	RecalculateSubtotal();
	
EndProcedure

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

&AtClient
Procedure FieldSwitchTypeListOfPaymentCalendarOnChange(Item)
	
	PaymentCalendarCount = Object.PaymentCalendar.Count();
	
	If Not SwitchTypeListOfPaymentCalendar Then
		If PaymentCalendarCount > 1 Then
			ClearMessages();
			TextMessage = NStr("en = 'You can''t change the mode of payment terms because there is more than one payment date'; ru = 'Вы не можете переключить режим отображения условий оплаты, т.к. указано более одной даты оплаты.';pl = 'Nie możesz zmienić trybu warunków płatności, ponieważ istnieje kilka dat płatności';es_ES = 'Usted no puede cambiar el modo de los términos de pago porque hay más de una fecha de pago';es_CO = 'Usted no puede cambiar el modo de los términos de pago porque hay más de una fecha de pago';tr = 'Birden fazla ödeme tarihi olduğundan, ödeme şartlarının modu değiştirilemez';it = 'Non è possibile modificare i termini di pagamento, perché c''è più di una data di pagamento';de = 'Sie können den Modus der Zahlungsbedingungen nicht ändern, da es mehr als einen Zahlungsdatum gibt.'");
			CommonClientServer.MessageToUser(TextMessage);
			
			SwitchTypeListOfPaymentCalendar = 1;
		ElsIf PaymentCalendarCount = 0 Then
			NewLine = Object.PaymentCalendar.Add();
		EndIf;
	EndIf;
	
	SetEditInListFragmentOption();

EndProcedure

&AtClient
Procedure PaymentMethodOnChange(Item)
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	SetVisiblePaymentMethod();
EndProcedure

&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	PercentOfPaymentTotal = Object.PaymentCalendar.Total("PaymentPercentage");
	
	If PercentOfPaymentTotal > 100 Then
		CurrentRow.PaymentPercentage = CurrentRow.PaymentPercentage - (PercentOfPaymentTotal - 100);
	EndIf;
	
	Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
	
	CurrentRow.PaymentAmount = Round(Totals.Amount * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(Totals.VATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure PaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
	
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentAmount");
	
	If PaymentCalendarTotal > Totals.Amount Then
		CurrentRow.PaymentAmount = CurrentRow.PaymentAmount - (PaymentCalendarTotal - Totals.Amount);
	EndIf;
	
	CurrentRow.PaymentPercentage = ?(Totals.Amount = 0, 0, Round(CurrentRow.PaymentAmount / Totals.Amount * 100, 2, 1));
	CurrentRow.PaymentVATAmount = Round(Totals.VATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
	
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	
	If PaymentCalendarTotal > Totals.VATAmount Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - Totals.VATAmount);
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure StatusOnChange(Item)
	
	If StatusBeforeChange = PredefinedValue("Catalog.QuotationStatuses.Converted") And Status <> StatusBeforeChange Then
		
		DocsArray = GetSubordinateDocuments(Object.Ref);
		
		If DocsArray.Count() > 0 Then
			
			DocsPresentations = StrConcat(DocsArray, ", ");
			MessageText = NStr("en = '""%1"" is the base document for the following documents: %2.
				|It is recommended to review these documents and edit them if needed.
				|Do you want to change the quotation status now?'; 
				|ru = '""%1"" является документом-основанием для следующих документов: %2.
				|Рекомендуется просмотреть эти документы и при необходимости отредактировать их.
				|Изменить статус коммерческого предложения сейчас?';
				|pl = '""%1"" jest dokumentem źródłowym dla następujących dokumentów: %2.
				|Zaleca się przejrzeć te dokumenty i edytować je w razie potrzeby.
				|Czy chcesz teraz zmienić status oferty cenowej?';
				|es_ES = '""%1"" es el documento base para los siguientes documentos: %2.
				|Se recomienda revisar estos documentos y editarlos si es necesario.
				| ¿Quiere cambiar el estado de la oferta ahora?';
				|es_CO = '""%1"" es el documento base para los siguientes documentos: %2.
				|Se recomienda revisar estos documentos y editarlos si es necesario.
				| ¿Quiere cambiar el estado de la oferta ahora?';
				|tr = '""%1"" şu belgelerin temel belgesi: %2.
				|Bu belgeleri incelemeniz ve gerekirse düzenlemeniz önerilir.
				|Teklif durumunu şimdi değiştirmek ister misiniz?';
				|it = '""%1"" è il documento di base per i seguenti documenti: .%2.
				|Si consiglia di rivedere questi documenti e di modificarli se necessario.
				|Desideri modificare lo stato del preventivo ora?';
				|de = '""%1"" ist das Basisdokument für die folgenden Dokumenten: %2.
				|Es ist empfehlenswert siede Dokumente anzuschauen und ggf. zu bearbeiten.
				|Möchten Sie jetzt den Angebotsstatus ändern?'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, Object.Ref, DocsPresentations);
			NotifyDescription = New NotifyDescription("StatusOnChangeEnd", ThisObject);
			
			ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo);
			
			Return;
			
		EndIf;
		
	EndIf;
	
	StatusBeforeChange = Status;
	
EndProcedure

#EndRegion

#Region InventoryFormTableItemsEventHandlers

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	// Bundles
	InventoryLine = Object.Inventory.FindByID(SelectedRow);
	If Not ReadOnly And ValueIsFilled(InventoryLine.BundleProduct)
		And (Item.CurrentItem = Items.InventoryProducts
			Or Item.CurrentItem = Items.InventoryCharacteristic
			Or Item.CurrentItem = Items.InventoryQuantity
			Or Item.CurrentItem = Items.InventoryMeasurementUnit
			Or Item.CurrentItem = Items.InventoryBundlePicture) Then
			
		StandardProcessing = False;
		EditBundlesComponents(InventoryLine);
		
	// End Bundles
	
	// AutomaticDiscounts
	ElsIf Item.CurrentItem = Items.InventoryAutomaticDiscountPercent
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient()
		
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure InventoryOnActivateRow(Item)
	
	InventoryRowIsSelected = Not Items.Inventory.CurrentRow = Undefined;
	
	Items.InventoryMoveUp.Enabled = InventoryRowIsSelected;
	Items.InventoryMoveDown.Enabled = InventoryRowIsSelected;
	Items.InventorySortAscending.Enabled = InventoryRowIsSelected;
	Items.InventorySortDescending.Enabled = InventoryRowIsSelected;
	Items.InventoryContextMenuMoveUp.Enabled = InventoryRowIsSelected;
	Items.InventoryContextMenuMoveDown.Enabled = InventoryRowIsSelected;
	
EndProcedure

&AtClient
Procedure InventoryBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	// Bundles
	If Clone Then
		
		If ValueIsFilled(Item.CurrentData.BundleProduct) Then
			Cancel = True;
		EndIf;
		
	EndIf;
	// End Bundles
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Bundles
	FilterStructure = New Structure;
	FilterStructure.Insert("Variant", CurrentVariant);
	AllVariantRows = Object.Inventory.FindRows(FilterStructure);
	
	If Items.Inventory.SelectedRows.Count() = AllVariantRows.Count() Then
		
		RowsToDelete = Object.AddedBundles.FindRows(FilterStructure);
		For Each RowToDelete In RowsToDelete Do
			Object.AddedBundles.Delete(RowToDelete);
		EndDo;
		
		SetBundlePictureVisible();
		
	Else
		
		BundleData = New Structure("BundleProduct, BundleCharacteristic");
		
		For Each SelectedRow In Items.Inventory.SelectedRows Do
			
			SelectedRowData = Items.Inventory.RowData(SelectedRow);
			
			If BundleData.BundleProduct = Undefined Then
				
				BundleData.BundleProduct = SelectedRowData.BundleProduct;
				BundleData.BundleCharacteristic = SelectedRowData.BundleCharacteristic;
				
			ElsIf BundleData.BundleProduct <> SelectedRowData.BundleProduct
				Or BundleData.BundleCharacteristic <> SelectedRowData.BundleCharacteristic Then
				
				CommonClientServer.MessageToUser(
					NStr("en = 'Action is unavailable for bundles.'; ru = 'Это действие не доступно для наборов.';pl = 'Działanie nie jest dostępne dla zestawów.';es_ES = 'La acción no está disponible para los paquetes.';es_CO = 'La acción no está disponible para los paquetes.';tr = 'Bu işlem setler için kullanılamaz.';it = 'Azione non disponibile per kit di prodotti.';de = 'Für Bündel ist die Aktion nicht verfügbar.'"),,
					"Object.Inventory",,
					Cancel);
				Break;
				
			EndIf;
			
		EndDo;
		
		If Not Cancel And ValueIsFilled(BundleData.BundleProduct) Then
			
			Cancel = True;
			BundleData.Insert("Variant", CurrentVariant);
			AddedBundles = Object.AddedBundles.FindRows(BundleData);
			Notification = New NotifyDescription("InventoryBeforeDeleteRowEnd", ThisObject, BundleData);
			ButtonsList = New ValueList;
			
			If AddedBundles.Count() > 0 And AddedBundles[0].Quantity > 1 Then
				
				QuestionText = BundlesClient.QuestionTextSeveralBundles();
				ButtonsList.Add(DialogReturnCode.Yes,	BundlesClient.AnswerDeleteAllBundles());
				ButtonsList.Add("DeleteOne",			BundlesClient.AnswerReduceQuantity());
				
			Else
				
				QuestionText = BundlesClient.QuestionTextOneBundle();
				ButtonsList.Add(DialogReturnCode.Yes,	BundlesClient.AswerDeleteAllComponents());
				
			EndIf;
			
			ButtonsList.Add(DialogReturnCode.No, BundlesClient.AswerChangeComponents());
			ButtonsList.Add(DialogReturnCode.Cancel);
			
			ShowQueryBox(Notification, QuestionText, ButtonsList, 0, DialogReturnCode.Yes);
			
		EndIf;
		
	EndIf;
	// End Bundles
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		InventoryRow = Item.CurrentData;
		
		If Copy Then
			InventoryRow.AutomaticDiscountsPercent = 0;
			InventoryRow.AutomaticDiscountAmount = 0;
			CalculateAmountInTabularSectionLine();
		EndIf;
		
		InventoryRow.Variant = CurrentVariant;
		
		FillInventoryRelativeLineNumbers();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculateSalesTax();
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();

EndProcedure

&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	RecalculateSalesTax();
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
	FillInventoryRelativeLineNumbers();
	
EndProcedure

&AtClient
Procedure InventoryDragEnd(Item, DragParameters, StandardProcessing)
	
	FillInventoryRelativeLineNumbers();
	
EndProcedure

&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Inventory", TabularSectionRow);
	
	StructureData.Insert("Company", 			Object.Company);
	StructureData.Insert("ProcessingDate",		Object.Date);
	StructureData.Insert("PriceKind",			Object.PriceKind);
	StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	StructureData.Insert("Products",			TabularSectionRow.Products);
	StructureData.Insert("Characteristic",		TabularSectionRow.Characteristic);
	StructureData.Insert("Factor",				1);
	StructureData.Insert("VATTaxation",			Object.VATTaxation);
	StructureData.Insert("DiscountMarkupKind",	Object.DiscountMarkupKind);
	StructureData.Insert("Taxable",				TabularSectionRow.Taxable);
		
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	// End DiscountCards
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	// Bundles
	If StructureData.IsBundle And Not StructureData.UseCharacteristics Then
		
		ReplaceInventoryLineWithBundleData(ThisObject, TabularSectionRow, StructureData);
		ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
		RecalculateSubtotal();
		FillInventoryRelativeLineNumbers();
		
	Else
	// End Bundles
	
		TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
		TabularSectionRow.Quantity = 1;
		TabularSectionRow.Price = StructureData.Price;
		TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
		TabularSectionRow.VATRate = StructureData.VATRate;
		TabularSectionRow.Content = "";
		TabularSectionRow.Taxable = StructureData.Taxable;
		
		CalculateAmountInTabularSectionLine();
	
	// Bundles
	EndIf;
	// End Bundles
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	
	StructureData.Insert("Company", 			Object.Company);
	StructureData.Insert("ProcessingDate",		Object.Date);
	StructureData.Insert("PriceKind",			Object.PriceKind);
	StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	
	StructureData.Insert("VATRate",			TabularSectionRow.VATRate);
	StructureData.Insert("Products",		TabularSectionRow.Products);
	StructureData.Insert("Characteristic",	TabularSectionRow.Characteristic);
	StructureData.Insert("MeasurementUnit",	TabularSectionRow.MeasurementUnit);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	// Bundles
	If StructureData.IsBundle Then
		
		ReplaceInventoryLineWithBundleData(ThisObject, TabularSectionRow, StructureData);
		ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
		RecalculateSubtotal();
		FillInventoryRelativeLineNumbers();
		
	Else
	// End Bundles
	
		TabularSectionRow.Price = StructureData.Price;
		TabularSectionRow.Content = "";
		CalculateAmountInTabularSectionLine();
	
	// Bundles
	EndIf;
	// End Bundles
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicAutoComplete(Item, Text, ChoiceData, DataGetParameters, Wait, StandardProcessing)
	
	// Bundles
	CurrentRow = Items.Inventory.CurrentData;
	
	If CurrentRow.IsBundle Then
		
		StandardProcessing = False;
		ChoiceData = BundleCharacteristics(CurrentRow.Products, Text);
		
	EndIf;
	// End Bundles
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	// Bundles
	CurrentRow = Items.Inventory.CurrentData;
	
	If CurrentRow.IsBundle Then
		
		StandardProcessing = False;
		
		OpeningStructure = New Structure;
		OpeningStructure.Insert("BundleProduct",	CurrentRow.Products);
		OpeningStructure.Insert("ChoiceMode",		True);
		OpeningStructure.Insert("CloseOnChoice",	True);
		
		OpenForm("InformationRegister.BundlesComponents.Form.ChangeComponentsOfTheBundle",
			OpeningStructure,
			Item,
			, , , ,
			FormWindowOpeningMode.LockOwnerWindow);
		
	// End Bundles
	
	ElsIf DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "Inventory";
		SelectionMarker		= "Inventory";
		SelectionParameters	= DriveClient.GetMatrixParameters(ThisObject, TabularSectionName, True, CurrentVariant);
		NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseVariantsSelection", ThisObject);
		OpenForm("Catalog.ProductsCharacteristics.Form.MatrixFormWithAvailableQuantity",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

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

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

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
	
	CalculateAmountInTabularSectionLine();
	
	TabularSectionRow.MeasurementUnit = ValueSelected;
	
EndProcedure

&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure InventoryDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	// Discount.
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Price = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / ((1 - TabularSectionRow.DiscountMarkupPercent / 100) * TabularSectionRow.Quantity);
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculateSalesTax();
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", ThisObject.CurrentItem.CurrentItem.Name);
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

#EndRegion

#Region PaymentCalendarFormTableItemsEventHandlers

&AtClient
Procedure PaymentCalendarBeforeDelete(Item, Cancel)
	
	If Object.PaymentCalendar.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		CurrentRow = Items.PaymentCalendar.CurrentData;
		
		Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
		
		CurrentRow.PaymentAmount = Round(Totals.Amount * CurrentRow.PaymentPercentage / 100, 2, 1);
		CurrentRow.PaymentVATAmount = Round(Totals.VATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListPaymentCalendarPaymentBaselineDateOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	CurrentRow.PaymentTerm = GetPaymentTermByBaselineDate(CurrentRow.PaymentBaselineDate);
	
EndProcedure

&AtClient
Procedure ListPaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
	
	CurrentRow.PaymentAmount = Round(Totals.Amount * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(Totals.VATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure ListPaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
	
	If Totals.Amount = 0 Then
		CurrentRow.PaymentPercentage	= 0;
		CurrentRow.PaymentVATAmount		= 0;
	Else
		CurrentRow.PaymentPercentage	= Round(CurrentRow.PaymentAmount / Totals.Amount * 100, 2, 1);
		CurrentRow.PaymentVATAmount		= Round(Totals.VATAmount * CurrentRow.PaymentAmount / Totals.Amount, 2, 1);
	EndIf;
	
EndProcedure

&AtClient
Procedure ListPaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	
	Totals = PaymentTermsClientServer.CalculateDocumentAmountVATAmountTotals(Object);
	
	If PaymentCalendarTotal > Totals.VATAmount Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - Totals.VATAmount);
	EndIf;

EndProcedure

#EndRegion

#Region FormItemEventHandlersFormSalesTax

&AtClient
Procedure SalesTaxSalesTaxRateOnChange(Item)
	
	SalesTaxTabularRow = Items.SalesTax.CurrentData;
	
	If SalesTaxTabularRow <> Undefined And ValueIsFilled(SalesTaxTabularRow.SalesTaxRate) Then
		
		SalesTaxTabularRow.SalesTaxPercentage = GetSalesTaxPercentage(SalesTaxTabularRow.SalesTaxRate);
		
		CalculateSalesTaxAmount(SalesTaxTabularRow);
		
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SalesTaxSalesTaxPercentageOnChange(Item)
	
	SalesTaxTabularRow = Items.SalesTax.CurrentData;
	
	If SalesTaxTabularRow <> Undefined And ValueIsFilled(SalesTaxTabularRow.SalesTaxRate) Then
		
		CalculateSalesTaxAmount(SalesTaxTabularRow);
		
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SalesTaxAfterDeleteRow(Item)
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

&AtClient
Procedure SalesTaxAmountOnChange(Item)
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CalculateDiscountsMarkups(Command)
	
	If Object.Inventory.Count() = 0 Then
		If Object.DiscountsMarkups.Count() > 0 Then
			Object.DiscountsMarkups.Clear();
		EndIf;
		Return;
	EndIf;
	
	CalculateDiscountsMarkupsClient();
	
EndProcedure

&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en = 'Select a line to get the weight for.'; ru = 'Необходимо выбрать строку, для которой необходимо получить вес.';pl = 'Wybierz wiersz, aby uzyskać wagę.';es_ES = 'Seleccionar una línea para obtener el peso para.';es_CO = 'Seleccionar una línea para obtener el peso para.';tr = 'Ağırlığı alınacak bir satır seçin.';it = 'Selezionare una linea per ottenere il peso.';de = 'Wählen Sie eine Linie aus, für die das Gewicht ermittelt werden soll.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NotifyDescription, UUID);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure

&AtClient
Procedure OpenInformationAboutDiscounts(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient()
	
EndProcedure

&AtClient
Procedure Pick(Command)
	     
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'quotation'; ru = 'коммерческое предложение';pl = 'oferta cenowa';es_ES = 'presupuesto';es_CO = 'presupuesto';tr = 'teklif';it = 'preventivo';de = 'Angebot'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, True, False, True);
	SelectionParameters.Insert("Company", Counterparty);
	
	InvRows = Object.Inventory.FindRows(New Structure("Variant", CurrentVariant));
	SelectionParameters.Insert("TotalItems", InvRows.Count());
	SelectionParameters.Insert("TotalAmount", DocumentTotal);
	
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

&AtClient
Procedure ReadDiscountCardClick(Item)
	
	ParametersStructure = New Structure("Counterparty", Object.Counterparty);
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", ParametersStructure, ThisObject, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);	
	
EndProcedure

&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));
	
EndProcedure

&AtClient
Procedure VariantAdd(Command)
	
	AddVariant();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure VariantSetAsPreferred(Command)
	
	Object.PreferredVariant = CurrentVariant;
	PopulateVariantsList(Items.CurrentVariant.ChoiceList,
		Object.VariantsCount,
		Object.PreferredVariant,
		EditingIsAvailable);
	SetVariantsActionsAvailability();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

&AtClient
Procedure VariantCopy(Command)
	
	CopyVariant();
	
EndProcedure

&AtClient
Procedure VariantDelete(Command)
	
	DeleteVariant();
	
EndProcedure

&AtClient
Procedure InventoryMoveUp(Command)
	InventoryMove(-1);
	FillInventoryRelativeLineNumbers();
EndProcedure

&AtClient
Procedure InventoryMoveDown(Command)
	InventoryMove(1);
	FillInventoryRelativeLineNumbers();
EndProcedure

&AtClient
Procedure InventorySortAscending(Command)
	InventorySort("Asc");
	FillInventoryRelativeLineNumbers();
EndProcedure

&AtClient
Procedure InventorySortDescending(Command)
	InventorySort("Desc");
	FillInventoryRelativeLineNumbers();
EndProcedure

&AtClient
Procedure UpdateCounterpartySegments(Command)

	ClearMessages();
	ExecutionResult = GenerateCounterpartySegmentsAtServer();
	If Not ExecutionResult.Status = "Completed" Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure FillSalesTax(Command)
	
	RecalculateSalesTax();
	
EndProcedure

#EndRegion

#Region Private

#Region Other

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	//InventoryAmount
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Inventory.DiscountMarkupPercent");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= 100;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("MarkIncomplete", False);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("InventoryAmount");
	FieldAppearance.Use = True;
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	PerInvoiceVATRoundingRule = AccountingPolicy.PerInvoiceVATRoundingRule;
	RegisteredForSalesTax = AccountingPolicy.RegisteredForSalesTax;
	
EndProcedure

&AtServer
Procedure SetAutomaticVATCalculation()
	
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
	
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
		
		If Not TaxationBeforeChange = Object.VATTaxation Then
			FillVATRateByVATTaxation();
		EndIf;
		
	EndIf;
	
EndProcedure

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
			
		EndDo;	
		
	EndIf;	
	
EndProcedure

&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	CurrencyRateRepetition = StructureData.CurrencyRateRepetition;
	SettlementsCurrencyRateRepetition = StructureData.SettlementsCurrencyRateRepetition;

	NewExchangeRate = ?(CurrencyRateRepetition.Rate = 0, 1, CurrencyRateRepetition.Rate);
	NewRatio = ?(CurrencyRateRepetition.Repetition = 0, 1, CurrencyRateRepetition.Repetition);
	
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
		
		QuestionParameters = New Structure;
		QuestionParameters.Insert("NewExchangeRate", NewExchangeRate);
		QuestionParameters.Insert("NewRatio", NewRatio);
		QuestionParameters.Insert("NewContractCurrencyExchangeRate",	NewContractCurrencyExchangeRate);
		QuestionParameters.Insert("NewContractCurrencyRatio",			NewContractCurrencyRatio);
		
		NotifyDescription = New NotifyDescription("RecalculatePaymentCurrencyRateConversionFactorEnd",
			ThisObject, 
			QuestionParameters);
		
		MessageText = MessagesToUserClientServer.GetApplyRatesOnNewDateQuestionText();
		
		ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo);
		
		Return;
		
	EndIf;
	
	RecalculatePaymentCurrencyRateConversionFactorFragment()
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export
	
	NewRatio = AdditionalParameters.NewRatio;
	NewExchangeRate = AdditionalParameters.NewExchangeRate;
	
	Response = Result;
	
	If Response = DialogReturnCode.Yes Then
		Object.ExchangeRate = NewExchangeRate;
		Object.Multiplicity = NewRatio;
	EndIf;
	
	RecalculatePaymentCurrencyRateConversionFactorFragment();
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorFragment()
	
	// Generate price and currency label.
	GenerateLabelPricesAndCurrency(ThisObject);
	
EndProcedure

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

&AtServer
Procedure RecalculateSubtotal()
	
	InventoryRowsCount = 0;
	
	If Object.VariantsCount = 0 Then
		InventoryRows = Object.Inventory;
		Table = InventoryRows.Unload();
		SalesTaxTable = Object.SalesTax.Unload();
	Else
		InventoryRows = Object.Inventory.FindRows(New Structure("Variant", CurrentVariant));
		Table = Object.Inventory.Unload(InventoryRows);
		SalesTaxTable = Object.SalesTax.Unload(New Structure("Variant", CurrentVariant));
	EndIf;
	
	InventoryRowsCount = InventoryRows.Count();
	
	Totals = DriveServer.CalculateSubtotal(Table, Object.AmountIncludesVAT, SalesTaxTable);
	FillPropertyValues(ThisObject, Totals);
	FillPropertyValues(Object, Totals);
	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, SalesRep, VATTaxation";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

&AtServerNoContext
Function GetQuotationStatus(QuotationRef)
	
	Return QuotationStatuses.GetQuotationStatus(QuotationRef);
	
EndFunction

#EndRegion

#Region WorkWithSelection

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		NewRow.Variant = CurrentVariant;
		
		// Bundles
		If ImportRow.IsBundle Then
			
			StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Inventory", NewRow);
			
			StructureData.Insert("Company", 						Object.Company);
			StructureData.Insert("ProcessingDate",					Object.Date);
			StructureData.Insert("PriceKind",						Object.PriceKind);
			StructureData.Insert("DocumentCurrency",				Object.DocumentCurrency);
			StructureData.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
			StructureData.Insert("Products",						NewRow.Products);
			StructureData.Insert("Characteristic",					NewRow.Characteristic);
			StructureData.Insert("Factor",							1);
			StructureData.Insert("VATTaxation",						Object.VATTaxation);
			StructureData.Insert("DiscountMarkupKind",				Object.DiscountMarkupKind);
			StructureData.Insert("DiscountCard",					Object.DiscountCard);
			StructureData.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
			
			StructureData = GetDataProductsOnChange(StructureData);
			
			ReplaceInventoryLineWithBundleData(ThisObject, NewRow, StructureData);
			
		EndIf;
		// End Bundles
	EndDo;
	
	// AutomaticDiscounts
	If TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True);
		
			// Cash flow projection
			RecalculateSalesTax();
			PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
			RecalculateSubtotal();
			
			FillInventoryRelativeLineNumbers();
			SetVariantRowFilter();
			
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
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			
			TabularSectionName	= "Inventory";
			
			// Clear inventory
			Filter = New Structure;
			Filter.Insert("Products", ClosingResult.FilterProducts);
			Filter.Insert("Variant", CurrentVariant);
			Filter.Insert("IsBundle", False);
			
			RowsToDelete = Object[TabularSectionName].FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				Object[TabularSectionName].Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True);
			
			RowsToRecalculate = Object[TabularSectionName].FindRows(Filter);
			For Each RowToRecalculate In RowsToRecalculate Do
				CalculateAmountInTabularSectionLine(RowToRecalculate, False);
			EndDo;
			
			RecalculateSalesTax();
			// Payment calendar
			PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
			RecalculateSubtotal();
			
			FillInventoryRelativeLineNumbers();
			SetVariantRowFilter();
			
		EndIf;
		
	EndIf;

EndProcedure

#EndRegion

#Region Header

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange(Object.DocumentCurrency, SettlementsCurrency);
	
	If ValueIsFilled(SettlementsCurrency) Then
		RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
	EndIf;	
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	// Cash flow projection.
	RecalculatePaymentDate();
	RecalculateSubtotal();
	
	// DiscountCards
	// IN this procedure call not modal window of question is occurred.
	RecalculateDiscountPercentAtDocumentDateChange();
	// End DiscountCards
	
	// AutomaticDiscounts
	DocumentDateChangedManually = True;
	ClearCheckboxDiscountsAreCalculatedClient("DateOnChange");
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Function GetDataDateOnChange(DocumentCurrency, SettlementsCurrency)
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, DocumentCurrency, Object.Company);
	
	StructureData = New Structure;
	StructureData.Insert("CurrencyRateRepetition", CurrencyRateRepetition);
	
	If DocumentCurrency <> SettlementsCurrency Then
		
		SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, SettlementsCurrency, Object.Company);
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", SettlementsCurrencyRateRepetition);
		
	Else
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", CurrencyRateRepetition);
		
	EndIf;
	
	SetAccountingPolicyValues();
	FillVATRateByCompanyVATTaxation();
	
	ProcessingCompanyVATNumbers();
	
	FillSalesTaxRate();
	SetVisibleTaxAttributes();
	SetAutomaticVATCalculation();
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	
	StructureData.Insert("ParentCompany", DriveServer.GetCompany(Object.Company));
	StructureData.Insert("BankAccount", Object.Company.BankAccountByDefault);
	StructureData.Insert("BankAccountCashAssetsCurrency", Object.Company.BankAccountByDefault.CashCurrency);
	
	SetAccountingPolicyValues();
	FillVATRateByCompanyVATTaxation();
	
	ProcessingCompanyVATNumbers();
	
	FillSalesTaxRate();
	SetVisibleTaxAttributes();
	SetAutomaticVATCalculation();
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	FillVATRateByCompanyVATTaxation(True);
	FillSalesTaxRate();
	
	StructureData = GetDataContractOnChange(
		Date,
		DocumentCurrency,
		ContractByDefault,
		Company);
	
	StructureData.Insert("Contract", ContractByDefault);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataContractOnChange(Date, DocumentCurrency, Contract, Company)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"SettlementsCurrency",
		Contract.SettlementsCurrency);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, Contract.SettlementsCurrency, Company));
	
	StructureData.Insert(
		"DiscountMarkupKind",
		Contract.DiscountMarkupKind);
	
	StructureData.Insert(
		"PriceKind",
		Contract.PriceKind);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined));
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure CounterpartyOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		DriveClient.RefillTabularSectionPricesByPriceKind(ThisObject, "Inventory", True);
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetContractVisible()
	
	Items.Contract.Visible = CounterpartyAttributes.DoOperationsByContracts;
	
EndProcedure

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company);
	
EndFunction

&AtClient
Procedure ProcessContractChange(StructureData = Undefined)
	
	ContractBeforeChange	= Contract;
	Contract				= Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		If StructureData = Undefined Then
			
			StructureData = GetDataContractOnChange(Object.Date,
				Object.DocumentCurrency,
				Object.Contract,
				Object.Company);
			
		EndIf;
		
		SettlementsCurrency = StructureData.SettlementsCurrency;
		
		If StructureData.AmountIncludesVAT <> Undefined Then
			
			Object.AmountIncludesVAT = StructureData.AmountIncludesVAT;
			
		EndIf;
		
		AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
			Object.DocumentCurrency,
			Object.ExchangeRate,
			Object.Multiplicity);
		
		If ValueIsFilled(Object.Contract) Then 
			Object.ExchangeRate = ?(StructureData.SettlementsCurrencyRateRepetition.Rate = 0,
				1,
				StructureData.SettlementsCurrencyRateRepetition.Rate);
			Object.Multiplicity = ?(StructureData.SettlementsCurrencyRateRepetition.Repetition = 0,
				1,
				StructureData.SettlementsCurrencyRateRepetition.Repetition);
			Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
			Object.ContractCurrencyMultiplicity = Object.Multiplicity;
		EndIf;
		
		PriceKindChanged = (Object.PriceKind <> StructureData.PriceKind And ValueIsFilled(StructureData.PriceKind));
		DiscountKindChanged = (Object.DiscountMarkupKind <> StructureData.DiscountMarkupKind);
		
		Object.DiscountCard = PredefinedValue("Catalog.DiscountCards.EmptyRef");
		Object.DiscountPercentByDiscountCard = 0;
		
		OpenFormPricesAndCurrencies = (ValueIsFilled(Object.Contract)
			And ValueIsFilled(SettlementsCurrency)
			And Object.DocumentCurrency <> StructureData.SettlementsCurrency
			And Object.Inventory.Count() > 0);
		
		QueryPriceKind = (ValueIsFilled(Object.Contract) And (PriceKindChanged Or DiscountKindChanged));
		If QueryPriceKind Then
			If PriceKindChanged Then
				Object.PriceKind = StructureData.PriceKind;
			EndIf;
			If DiscountKindChanged Then
				Object.DiscountMarkupKind = StructureData.DiscountMarkupKind;
			EndIf;
		EndIf;
		
		If Object.DocumentCurrency <> StructureData.SettlementsCurrency Then
			Object.BankAccount = Undefined;
		EndIf;
		
		If ValueIsFilled(SettlementsCurrency) Then
			Object.DocumentCurrency = SettlementsCurrency;
		EndIf;
		
		If OpenFormPricesAndCurrencies Then
			
			WarningText = "";
			If QueryPriceKind Then
				
				WarningText = MessagesToUserClientServer.GetPriceTypeOnChangeWarningText();
				
			EndIf;
			
			WarningText = WarningText
				+ ?(IsBlankString(WarningText), "", Chars.LF + Chars.LF)
				+ MessagesToUserClientServer.GetSettleCurrencyOnChangeWarningText();
			
			ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, True, PriceKindChanged, WarningText);
			
		ElsIf QueryPriceKind Then
			
			GenerateLabelPricesAndCurrency(ThisObject);
			
			If Object.Inventory.Count() > 0 Then
				
				MessageText = NStr("en = 'The price and discount in the contract with counterparty differ from price and discount in the document. 
                                    |Recalculate the document according to the contract?'; 
                                    |ru = 'Договор с контрагентом предусматривает условия цен и скидок, отличные от установленных в документе. 
                                    |Пересчитать документ в соответствии с договором?';
                                    |pl = 'Cena i rabaty w kontrakcie z kontrahentem różnią się od cen i rabatów w dokumencie. 
                                    |Przeliczyć dokument zgodnie z kontraktem?';
                                    |es_ES = 'El precio y descuento en el contrato con la contraparte es diferente del precio y descuento en el documento. 
                                    |¿Recalcular el documento según el contrato?';
                                    |es_CO = 'El precio y descuento en el contrato con la contraparte es diferente del precio y descuento en el documento. 
                                    |¿Recalcular el documento según el contrato?';
                                    |tr = 'Cari hesapla yapılan sözleşmedeki fiyat ve indirim, belgedeki fiyat ve indirimlerden farklıdır.
                                    |Belge sözleşmeye göre yeniden hesaplansın mı?';
                                    |it = 'Il prezzo e lo sconto con la controparte differiscono dal prezzo e lo sconto nel documento.
                                    |Ricalcolare il documento secondo il contratto?';
                                    |de = 'Der Preis und der Rabatt im Vertrag mit dem Geschäftspartner unterscheiden sich von Preis und Rabatt im Beleg.
                                    |Das Dokument gemäß dem Vertrag neu berechnen?'");
				
				NotifyDescription = New NotifyDescription("ProcessContractChangeEnd", ThisObject);
				
				ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo);
				
				Return;
				
			EndIf;
			
		Else
			
			GenerateLabelPricesAndCurrency(ThisObject);
			
		EndIf;
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
		SetVisibleEnablePaymentTermItems();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessContractChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		DriveClient.RefillTabularSectionPricesByPriceKind(ThisObject, "Inventory", True);
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetChoiceFormOfContractParameters(Document, Company, Counterparty, Contract, IsOperationsByContracts)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", IsOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

&AtServerNoContext
Function GetSubordinateDocuments(QuotationRef)
	
	Result = New Array;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	SalesInvoice.Presentation AS DocumentStr
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.BasisDocument = &BasisDocument
	|	AND SalesInvoice.Posted
	|
	|UNION ALL
	|
	|SELECT
	|	SalesOrder.Presentation
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.BasisDocument = &BasisDocument
	|	AND SalesOrder.Posted
	|
	|UNION ALL
	|
	|SELECT
	|	WorkOrder.Presentation
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|WHERE
	|	WorkOrder.BasisDocument = &BasisDocument
	|	AND WorkOrder.Posted";
	
	Query.SetParameter("BasisDocument", QuotationRef);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Result = QueryResult.Unload().UnloadColumn("DocumentStr");
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure StatusOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		StatusBeforeChange = Status;
		
	Else
		
		Status = StatusBeforeChange;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region PricesAndCurrency

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange = Undefined, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	If AttributesBeforeChange = Undefined Then
		AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
			Object.DocumentCurrency,
			Object.ExchangeRate,
			Object.Multiplicity);
	EndIf;
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure();
	
	ParametersStructure.Insert("PriceKind",						Object.PriceKind);
	ParametersStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	ParametersStructure.Insert("Contract",						Object.Contract);
	ParametersStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",					Object.Multiplicity);
	ParametersStructure.Insert("ContractCurrencyExchangeRate",	Object.ContractCurrencyExchangeRate);
	ParametersStructure.Insert("ContractCurrencyMultiplicity",	Object.ContractCurrencyMultiplicity);
	ParametersStructure.Insert("Company",						ParentCompany);
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("RefillPrices",					RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",				RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",				False);
	ParametersStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	ParametersStructure.Insert("DiscountCard",					Object.DiscountCard);
	// DiscountCards
	ParametersStructure.Insert("Counterparty",		Object.Counterparty);
	// End DiscountCards
	ParametersStructure.Insert("WarningText",		WarningText);
	
	If RegisteredForVAT Then
		ParametersStructure.Insert("AutomaticVATCalculation",	Object.AutomaticVATCalculation);
		ParametersStructure.Insert("PerInvoiceVATRoundingRule",	PerInvoiceVATRoundingRule);
		ParametersStructure.Insert("VATTaxation",				Object.VATTaxation);
		ParametersStructure.Insert("AmountIncludesVAT",			Object.AmountIncludesVAT);
	EndIf;
	
	If RegisteredForSalesTax Then
		ParametersStructure.Insert("SalesTaxRate",			Object.SalesTaxRate);
		ParametersStructure.Insert("SalesTaxPercentage",	Object.SalesTaxPercentage);
	EndIf;
	
	NotifyDescription = New NotifyDescription("ProcessChangesOnButtonPricesAndCurrenciesEnd",
		ThisObject,
		AttributesBeforeChange);
	
	OpenForm("CommonForm.PricesAndCurrency",
		ParametersStructure,
		ThisObject,,,,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrenciesEnd(ClosingResult, AdditionalParameters) Export
	
	// 3. Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
	If TypeOf(ClosingResult) = Type("Structure") AND ClosingResult.WereMadeChanges Then
		
		If Object.DocumentCurrency <> ClosingResult.DocumentCurrency Then
			Object.BankAccount = Undefined;
		EndIf;
		
		Object.PriceKind = ClosingResult.PriceKind;
		Object.DiscountMarkupKind = ClosingResult.DiscountKind;
		// DiscountCards
		If ValueIsFilled(ClosingResult.DiscountCard) AND ValueIsFilled(ClosingResult.Counterparty) AND Not Object.Counterparty.IsEmpty() Then
			If ClosingResult.Counterparty = Object.Counterparty Then
				Object.DiscountCard = ClosingResult.DiscountCard;
				Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
			Else // We will show the message and we will not change discount card data.
				CommonClientServer.MessageToUser(
					DiscountCardsClient.GetDiscountCardInapplicableMessage(),
					,
					"Counterparty",
					"Object");
			EndIf;
		Else
			Object.DiscountCard = ClosingResult.DiscountCard;
			Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
		EndIf;
		// End DiscountCards
		
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
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisObject, "Inventory", True);
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			  AND ClosingResult.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Inventory", PricesPrecision);
		EndIf;
		
		// VAT
		If RegisteredForVAT Then
			
			Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
			Object.VATTaxation = ClosingResult.VATTaxation;
			Object.AutomaticVATCalculation = ClosingResult.AutomaticVATCalculation;
			
			// Recalculate the amount if VAT taxation flag is changed.
			If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
				FillVATRateByVATTaxation();
			EndIf;
			
			// Recalculate the amount if the "Amount includes VAT" flag is changed.
			If Not ClosingResult.RefillPrices
				AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
				DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Inventory", PricesPrecision);
			EndIf;
			
		EndIf;
		
		// Sales tax
		If RegisteredForSalesTax Then
			
			Object.SalesTaxRate = ClosingResult.SalesTaxRate;
			Object.SalesTaxPercentage = ClosingResult.SalesTaxPercentage;
			
			If ClosingResult.SalesTaxRate <> ClosingResult.PrevSalesTaxRate
				OR ClosingResult.SalesTaxPercentage <> ClosingResult.PrevSalesTaxPercentage Then
				
				RecalculateSalesTax();
				
			EndIf;
			
		EndIf;
		
		SetVisibleTaxAttributes();
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts OR ClosingResult.RefillPrices OR ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;
		
		Modified = True;
		
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
		
	EndIf;
	
	GenerateLabelPricesAndCurrency(ThisObject);		
	
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateLabelPricesAndCurrency(Form)
	
	Object = Form.Object;
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Form.SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		Form.ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			Form.RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				Form.RegisteredForVAT);
	LabelStructure.Insert("RegisteredForSalesTax",			Form.RegisteredForSalesTax);
	LabelStructure.Insert("SalesTaxRate",					Object.SalesTaxRate);
	
	Form.PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileInventory(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"Quote.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import inventory from file'; ru = 'Загрузка запасов из файла';pl = 'Import zapasów z pliku';es_ES = 'Importar el inventario del archivo';es_CO = 'Importar el inventario del archivo';tr = 'Stoku dosyadan içe aktar';it = 'Importazione delle scorte da file';de = 'Bestand aus Datei importieren'"));
	
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

#Region StandardSubsystemsProperties

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

#Region Inventory

&AtClientAtServerNoContext
Function CreateGeneralAttributeValuesStructure(Form, TabName, TabRow)
	
	Object = Form.Object;
	
	StructureData = New Structure("
	|TabName,
	|Object,
	|Company,
	|Products,
	|Characteristic,
	|VATTaxation,
	|UseDefaultTypeOfAccounting,
	|IncomeAndExpenseItems,
	|IncomeAndExpenseItemsFilled,
	|RevenueItem");
	
	FillPropertyValues(StructureData, Form);
	FillPropertyValues(StructureData, Object);
	FillPropertyValues(StructureData, TabRow);
	
	StructureData.Insert("TabName", TabName);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products, "MeasurementUnit, VATRate");
	
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
	
	If StructureData.Property("Taxable") Then
		StructureData.Insert("Taxable", StructureData.Products.Taxable);
	EndIf;
	
	If StructureData.Property("PriceKind") Then
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
	Else
		StructureData.Insert("Price", 0);
	EndIf;
	
	If StructureData.Property("DiscountMarkupKind") 
		AND ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupPercent", 
			Common.ObjectAttributeValue(StructureData.DiscountMarkupKind, "Percent"));
	Else	
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
		
	If StructureData.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(StructureData.DiscountCard) Then
		CurPercent = StructureData.DiscountMarkupPercent;
		StructureData.Insert("DiscountMarkupPercent", CurPercent + StructureData.DiscountPercentByDiscountCard);
	EndIf;
	
	// Bundles
	BundlesServer.AddBundleInformationOnGetProductsData(StructureData);
	// End Bundles
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
	EndIf;
	
	Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
	StructureData.Insert("Price", Price);
	
	// Bundles
	BundlesServer.AddBundleInformationOnGetProductsData(StructureData);
	// End Bundles
	
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
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  TabularSectionRow.Amount * VATRate / 100);
	
EndProcedure

&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined, RecalcSalesTax = True)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Amount = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0
			AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// AutomaticDiscounts.
	AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
	If RecalcSalesTax Then
		RecalculateSalesTax();
	EndIf;
	
	RecalculateSubtotal();
	
EndProcedure

&AtServer
Procedure InventoryMove(Offset)
	
	SelectedRowsCount = Items.Inventory.SelectedRows.Count();
	
	If SelectedRowsCount = 0 Then
		Return;
	EndIf;
	
	If Offset > 0 Then
		BoundaryRowID = Items.Inventory.SelectedRows[SelectedRowsCount - 1];
	Else
		BoundaryRowID = Items.Inventory.SelectedRows[0];
	EndIf;
	BoundaryRow = Object.Inventory.FindByID(BoundaryRowID);
	
	NextRow = Undefined;
	
	Rows = Object.Inventory.FindRows(
		New Structure(
			"Variant, RelativeLineNumber",
			CurrentVariant,
			BoundaryRow.RelativeLineNumber + Offset));
			
	If Rows.Count() <> 0 Then
		NextRow = Rows[0];
	EndIf;
	
	If NextRow = Undefined Then
		Return;
	EndIf;
	
	If Offset > 0 Then
		Index = SelectedRowsCount -1 
	Else
		Index = 0;
	EndIf;
	While Index >= 0 And Index < SelectedRowsCount Do
		RowID = Items.Inventory.SelectedRows[Index];
		InventoryRow = Object.Inventory.FindByID(RowID);
		Object.Inventory.Move(Object.Inventory.IndexOf(InventoryRow), NextRow.LineNumber - InventoryRow.LineNumber);
		Index = Index - Offset;
	EndDo;
	
EndProcedure

&AtServer
Procedure InventorySort(Direction)
	
	InventoryCurrentItem = Items.Inventory.CurrentItem;
	
	If InventoryCurrentItem = Items.InventoryRelativeLineNumber Then
		Return;
	EndIf;
	
	ColumnName = StrReplace(InventoryCurrentItem.DataPath, "Object.Inventory.", "");
	
	Object.Inventory.Sort(ColumnName + " " + Direction);
	
EndProcedure

#EndRegion

#Region PaymentCalendar

&AtClient
Procedure RecalculatePaymentDate()
	
	If Object.SetPaymentTerms Then
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
		SetVisibleEnablePaymentTermItems();
		
		If ValueIsFilled(Object.Ref) Then
			MessageString = NStr("en = 'Payment terms have been changed'; ru = 'Условия оплаты изменены';pl = 'Warunki płatności zostały zmienione';es_ES = 'Se han cambiado las condiciones de pago';es_CO = 'Se han cambiado las condiciones de pago';tr = 'Ödeme şartları değiştirildi';it = 'I termini di pagamento sono stati modificati';de = 'Zahlungsbedingungen wurden geändert'");
			CommonClientServer.MessageToUser(MessageString);
		EndIf;
		
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

&AtClient
Procedure SetEditInListFragmentOption()
	
	If SwitchTypeListOfPaymentCalendar Then
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupPaymentCalendarList;
	Else
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupBillingCalendarString;
	EndIf;

EndProcedure

&AtServer
Procedure FillPaymentCalendar(TypeListOfPaymentCalendar, IsEnabledManually = False)
	
	PaymentTermsServer.FillPaymentCalendarFromContract(Object, IsEnabledManually);
	
	TypeListOfPaymentCalendar = Number(Object.PaymentCalendar.Count() > 1);
	Modified = True;
	
EndProcedure

&AtClient
Procedure SetVisibleEnablePaymentTermItems()
	
	SetEnableGroupPaymentCalendarDetails();
	SetEditInListFragmentOption();
	SetVisiblePaymentMethod();
	
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
Procedure SetEnableGroupPaymentCalendarDetails()
	
	Items.SwitchTypeListOfPaymentCalendar.Enabled = Object.SetPaymentTerms;
	Items.GroupPaymentMethod.Enabled = Object.SetPaymentTerms;
	Items.GroupPaymentCalendarListString.Enabled = Object.SetPaymentTerms;
	
EndProcedure

&AtServer
Procedure SetSwitchTypeListOfPaymentCalendar()
	
	If Object.PaymentCalendar.Count() > 1 Then
		SwitchTypeListOfPaymentCalendar = 1;
	Else
		SwitchTypeListOfPaymentCalendar = 0;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetPaymentTermByBaselineDate(BaselineDate)
	Return PaymentTermsServer.GetPaymentTermByBaselineDate(BaselineDate);	
EndFunction

#EndRegion

#Region BarcodesAndPeripherals

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
		   AND BarcodeData.Count() <> 0 Then
			
			StructureProductsData = New Structure();
			StructureProductsData.Insert("Company", StructureData.Company);
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsData.Insert("VATTaxation", StructureData.VATTaxation);
			If ValueIsFilled(StructureData.PriceKind) Then
				StructureProductsData.Insert("ProcessingDate", StructureData.Date);
				StructureProductsData.Insert("DocumentCurrency", StructureData.DocumentCurrency);
				StructureProductsData.Insert("AmountIncludesVAT", StructureData.AmountIncludesVAT);
				StructureProductsData.Insert("PriceKind", StructureData.PriceKind);
				If ValueIsFilled(BarcodeData.MeasurementUnit)
					AND TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
					StructureProductsData.Insert("Factor", BarcodeData.MeasurementUnit.Factor);
				Else
					StructureProductsData.Insert("Factor", 1);
				EndIf;
				StructureProductsData.Insert("DiscountMarkupKind", StructureData.DiscountMarkupKind);
			EndIf;
			
			// DiscountCards
			StructureProductsData.Insert("DiscountPercentByDiscountCard", StructureData.DiscountPercentByDiscountCard);
			StructureProductsData.Insert("DiscountCard", StructureData.DiscountCard);
			// End DiscountCards
			
			BarcodeData.Insert("StructureProductsData", GetDataProductsOnChange(StructureProductsData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.Products.MeasurementUnit;
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
	StructureData.Insert("PriceKind", Object.PriceKind);
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	// DiscountCards
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	// End DiscountCards
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			FilterParameters = New Structure;
			FilterParameters.Insert("Products", BarcodeData.Products);
			FilterParameters.Insert("Characteristic", BarcodeData.Characteristic);
			FilterParameters.Insert("MeasurementUnit", BarcodeData.MeasurementUnit);
			FilterParameters.Insert("Variant", CurrentVariant);
			// Bundles
			FilterParameters.Insert("BundleProduct", PredefinedValue("Catalog.Products.EmptyRef"));
			// End Bundles
			TSRowsArray = Object.Inventory.FindRows(FilterParameters);
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.Variant = CurrentVariant;
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsData.Price;
				NewRow.DiscountMarkupPercent = BarcodeData.StructureProductsData.DiscountMarkupPercent;
				NewRow.VATRate = BarcodeData.StructureProductsData.VATRate;
				NewCurrentRow = NewRow.GetID();
				// Bundles
				If BarcodeData.StructureProductsData.IsBundle Then
					ReplaceInventoryLineWithBundleData(ThisObject, NewRow, BarcodeData.StructureProductsData);
				Else
				// End Bundles
					CalculateAmountInTabularSectionLine(NewRow);
				EndIf;
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(FoundString);
				NewCurrentRow= FoundString.GetID();
			EndIf;
		EndIf;
	EndDo;
	
	FillInventoryRelativeLineNumbers();
	SetVariantRowFilter();
	
	Items.Inventory.CurrentRow = NewCurrentRow;
	
	Return UnknownBarcodes;

EndFunction

&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	Modified = True;
	
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
		
		MessageString = NStr("en = 'Barcode is not found: %1%; quantity: %2%'; ru = 'Данные по штрихкоду не найдены: %1%; количество: %2%';pl = 'Kod kreskowy nie został znaleziony: %1%; ilość: %2%';es_ES = 'Código de barras no encontrado: %1%; cantidad: %2%';es_CO = 'Código de barras no encontrado: %1%; cantidad: %2%';tr = 'Barkod bulunamadı: %1%; miktar: %2%';it = 'Il codice a barre non è stato trovato: %1%; quantità:%2%';de = 'Barcode wird nicht gefunden: %1%; Menge: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
		
		// Cash flow projection.
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
		
		Modified = True;
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
			PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
			RecalculateSubtotal();
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

#EndRegion

#Region DiscountCards

&AtClient
Procedure ReadDiscountCardClickEnd(ReturnParameters, Parameters) Export

	If TypeOf(ReturnParameters) = Type("Structure") Then
		DiscountCardRead = ReturnParameters.DiscountCardRead;
		DiscountCardIsSelected(ReturnParameters.DiscountCard);
	EndIf;

EndProcedure

&AtClient
Procedure DiscountCardIsSelected(DiscountCard)

	DiscountCardOwner = GetDiscountCardOwner(DiscountCard);
	If Object.Counterparty.IsEmpty() AND Not DiscountCardOwner.IsEmpty() Then
		Object.Counterparty = DiscountCardOwner;
		CounterpartyOnChange(Items.Counterparty);
		
		ShowUserNotification(
			NStr("en = 'Counterparty is filled in and discount card is read'; ru = 'Заполнен контрагент и считана дисконтная карта';pl = 'Kontrahent wypełniony, karta rabatowa sczytana';es_ES = 'Contraparte de ha rellenado y la tarjeta de descuento se ha leído';es_CO = 'Contraparte de ha rellenado y la tarjeta de descuento se ha leído';tr = 'Cari hesap dolduruldu ve indirim kartı okundu';it = 'La controparte è stata compilata e la carta sconto è stata letta';de = 'Der Geschäftspartner ist ausgefüllt und die Rabattkarte wird gelesen'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The counterparty is filled out in the document and discount card %1 is read'; ru = 'В документе заполнен контрагент и считана дисконтная карта %1';pl = 'W dokumencie wskazano kontrahenta, karta rabatowa %1 została sczytana';es_ES = 'La contraparte se ha rellenado en el documento y la tarjeta de descuento %1 se ha leído';es_CO = 'La contraparte se ha rellenado en el documento y la tarjeta de descuento %1 se ha leído';tr = 'Belgede cari hesap dolduruldu ve %1 indirim kartı okundu';it = 'La controparte è stata compilata nel documento e carta sconto %1 è stata letta';de = 'Der Geschäftspartner wird im Dokument ausgefüllt und die Rabattkarte %1 wird gelesen'"), DiscountCard),
			PictureLib.Information32);
	ElsIf Object.Counterparty <> DiscountCardOwner AND Not DiscountCardOwner.IsEmpty() Then
		
		CommonClientServer.MessageToUser(
			DiscountCardsClient.GetDiscountCardInapplicableMessage(),
			,
			"Counterparty",
			"Object");
		
		Return;
	Else
		ShowUserNotification(
			NStr("en = 'Discount card is read'; ru = 'Считана дисконтная карта';pl = 'Karta rabatowa została sczytana';es_ES = 'Tarjeta de descuento se ha leído';es_CO = 'Tarjeta de descuento se ha leído';tr = 'İndirim kartı okundu';it = 'La carta sconto è stata letta';de = 'Rabattkarte wird gelesen'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Discount card %1 is read'; ru = 'Считана дисконтная карта %1';pl = 'Karta rabatowa %1 została sczytana';es_ES = 'Tarjeta de descuento %1 se ha leído';es_CO = 'Tarjeta de descuento %1 se ha leído';tr = 'İndirim kartı %1 okundu';it = 'Letta Carta sconti %1';de = 'Rabattkarte %1 wird gelesen'"), DiscountCard),
			PictureLib.Information32);
	EndIf;
	
	DiscountCardIsSelectedAdditionally(DiscountCard);
		
EndProcedure

&AtClient
Procedure DiscountCardIsSelectedAdditionally(DiscountCard)
	
	If Not Modified Then
		Modified = True;
	EndIf;
	
	Object.DiscountCard = DiscountCard;
	Object.DiscountPercentByDiscountCard = DriveServer.CalculateDiscountPercentByDiscountCard(Object.Date, DiscountCard);
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	If Object.Inventory.Count() > 0 Then
		Text = NStr("en = 'Should we recalculate discounts in all lines?'; ru = 'Перезаполнить скидки во всех строках?';pl = 'Czy powinniśmy obliczyć zniżki we wszystkich wierszach?';es_ES = '¿Hay que recalcular los descuentos en todas las líneas?';es_CO = '¿Hay que recalcular los descuentos en todas las líneas?';tr = 'Tüm satırlarda indirimler yeniden hesaplansın mı?';it = 'Dobbiamo ricalcolare gli sconti in tutte le linee?';de = 'Sollten wir Rabatte in allen Zeilen neu berechnen?'");
		Notification = New NotifyDescription("DiscountCardIsSelectedAdditionallyEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

&AtClient
Procedure DiscountCardIsSelectedAdditionallyEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisObject, "Inventory");
	EndIf;
	
	RecalculateSalesTax();
	// Cash flow projection.
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("DiscountRecalculationByDiscountCard");
	
EndProcedure

&AtServerNoContext
Function GetDiscountCardOwner(DiscountCard)
	
	Return DiscountCard.CardOwner;
	
EndFunction

&AtServerNoContext
Function ThisDiscountCardWithFixedDiscount(DiscountCard)
	
	Return DiscountCard.Owner.DiscountKindForDiscountCards = Enums.DiscountTypeForDiscountCards.FixedDiscount;
	
EndFunction

&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChange()
	
	If Object.DiscountCard.IsEmpty() OR ThisDiscountCardWithFixedDiscount(Object.DiscountCard) Then
		Return;
	EndIf;
	
	PreDiscountPercentByDiscountCard = Object.DiscountPercentByDiscountCard;
	NewDiscountPercentByDiscountCard = DriveServer.CalculateDiscountPercentByDiscountCard(Object.Date, Object.DiscountCard);
	
	If PreDiscountPercentByDiscountCard <> NewDiscountPercentByDiscountCard Then
		
		If Object.Inventory.Count() > 0 Then
			
			Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Do you want to change the discount rate from %1% to %2% and apply to the document?'; ru = 'Процент скидки карты изменится с %1% на %2% и будет перезаполнен в документе. Продолжить?';pl = 'Zmienić stawkę rabatową z %1% na %2% i zastosować w dokumencie?';es_ES = '¿Quiere cambiar el tipo de descuento de %1% a %2% y aplicar en el documento?';es_CO = '¿Quiere cambiar el tipo de descuento de %1% a %2% y aplicar en el documento?';tr = 'İndirim oranını %1%''den %2%''ye değiştirmek ve dokümana uygulamak ister misiniz?';it = 'Volete cambiare la percentuale di sconto da %1% a %2% ed applicarla al documento?';de = 'Möchten Sie den Diskontsatz von %1% in %2% ändern und auf das Dokument anwenden?'"),
				PreDiscountPercentByDiscountCard,
				NewDiscountPercentByDiscountCard);
			AdditionalParameters	= New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, True);
			Notification			= New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
			
		Else
			
			Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Do you want to change the discount rate from %1% to %2%?'; ru = 'Изменить процент скидки карты с %1% на %2%?';pl = 'Zmienić stawkę rabatu z %1% na %2%?';es_ES = '¿Quiere cambiar el tipo de descuento de %1% a %2%?';es_CO = '¿Quiere cambiar el tipo de descuento de %1% a %2%?';tr = 'İndirim oranını %1%''den %2%''ye değiştirmek ister misiniz?';it = 'Volete cambiare la percentuale di sconto da %1% a %2%?';de = 'Möchten Sie den Diskontsatz von %1% in %2% ändern?'"),
				PreDiscountPercentByDiscountCard,
				NewDiscountPercentByDiscountCard);
			AdditionalParameters	= New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, False);
			Notification			= New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
			
		EndIf;
		
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChangeEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		Object.DiscountPercentByDiscountCard = AdditionalParameters.NewDiscountPercentByDiscountCard;
		
		GenerateLabelPricesAndCurrency(ThisObject);
		
		If AdditionalParameters.RecalculateTP Then
			DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisObject, "Inventory");
			
			RecalculateSalesTax();
			// Cash flow projection.
			PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
			RecalculateSubtotal();
		EndIf;
				
	EndIf;
	
EndProcedure

#EndRegion

#Region AutomaticDiscounts

&AtClient
Procedure CalculateDiscountsMarkupsClient()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
		
EndProcedure

&AtServer
Function DiscountsChanged()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                False);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	
	DiscountsChanged = False;
	
	LineCount = AppliedDiscounts.TableDiscountsMarkups.Count();
	If LineCount <> Object.DiscountsMarkups.Count() Then
		DiscountsChanged = True;
	Else
		
		If Object.Inventory.Total("AutomaticDiscountAmount") <> Object.DiscountsMarkups.Total("Amount") Then
			DiscountsChanged = True;
		EndIf;
		
		If Not DiscountsChanged Then
			For LineNumber = 1 To LineCount Do
				If    Object.DiscountsMarkups[LineNumber-1].Amount <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].Amount
					OR Object.DiscountsMarkups[LineNumber-1].ConnectionKey <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].ConnectionKey
					OR Object.DiscountsMarkups[LineNumber-1].DiscountMarkup <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].DiscountMarkup Then
					DiscountsChanged = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	If DiscountsChanged Then
		AddressDiscountsAppliedInTemporaryStorage = PutToTempStorage(AppliedDiscounts, UUID);
	EndIf;
	
	Return DiscountsChanged;
	
EndFunction

&AtServer
Procedure CalculateDiscountsMarkupsOnServer(ParameterStructure)
	
	AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	
	AddressDiscountsAppliedInTemporaryStorage = PutToTempStorage(AppliedDiscounts, UUID);
	
	Modified = True;
	
	DiscountsMarkupsServerOverridable.UpdateDiscountDisplay(Object, "Inventory");
	
	If Not Object.DiscountsAreCalculated Then
	
		Object.DiscountsAreCalculated = True;
	
	EndIf;
	
	Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
	
	ThereAreManualDiscounts = Constants.UseManualDiscounts.Get();
	For Each CurrentRow In Object.Inventory Do
		ManualDiscountCurAmount = ?(ThereAreManualDiscounts, CurrentRow.Price * CurrentRow.Quantity * CurrentRow.DiscountMarkupPercent / 100, 0);
		CurAmountDiscounts = ManualDiscountCurAmount + CurrentRow.AutomaticDiscountAmount;
		If CurAmountDiscounts >= CurrentRow.Amount AND CurrentRow.Price > 0 Then
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = True;
		Else
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = False;
		EndIf;
	EndDo;
	
	RecalculateSubtotal();

EndProcedure

&AtClient
Procedure OpenInformationAboutDiscountsClient()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	ParameterStructure.Insert("OnlyMessagesAfterRegistration",   False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	If Not Object.DiscountsAreCalculated Then
		QuestionText = NStr("en = 'Do you want to apply discounts?'; ru = 'Скидки (наценки) не рассчитаны, рассчитать?';pl = 'Czy chcesz zastosować zniżki?';es_ES = '¿Quiere aplicar los descuentos?';es_CO = '¿Quiere aplicar los descuentos?';tr = 'İndirimleri uygulamak istiyor musunuz?';it = 'Volete applicare gli sconti?';de = 'Möchten Sie Rabatte anwenden?'");
		
		AdditionalParameters = New Structure; 
		AdditionalParameters.Insert("ParameterStructure", ParameterStructure);
		NotificationHandler = New NotifyDescription("NotificationQueryCalculateDiscounts", ThisObject, AdditionalParameters);
		ShowQueryBox(NotificationHandler, QuestionText, QuestionDialogMode.YesNo);
	Else
		CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationQueryCalculateDiscounts(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;
	ParameterStructure = AdditionalParameters.ParameterStructure;
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure);
	
EndProcedure

&AtClient
Procedure CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure)
	
	If Not ValueIsFilled(AddressDiscountsAppliedInTemporaryStorage) Then
		CalculateDiscountsMarkupsClient();
	EndIf;
	
	CurrentData = Items.Inventory.CurrentData;
	MarkupsDiscountsClient.OpenFormAppliedDiscounts(CurrentData, Object, ThisObject);
	
EndProcedure

&AtServer
Function ResetFlagDiscountsAreCalculatedServer(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

&AtClient
Function ClearCheckboxDiscountsAreCalculatedClient(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

&AtServer
Function ResetFlagDiscountsAreCalculated(Action, SPColumn = "")
	
	Return DiscountsMarkupsServer.ResetFlagDiscountsAreCalculated(ThisObject, Action, SPColumn);
	
EndFunction

&AtServer
Procedure AutomaticDiscountsOnCreateAtServer()
	
	InstalledGrayColor = False;
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts");
	If UseAutomaticDiscounts Then
		If Object.Inventory.Count() = 0 Then
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
			InstalledGrayColor = True;
		ElsIf Not Object.DiscountsAreCalculated Then
			Object.DiscountsAreCalculated = False;
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateRed;
		Else
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Variants

&AtClientAtServerNoContext
Procedure PopulateVariantsList(VariantsChoiceList, VariantsCount, PreferredVariant, EditingIsAvailable)
	
	VariantsChoiceList.Clear();
	
	SingleVariant = VariantsCount < 2;
	
	If SingleVariant Then
		
		VariantsChoiceList.Add(0, NStr("en = 'Single variant'; ru = 'Единственный вариант';pl = 'Pojedynczy wariant';es_ES = 'Una variante';es_CO = 'Una variante';tr = 'Tek varyant';it = 'Singola variante';de = 'Einzelne Variante'"));
		Variant = 2;
		
	Else
		
		For Variant = 1 To VariantsCount Do
			
			If Variant = PreferredVariant Then
				VariantPostfix = NStr("en = '(preferred)'; ru = '(предпочтительный)';pl = '(preferowane)';es_ES = '(preferido)';es_CO = '(preferido)';tr = '(tercih edilen)';it = '(preferito)';de = '(bevorzugt)'");
			Else
				VariantPostfix = "";
			EndIf;
			
			VariantName = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Variant %1 %2'; ru = 'Вариант %1 %2';pl = 'Wariant %1 %2';es_ES = 'Variante %1 %2';es_CO = 'Variante %1 %2';tr = 'Varyant %1 %2';it = 'Variante %1 %2';de = 'Variante %1 %2'"), Variant, VariantPostfix);
			VariantsChoiceList.Add(Variant, VariantName);
			
		EndDo;
		
	EndIf;
	
	If EditingIsAvailable Then
		VariantsChoiceList.Add(Variant, "+");
	EndIf;
	
EndProcedure

&AtClient
Procedure FillInventoryRelativeLineNumbers()
	
	If CurrentVariant = 0 Then
		
		For Each InventoryRow In Object.Inventory Do
			InventoryRow.RelativeLineNumber = InventoryRow.LineNumber;
		EndDo;
		
	Else
		
		InventoryRows = Object.Inventory.FindRows(New Structure("Variant", CurrentVariant));
		LineNumber = 0;
		For Each InventoryRow In InventoryRows Do
			LineNumber = LineNumber + 1;
			InventoryRow.RelativeLineNumber = LineNumber;
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVariantsActionsAvailability()
	
	CurrentVariantIsPreferred = CurrentVariant = Object.PreferredVariant;
	Items.VariantDelete.Enabled = Not CurrentVariantIsPreferred;
	Items.VariantSetAsPreferred.Enabled = Not CurrentVariantIsPreferred;
	
EndProcedure

&AtClient
Procedure SetVariantRowFilter()
	
	If Object.VariantsCount < 2 Then
		Items.Inventory.RowFilter = Undefined;
		Items.SalesTax.RowFilter = Undefined;
	Else
		Items.Inventory.RowFilter = New FixedStructure("Variant", CurrentVariant);
		Items.SalesTax.RowFilter = New FixedStructure("Variant", CurrentVariant);
	EndIf;
	
EndProcedure

&AtClient
Procedure AddVariant()
	
	If Object.VariantsCount < 2 Then
		
		Object.VariantsCount = 2;
		Object.PreferredVariant = 1;
		
		For Each InventoryRow In Object.Inventory Do
			InventoryRow.Variant = 1;
		EndDo;
		
		// Bundles
		For Each BundleRow In Object.AddedBundles Do
			BundleRow.Variant = 1;
		EndDo;
		// End Bundles
		
		For Each SalesTaxRow In Object.SalesTax Do
			SalesTaxRow.Variant = 1;
		EndDo;
		
	Else
		
		Object.VariantsCount = Object.VariantsCount + 1;
		
	EndIf;
	
	PopulateVariantsList(Items.CurrentVariant.ChoiceList,
		Object.VariantsCount,
		Object.PreferredVariant,
		EditingIsAvailable);
	
	CurrentVariant = Object.VariantsCount;
	
	SetVariantsActionsAvailability();
	SetVariantRowFilter();
	
EndProcedure

&AtClient
Procedure CopyVariant()
	
	PreviousVariant = ?(CurrentVariant = 0, 1, CurrentVariant);
	
	AddVariant();
	
	InventoryRows = Object.Inventory.FindRows(New Structure("Variant", PreviousVariant));
	
	For Each InventoryRow In InventoryRows Do
		
		NewRow = Object.Inventory.Add();
		FillPropertyValues(NewRow, InventoryRow, , "ConnectionKey");
		NewRow.Variant = CurrentVariant;
		
	EndDo;
	
	// Bundles
	BundlesRows = Object.AddedBundles.FindRows(New Structure("Variant", PreviousVariant));
	
	For Each BundlesRow In BundlesRows Do
		
		NewRow = Object.AddedBundles.Add();
		FillPropertyValues(NewRow, BundlesRow);
		NewRow.Variant = CurrentVariant;
		
	EndDo;
	// End Bundles
	
	SalesTaxRows = Object.SalesTax.FindRows(New Structure("Variant", PreviousVariant));
	
	For Each SalesTaxRow In SalesTaxRows Do
		
		NewRow = Object.SalesTax.Add();
		FillPropertyValues(NewRow, SalesTaxRow);
		NewRow.Variant = CurrentVariant;
		
	EndDo;
	
	RecalculateSubtotal();
	
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure

&AtClient
Procedure DeleteVariant()
	
	If CurrentVariant = Object.PreferredVariant
		Or Object.VariantsCount < 2
		Or Object.PreferredVariant = 0 Then
		
		Return;
		
	EndIf;
	
	InvRows = Object.Inventory.FindRows(New Structure("Variant", CurrentVariant));
	For Each InvRow In InvRows Do
		Object.Inventory.Delete(InvRow);
	EndDo;
	
	// Bundles
	BundlesRows = Object.AddedBundles.FindRows(New Structure("Variant", CurrentVariant));	
	For Each BundlesRow In BundlesRows Do
		Object.AddedBundles.Delete(BundlesRow);
	EndDo;
	// End Bundles
	
	SalesTaxRows = Object.SalesTax.FindRows(New Structure("Variant", CurrentVariant));
	For Each SalesTaxRow In SalesTaxRows Do
		Object.SalesTax.Delete(SalesTaxRow);
	EndDo;
	
	If Object.VariantsCount = 2 Then
		
		Object.VariantsCount = 0;
		Object.PreferredVariant = 0;
		
		For Each InvRow In Object.Inventory Do
			InvRow.Variant = 0;
		EndDo;
		
		// Bundles
		For Each BundlesRow In BundlesRows Do
			BundlesRow.Variant = 0;
		EndDo;
		// End Bundles
		
		For Each SalesTaxRow In Object.SalesTax Do
			SalesTaxRow.Variant = 0;
		EndDo;
		
	Else
		
		For Each InvRow In Object.Inventory Do
			If InvRow.Variant > CurrentVariant Then
				InvRow.Variant = InvRow.Variant - 1;
			EndIf;
		EndDo;
		
		// Bundles
		For Each BundlesRow In BundlesRows Do
			If BundlesRow.Variant > CurrentVariant Then
				BundlesRow.Variant = BundlesRow.Variant - 1;
			EndIf;
		EndDo;
		// End Bundles
		
		For Each SalesTaxRow In Object.SalesTax Do
			If SalesTaxRow.Variant > CurrentVariant Then
				SalesTaxRow.Variant = SalesTaxRow.Variant - 1;
			EndIf;
		EndDo;
		
		Object.VariantsCount = Object.VariantsCount - 1;
		If Object.PreferredVariant > CurrentVariant Then
			Object.PreferredVariant = Object.PreferredVariant - 1;
		EndIf;
		
	EndIf;
	
	CurrentVariant = Object.PreferredVariant;
	
	PopulateVariantsList(Items.CurrentVariant.ChoiceList,
		Object.VariantsCount,
		Object.PreferredVariant,
		EditingIsAvailable);
	SetVariantsActionsAvailability();
	FillInventoryRelativeLineNumbers();
	SetVariantRowFilter();
	RecalculateSubtotal();
	
EndProcedure

#EndRegion

#Region Bundles

&AtClient
Procedure InventoryBeforeDeleteRowEnd(Result, BundleData) Export
	
	If Result = Undefined Or Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	BundleRows = Object.Inventory.FindRows(BundleData);
	If BundleRows.Count() = 0 Then
		Return;
	EndIf;
	
	BundleRow = BundleRows[0];
	
	If Result = DialogReturnCode.No Then
		
		EditBundlesComponents(BundleRow);
		
	ElsIf Result = DialogReturnCode.Yes Then
		
		BundlesClient.DeleteBundleRows(BundleRow.BundleProduct,
			BundleRow.BundleCharacteristic,
			Object.Inventory,
			Object.AddedBundles,
			CurrentVariant);
			
		Modified = True;
		RecalculateSalesTax();
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
		SetBundlePictureVisible();
		
	ElsIf Result = "DeleteOne" Then
		
		FilterStructure = New Structure;
		FilterStructure.Insert("BundleProduct",			BundleRow.BundleProduct);
		FilterStructure.Insert("BundleCharacteristic",	BundleRow.BundleCharacteristic);
		FilterStructure.Insert("Variant",				CurrentVariant);
		AddedRows = Object.AddedBundles.FindRows(FilterStructure);
		BundleRows = Object.Inventory.FindRows(FilterStructure);
		
		If AddedRows.Count() = 0 Or AddedRows[0].Quantity <= 1 Then
			
			For Each Row In BundleRows Do
				Object.Inventory.Delete(Row);
			EndDo;
			
			For Each Row In AddedRows Do
				Object.AddedBundles.Delete(Row);
			EndDo;
			
			Return;
			
		EndIf;
		
		OldCount = AddedRows[0].Quantity;
		AddedRows[0].Quantity = OldCount - 1;
		BundlesClientServer.DeleteBundleComponent(BundleRow.BundleProduct,
			BundleRow.BundleCharacteristic,
			Object.Inventory,
			OldCount,
			,
			CurrentVariant);
			
		BundleRows = Object.Inventory.FindRows(FilterStructure);
		For Each Row In BundleRows Do
			CalculateAmountInTabularSectionLine(Row, False);
		EndDo;
		
		Modified = True;
		RecalculateSalesTax();
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure BundlesOnCreateAtServer()
	
	UseBundles = GetFunctionalOption("UseProductBundles");
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshBundlePictures(Inventory)
	
	For Each InventoryLine In Inventory Do
		InventoryLine.BundlePicture = ValueIsFilled(InventoryLine.BundleProduct);
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure ReplaceInventoryLineWithBundleData(Form, BundleLine, StructureData)
	
	Items = Form.Items;
	Object = Form.Object;
	BundlesClientServer.ReplaceInventoryLineWithBundleData(Object, "Inventory", BundleLine, StructureData);
	
	// Refresh RowFiler
	If Items.Inventory.RowFilter <> Undefined And Items.Inventory.RowFilter.Count() > 0 Then
		OldRowFilter = Items.Inventory.RowFilter;
		Items.Inventory.RowFilter = New FixedStructure(New Structure);
		Items.Inventory.RowFilter = OldRowFilter;
	EndIf;
	
	Items.InventoryBundlePicture.Visible = True;
	
EndProcedure

&AtServerNoContext
Procedure RefreshBundleAttributes(Inventory)
	
	If Not GetFunctionalOption("UseProductBundles") Then
		Return;
	EndIf;
	
	ProductsArray = New Array;
	For Each InventoryLine In Inventory Do
		
		If ValueIsFilled(InventoryLine.Products) And Not ValueIsFilled(InventoryLine.BundleProduct) Then
			ProductsArray.Add(InventoryLine.Products);
		EndIf;
		
	EndDo;
	
	If ProductsArray.Count() > 0 Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	Products.Ref AS Ref
		|FROM
		|	Catalog.Products AS Products
		|WHERE
		|	Products.Ref IN(&ProductsArray)
		|	AND Products.IsBundle";
		
		Query.SetParameter("ProductsArray", ProductsArray);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		ProductsMap = New Map;
		
		While SelectionDetailRecords.Next() Do
			ProductsMap.Insert(SelectionDetailRecords.Ref, True);
		EndDo;
		
		For Each InventoryLine In Inventory Do
			
			If Not ValueIsFilled(InventoryLine.Products) Or ValueIsFilled(InventoryLine.BundleProduct) Then
				InventoryLine.IsBundle = False;
			Else
				InventoryLine.IsBundle = ProductsMap.Get(InventoryLine.Products);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshBundleComponents(BundleProduct, BundleCharacteristic, Quantity, BundleComponents)
	
	FillingParameters = New Structure;
	FillingParameters.Insert("Object", Object);
	
	BundlesServer.RefreshBundleComponentsInTable(BundleProduct, BundleCharacteristic, Quantity, BundleComponents, FillingParameters, CurrentVariant);
	Modified = True;
	
	// AutomaticDiscounts
	ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure ActionsAfterDeleteBundleLine()
	
	RecalculateSalesTax();
	FillInventoryRelativeLineNumbers();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow")
	
EndProcedure

&AtClient
Procedure EditBundlesComponents(InventoryLine)
	
	OpeningStructure = New Structure;
	OpeningStructure.Insert("BundleProduct", InventoryLine.BundleProduct);
	OpeningStructure.Insert("BundleCharacteristic", InventoryLine.BundleCharacteristic);
	OpeningStructure.Insert("Variant", CurrentVariant);
	
	AddedRows = Object.AddedBundles.FindRows(OpeningStructure);
	BundleRows = Object.Inventory.FindRows(OpeningStructure);
	
	If AddedRows.Count() = 0 Then
		OpeningStructure.Insert("Quantity", 1);
	Else
		OpeningStructure.Insert("Quantity", AddedRows[0].Quantity);
	EndIf;
	
	OpeningStructure.Insert("BundlesComponents", New Array);
	
	For Each Row In BundleRows Do
		RowStructure = New Structure("Products, Characteristic, Quantity, CostShare, MeasurementUnit, IsActive");
		FillPropertyValues(RowStructure, Row);
		RowStructure.IsActive = (Row = InventoryLine);
		OpeningStructure.BundlesComponents.Add(RowStructure);
	EndDo;
	
	OpenForm("InformationRegister.BundlesComponents.Form.ChangeComponentsOfTheBundle",
		OpeningStructure,
		ThisObject,
		, , , ,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Procedure SetBundlePictureVisible()
	
	BundlePictureVisible = False;
	
	For Each Row In Object.Inventory Do
		
		If Row.BundlePicture Then
			BundlePictureVisible = True;
			Break;
		EndIf;
		
	EndDo;
	
	If Items.InventoryBundlePicture.Visible <> BundlePictureVisible Then
		Items.InventoryBundlePicture.Visible = BundlePictureVisible;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetBundleConditionalAppearance()
	
	If UseBundles Then
		
		NewConditionalAppearance = ConditionalAppearance.Items.Add();
		WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
			"Object.Inventory.BundleProduct",
			Catalogs.Products.EmptyRef(),
			DataCompositionComparisonType.NotEqual);
			
		WorkWithForm.AddAppearanceField(NewConditionalAppearance, "InventoryProducts, InventoryCharacteristic, InventoryContent, InventoryQuantity, InventoryMeasurementUnit");
		WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
		WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.UnavailableTabularSectionTextColor);
				
	EndIf;
	
EndProcedure

&AtServer
Function BundleCharacteristics(Product, Text)
	
	ParametersStructure = New Structure;
	
	If IsBlankString(Text) Then
		ParametersStructure.Insert("SearchString", Undefined);
	Else
		ParametersStructure.Insert("SearchString", Text);
	EndIf;
	
	ParametersStructure.Insert("Filter", New Structure);
	ParametersStructure.Filter.Insert("Owner", Product);
	
	Return Catalogs.ProductsCharacteristics.GetChoiceData(ParametersStructure);
	
EndFunction

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	
	Return Fields;
	
EndFunction

#EndRegion

#Region BackgroundJobs

&AtServer
Function GenerateCounterpartySegmentsAtServer()
	
	CounterpartySegmentsJobID = Undefined;
	
	ProcedureName = "ContactsClassification.ExecuteCounterpartySegmentsGeneration";
	StartSettings = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings.BackgroundJobDescription = NStr("en = 'Counterparty segments generation'; ru = 'Создание сегментов контрагентов';pl = 'Generacja segmentów kontrahenta';es_ES = 'Generación de segmentos de contrapartida';es_CO = 'Generación de segmentos de contrapartida';tr = 'Cari hesap segmentleri oluşturma';it = 'Generazione segmenti controparti';de = 'Generierung von Geschäftspartnersegmenten'");
	
	ExecutionResult = TimeConsumingOperations.ExecuteInBackground(ProcedureName,, StartSettings);
	
	StorageAddress = ExecutionResult.ResultAddress;
	CounterpartySegmentsJobID = ExecutionResult.JobID;
	
	If ExecutionResult.Status = "Completed" Then
		MessageText = NStr("en = 'Counterparty segments have been updated successfully.'; ru = 'Сегменты контрагентов успешно обновлены.';pl = 'Segmenty kontrahenta zostali zaktualizowani pomyślnie.';es_ES = 'Se han actualizado con éxito los segmentos de contrapartida.';es_CO = 'Se han actualizado con éxito los segmentos de contrapartida.';tr = 'Cari hesap segmentleri başarıyla güncellendi.';it = 'I segmenti delle controparti sono stati aggiornati con successo.';de = 'Die Geschäftspartner-Segmente wurden erfolgreich aktualisiert.'");
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return ExecutionResult;

EndFunction

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If JobCompleted(CounterpartySegmentsJobID) Then
			MessageText = NStr("en = 'Counterparty segments have been updated successfully.'; ru = 'Сегменты контрагентов успешно обновлены.';pl = 'Segmenty kontrahenta zostali zaktualizowani pomyślnie.';es_ES = 'Se han actualizado con éxito los segmentos de contrapartida.';es_CO = 'Se han actualizado con éxito los segmentos de contrapartida.';tr = 'Cari hesap segmentleri başarıyla güncellendi.';it = 'I segmenti delle controparti sono stati aggiornati con successo.';de = 'Die Geschäftspartner-Segmente wurden erfolgreich aktualisiert.'");
			CommonClientServer.MessageToUser(MessageText);
		Else
			TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckJobExecution",
				IdleHandlerParameters.CurrentInterval,
				True);
		EndIf;
	Except
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(CounterpartySegmentsJobID)
	
	Return TimeConsumingOperations.JobCompleted(CounterpartySegmentsJobID);
	
EndFunction

&AtClient
Procedure SalesTaxOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		
		SalesTaxRow = Item.CurrentData;
		
		SalesTaxRow.Variant = CurrentVariant;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region SalesTax

&AtServer
Procedure SetVisibleTaxAttributes()
	
	IsSubjectToVAT = (Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT);

	Items.InventoryVATRate.Visible						= IsSubjectToVAT;
	Items.InventoryVATAmount.Visible					= IsSubjectToVAT;
	Items.InventoryAmountTotal.Visible					= IsSubjectToVAT;
	Items.PaymentCalendarPayVATAmount.Visible			= IsSubjectToVAT;
	Items.ListPaymentsCalendarSumVatOfPayment.Visible	= IsSubjectToVAT;
	Items.DocumentTax.Visible							= IsSubjectToVAT OR RegisteredForSalesTax;
	Items.InventoryTaxable.Visible						= RegisteredForSalesTax;
	Items.InventorySalesTaxAmount.Visible				= RegisteredForSalesTax;
	Items.GroupSalesTax.Visible							= RegisteredForSalesTax;
	
EndProcedure

&AtServerNoContext
Function GetSalesTaxPercentage(SalesTaxRate)
	
	Return Common.ObjectAttributeValue(SalesTaxRate, "Rate");
	
EndFunction

&AtClient
Procedure CalculateSalesTaxAmount(TableRow)
	
	AmountTaxable = GetTotalTaxable();
	
	TableRow.Amount = Round(AmountTaxable * TableRow.SalesTaxPercentage / 100, 2, RoundMode.Round15as20);
	
EndProcedure

&AtServer
Function GetTotalTaxable()
	
	InventoryTaxable = Object.Inventory.Unload(New Structure("Variant, Taxable", CurrentVariant, True));
	
	Return InventoryTaxable.Total("Total");
	
EndFunction

&AtServer
Procedure FillSalesTaxRate()
	
	SalesTaxRateBeforeChange = Object.SalesTaxRate;
	
	Object.SalesTaxRate = DriveServer.CounterpartySalesTaxRate(Object.Counterparty, RegisteredForSalesTax);
	
	If SalesTaxRateBeforeChange <> Object.SalesTaxRate Then
		
		If ValueIsFilled(Object.SalesTaxRate) Then
			Object.SalesTaxPercentage = Common.ObjectAttributeValue(Object.SalesTaxRate, "Rate");
		Else
			Object.SalesTaxPercentage = 0;
		EndIf;
		
		RecalculateSalesTax();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RecalculateSalesTax()
	
	FormObject = FormAttributeToValue("Object");
	FormObject.RecalculateSalesTax(CurrentVariant);
	ValueToFormAttribute(FormObject, "Object");
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

&AtClient
Procedure InventoryTaxableOnChange(Item)
	
	RecalculateSalesTax();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

#EndRegion

#EndRegion
