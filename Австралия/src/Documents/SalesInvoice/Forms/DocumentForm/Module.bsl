
#Region Variables

&AtClient
Var ThisIsNewRow;

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
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	
	If Object.ThirdPartyPayment Then
		Payer = Object.Payer;
	EndIf;
	
	ReadPayerAttributes(PayerAttributes, Object.Payer);
	
	If ValueIsFilled(Contract) Then
		SettlementCurrency = Common.ObjectAttributeValue(Contract, "SettlementsCurrency");
	EndIf;
	
	SetPrepaymentColumnsProperties();
	
	Order				= Object.Order;
	FunctionalCurrency	= DriveReUse.GetFunctionalCurrency();
	StructureByCurrency	= CurrencyRateOperations.GetCurrencyRate(Object.Date, FunctionalCurrency, Object.Company);
	
	ExchangeRateNationalCurrency	= StructureByCurrency.Rate;
	MultiplicityNationalCurrency	= StructureByCurrency.Repetition;
	ExchangeRateMethod = DriveServer.GetExchangeMethod(Object.Company);
	
	SetAccountingPolicyValues();
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	If Not ValueIsFilled(Object.Ref) Then
		
		If Not ValueIsFilled(Parameters.Basis) AND Not ValueIsFilled(Parameters.CopyingValue) Then
			FillVATRateByCompanyVATTaxation();
			FillSalesTaxRate();
		EndIf;
		
		If Not ValueIsFilled(Object.Order) AND Parameters.Property("Basis") AND TypeOf(Parameters.Basis)=Type("DocumentRef.InventoryTransfer") Then
			For Each RowInventory In Object.Inventory Do
				WorkWithProductsServer.FillDataInTabularSectionRow(Object, "Inventory", RowInventory);
			EndDo;
		EndIf;
		
	EndIf;
	
	ForeignExchangeAccounting = GetFunctionalOption("ForeignExchangeAccounting");
	// Generate price and currency label.
	GenerateLabelPricesAndCurrency(ThisObject);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
	ReadDeliveryDatePosition();
	
	SetVisibleAndEnabled();
	
	// Attribute visible set from user settings
	SetVisibleFromUserSettings();
	
	SetConditionalAppearance();
	
	WorkWithVAT.SetTextAboutTaxInvoiceIssued(ThisForm);
	
	User = Users.CurrentUser();
	
	SettingValue	= DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
	MainWarehouse	= ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainWarehouse);
	
	// Setting contract visible.
	SetContractVisible();
	
	// Department setting
	If Not GetFunctionalOption("UseSeveralDepartments") Then
		Items.AdditionallyRightColumn.United = True;
	EndIf;
	
	// Bundles
	BundlesOnCreateAtServer();
	
	If Not ValueIsFilled(Object.Ref) Then
		
		If Parameters.FillingValues.Property("Inventory") Then
			
			For Each RowData In Parameters.FillingValues.Inventory Do
				
				FilterStructure = New Structure;
				FilterStructure.Insert("Products", RowData.Products);
				If RowData.Property("Characteristic") And ValueIsFilled(RowData.Characteristic) Then
					FilterStructure.Insert("Characteristic", RowData.Characteristic);
				EndIf;
				Rows = Object.Inventory.FindRows(FilterStructure);
				
				For Each BundleRow In Rows Do
					
					StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Inventory", BundleRow);
					
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
					
					If UseDefaultTypeOfAccounting Then
						AddGLAccountsToStructure(ThisObject, "Inventory", StructureData, BundleRow);
					EndIf;
					
					StructureData = GetDataProductsOnChange(StructureData);
					
					If StructureData.IsBundle And Not StructureData.UseCharacteristics Then
						ReplaceInventoryLineWithBundleData(ThisObject, BundleRow, StructureData);
					Else
						FillPropertyValues(BundleRow, StructureData);
					EndIf;
					
				EndDo;
				
			EndDo;
			
		EndIf;
		
		RefreshBundlePictures(Object.Inventory);
		RefreshBundleAttributes(Object.Inventory);
		
	EndIf;
	
	SetBundlePictureVisible();
	SetBundleConditionalAppearance();
	// End Bundles
	
	FillVATValidationAttributes();
	
	ProcessingCompanyVATNumbers();
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// StandardSubsystems.Interactions
	Interactions.PrepareNotifications(ThisObject, Parameters);
	// End StandardSubsystems.Interactions
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.SalesInvoice.TabularSections.Inventory, DataLoadSettings, ThisObject);
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
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	SetVisibleTaxInvoiceText();
	
	Items.TaxInvoiceText.Enabled = WorkWithVAT.IsTaxInvoiceAccessRightEdit();
	
	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
	Items.InventoryDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
		
	OldOperationKind = Object.OperationKind;
	
	EDIParametersOnCreate = EDIServer.EDIParameters();
	EDIParametersOnCreate.Form = ThisObject;
	EDIParametersOnCreate.Ref = Object.Ref;
	EDIParametersOnCreate.StateDecoration = Items.EDIStateDecoration;
	EDIParametersOnCreate.StateGroup = Items.EDIStateGroup;
	EDIParametersOnCreate.SpotForCommands = Items.EDICommands;
	
	EDIServer.OnCreateAtServer_DocumentForm(EDIParametersOnCreate);
	
	DriveServer.CheckObjectGeneratedEnteringBalances(ThisObject);
	
	BatchesServer.AddFillBatchesByFEFOCommands(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If UsersClientServer.IsExternalUserSession() Then
		PrintManagementClientDrive.GeneratePrintFormForExternalUsers(Object.Ref,
			"Document.SalesInvoice",
			"SalesInvoice",
			NStr("en = 'Sales invoice'; ru = 'Инвойс покупателю';pl = 'Faktura sprzedaży';es_ES = 'Factura de ventas';es_CO = 'Factura de ventas';tr = 'Satış faturası';it = 'Fattura di vendita';de = 'Verkaufsrechnung'"),
			FormOwner,
			UniqueKey);
		Cancel = True;
		Return;
	EndIf;

	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	SetVisibleEnablePaymentTermItems();
	SetVisibleDeliveryAttributes();
	SetVisibleEarlyPaymentDiscounts();
	SetVisibleSalesRep();
	SetVisibleThirdPartyPayer();
	SetVisibleThirdPartyPayerContract();
	SetVisibleAccordingToInvoiceType();
	SetVisiblePrepaymentAndPaymentCalendar();
	
	PrepaymentWasChanged = False;
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)

	// AutomaticDiscounts
	// Display message about discount calculation if you click the "Post and close" or form closes by the cross with change saving.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification(NStr("en = 'Change:'; ru = 'Изменение:';pl = 'Zmiana:';es_ES = 'Cambiar:';es_CO = 'Cambiar:';tr = 'Değişim:';it = 'Modificare:';de = 'Änderung:'"), 
									GetURL(Object.Ref), 
									String(Object.Ref) + NStr("en = '. The automatic discounts are applied.'; ru = '. Автоматические скидки (наценки) рассчитаны!';pl = '. Stosowane są rabaty automatyczne.';es_ES = '. Descuentos automáticos se han aplicado.';es_CO = '. Descuentos automáticos se han aplicado.';tr = '. Otomatik indirimler uygulandı.';it = '. Sconti automatici sono stati applicati.';de = '. Die automatischen Rabatte werden angewendet.'"), 
									PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
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
	
	If EventName = "RefreshTaxInvoiceText" 
		AND TypeOf(Parameter) = Type("Structure") 
		AND Not Parameter.BasisDocuments.Find(Object.Ref) = Undefined Then
		
		TaxInvoiceText = Parameter.Presentation;
		
	ElsIf EventName = "UpdateIBDocumentAfterFilling" Then
		
		Read();
	
	ElsIf EventName = "Write_Counterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Parameter);
		SetContractVisible();
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
			CalculateAmountInTabularSectionLine();
		EndIf;
		
	EndIf;
	
	// Bundles
	If BundlesClient.ProcessNotifications(ThisObject, EventName, Source) Then
		RefreshBundleComponents(Parameter.BundleProduct, Parameter.BundleCharacteristic, Parameter.Quantity, Parameter.BundleComponents);
		ActionsAfterDeleteBundleLine();
	EndIf;
	// End Bundles
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	EDINotificationParameters = EDIClient.ParametersNotificationProcessing();
	EDINotificationParameters.Form = ThisObject;
	EDINotificationParameters.Ref = Object.Ref;
	EDINotificationParameters.StateDecoration = Items.EDIStateDecoration;
	EDINotificationParameters.StateGroup = Items.EDIStateGroup;
	EDIClient.NotificationProcessing_DocumentForm(EventName, Parameter, Source, EDINotificationParameters);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// Bundles
	RefreshBundlePictures(Object.Inventory);
	RefreshBundleAttributes(Object.Inventory);
	// End Bundles
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	SetSwitchTypeListOfPaymentCalendar();
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// AutomaticDiscounts
	DiscountsCalculatedBeforeWrite = False;
	// If the document is being posted, we check whether the discounts are calculated.
	If UseAutomaticDiscounts Then
		If Not Object.DiscountsAreCalculated AND DiscountsChanged() Then
			CalculateDiscountsMarkupsClient();
			RecalculateSalesTax();
			PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
			RefillDiscountAmountOfEPD();
			RecalculateSubtotal();
			CalculatedDiscounts = True;
			
			Message = New UserMessage;
			Message.Text	= NStr("en = 'The automatic discounts are applied.'; ru = 'Рассчитаны автоматические скидки (наценки)!';pl = 'Stosowane są rabaty automatyczne.';es_ES = 'Los descuentos automáticos se han aplicado.';es_CO = 'Los descuentos automáticos se han aplicado.';tr = 'Otomatik indirimler uygulandı.';it = '. Sconti automatici sono stati applicati.';de = 'Die automatischen Rabatte werden angewendet.'");
			Message.DataKey	= Object.Ref;
			Message.Message();
			
			DiscountsCalculatedBeforeWrite	= True;
		Else
			Object.DiscountsAreCalculated	= True;
			RefreshImageAutoDiscountsAfterWrite	= True;
		EndIf;
	EndIf;
	// End AutomaticDiscounts
	
	If ThisObject.Modified Or WriteParameters.WriteMode = DocumentWriteMode.UndoPosting Then
		EDIClient.DocumentWasChanged(Object.Ref);
	EndIf;
	
	If Object.AmountAllocation.Count() <> 0 And Object.DocumentAmount < 0
		And Object.AmountAllocation.Total("OffsetAmount") <> -Object.DocumentAmount Then 
		
		Cancel = True;
		Notify = New NotifyDescription("FillAllocationEnd", ThisObject);
		ShowQueryBox(Notify, 
			NStr("en = 'The total allocated amount does not match the total document amount.
				|Do you want to repopulate the Amount allocation tab?'; 
				|ru = 'Общая распределенная сумма не соответствует общей сумме документа.
				|Вы хотите повторно заполнить вкладку Распределение суммы?';
				|pl = 'Łączna przydzielona wartość nie odpowiada łącznej wartości dokumentu.
				|Czy chcesz ponownie wypełnić kartę Opis transakcji?';
				|es_ES = 'La cantidad total asignada no coincide con la cantidad total del documento.
				|¿Quiere rellenar la pestaña Asignación del importe?';
				|es_CO = 'La cantidad total asignada no coincide con la cantidad total del documento.
				|¿Quiere rellenar la pestaña Asignación del importe?';
				|tr = 'Paylaştırılan toplam tutar belgenin toplam tutarı ile eşleşmiyor.
				|Tutar paylaştırma sekmesi yeniden doldurulsun mu?';
				|it = 'L''importo allocato totale non corrisponde all''importo totale del documento. 
				|Ricompilare la scheda Allocazione importo?';
				|de = 'Die gesamte Verteilung stimmt mit der Gesamtmenge im Dokument nicht überein.
				|Möchten Sie die Registerkarte Verteilungsmenge neu ausfüllen?'"),
			QuestionDialogMode.YesNo, 0);
	EndIf;
	
	If Object.ThirdPartyPayment Then
		Object.SetPaymentTerms = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		If DriveReUse.CounterpartyContractsControlNeeded() And CounterpartyAttributes.DoOperationsByContracts Then
			
			CheckContractToDocumentConditionAccordance(
				MessageText,
				Object.Contract,
				Object.Ref,
				Object.Company,
				Object.Counterparty,
				Cancel);
			
		EndIf;
		
		If MessageText <> "" Then
			
			MessageText = ?(
				Cancel,
				NStr("en = 'Cannot post the sales invoice.'; ru = 'Невозможно провести инвойс покупателю.';pl = 'Nie można zatwierdzić faktury sprzedaży.';es_ES = 'No se puede publicar la factura de ventas.';es_CO = 'No se puede publicar la factura de ventas.';tr = 'Satış faturası kaydedilemiyor.';it = 'Impossibile pubblicare la fattura di vendita.';de = 'Die Verkaufsrechnung kann nicht gebucht werden.'") + " " + MessageText,
				MessageText);
				
			CommonClientServer.MessageToUser(MessageText,,,, Cancel);

			If Cancel Then
				Return;
			EndIf;
		EndIf;
		              
		If Object.PaymentMethod = PredefinedValue("Catalog.PaymentMethods.DirectDebit") And Object.DirectDebitMandate.IsEmpty() Then
			
			MessageText = NStr("en = 'Direct debit mandate cannot be empty.'; ru = 'Заполните мандат на прямое дебетование.';pl = 'Zezwolenie na polecenie zapłaty nie może być puste.';es_ES = 'El débito directo no puede estar vacío.';es_CO = 'El débito directo no puede estar vacío.';tr = 'Düzenli ödeme talimatı boş olamaz.';it = 'Il Mandato di addebito diretto non può essere vuoto.';de = 'Lastschriftmandat kann nicht leer sein.'");
			CommonClientServer.MessageToUser(MessageText,,,, Cancel);
			
			If Cancel Then
				Return;
			EndIf;
		EndIf;
		
		SalesTaxServer.CalculateInventorySalesTaxAmount(CurrentObject.Inventory, CurrentObject.SalesTax.Total("Amount"));
		
	EndIf;
	
	If DriveReUse.GetAdvanceOffsettingSettingValue() = PredefinedValue("Enum.YesNo.Yes")
		And CurrentObject.Prepayment.Count() = 0 
		And Not CurrentObject.ThirdPartyPayment Then
		FillPrepayment(CurrentObject);
	ElsIf PrepaymentWasChanged Then
		WorkWithVAT.FillPrepaymentVATFromVATOutput(CurrentObject);
	EndIf;
	
	AmountsHaveChanged = WorkWithVAT.CalculateVATPerInvoiceTotal(CurrentObject);
	If AmountsHaveChanged Then
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(CurrentObject);
		RefillDiscountAmountOfEPDNoContext(CurrentObject);
	EndIf;
	
	If NOT CheckEarlyPaymentDiscounts() Then
		Cancel = True;
	EndIf;
	
	If Object.ThirdPartyPayment Then
		
		If ValueIsFilled(Object.Contract) And ValueIsFilled(Object.PayerContract) Then
			
			PayerContractCurrency = Common.ObjectAttributeValue(Object.PayerContract, "SettlementsCurrency");
			
			If SettlementCurrency <> PayerContractCurrency Then
				MessageText = NStr("en = 'The currency of the customer''s and payer''s contracts must be the same.'; ru = 'Валюта договоров покупателя и плательщика должна совпадать.';pl = 'Waluta kontraktów nabywcy i płatnika powinna być taka sama.';es_ES = 'La moneda de los contratos del cliente y del pagador debe ser la misma.';es_CO = 'La moneda de los contratos del cliente y del pagador debe ser la misma.';tr = 'Müşterinin ve ödeyenin sözleşmelerindeki para birimi aynı olmalıdır.';it = 'La valuta dei contratti del cliente e del pagatore deve essere la stessa.';de = 'Die Währung der Verträge des Kunden und Zahler sollen übereinstimmen.'");
				CommonClientServer.MessageToUser(MessageText, , , , Cancel);
			EndIf;
			
		EndIf;
		
		If ValueIsFilled(Object.Payer) And ValueIsFilled(Object.Counterparty) And Object.Payer = Object.Counterparty Then
			MessageText = NStr("en = 'The customer and the payer must not be the same.'; ru = 'Покупатель и плательщик не должны совпадать.';pl = 'Nabywca i płatnik powinni różnić się.';es_ES = 'El cliente y el pagador no deben ser los mismos.';es_CO = 'El cliente y el pagador no deben ser los mismos.';tr = 'Müşteri ve ödeyen aynı olamaz.';it = 'Il cliente e il pagatore non possono essere la stessa persona.';de = 'Der Kunde und der Zahler sollen nicht übereinstimmen.'");
			CommonClientServer.MessageToUser(MessageText, , , , Cancel);
		EndIf;
		
	EndIf;
	
	SetDeliveryDatePosition();
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
	// Bundles
	RefreshBundleAttributes(Object.Inventory);
	// End Bundles
	
	WorkWithVAT.SetTextAboutTaxInvoiceIssued(ThisObject);
	
	EDIAfterWriteParameters = EDIServer.EDIParameters();
	EDIAfterWriteParameters.Form = ThisObject;
	EDIAfterWriteParameters.Ref = Object.Ref;
	EDIAfterWriteParameters.StateDecoration = Items.EDIStateDecoration;
	EDIAfterWriteParameters.StateGroup = Items.EDIStateGroup;
	EDIAfterWriteParameters.SpotForCommands = Items.EDICommands;
	EDIServer.AfterWriteAtServer_DocumentForm(CurrentObject, EDIAfterWriteParameters);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// StandardSubsystems.Interactions
	InteractionsClient.InteractionSubjectAfterWrite(ThisObject, Object, WriteParameters, "SalesInvoice");
	// End StandardSubsystems.Interactions
	
	OrderIsFilled = False;
	FilledOrderReturn = False;
	For Each TSRow In Object.Inventory Do
		If ValueIsFilled(TSRow.Order) Then
			If TypeOf(TSRow.Order) = Type("DocumentRef.SalesOrder") Then
				OrderIsFilled = True;
			Else
				FilledOrderReturn = True;
			EndIf;
			Break;
		EndIf;		
	EndDo;	
	
	If OrderIsFilled Then
		Notify("Record_SalesInvoice", Object.Ref);
	EndIf;
	
	If FilledOrderReturn Then
		Notify("Record_SalesInvoiceReturn", Object.Ref);
	EndIf;
	
	Notify("NotificationAboutChangingDebt");
	
	If Object.Posted
		And ValueIsFilled(Object.BasisDocument)
		And TypeOf(Object.BasisDocument) = Type("DocumentRef.Quote") Then
		NotifyParameter = New Structure;
		NotifyParameter.Insert("Quotation", Object.BasisDocument);
		NotifyParameter.Insert("Status", PredefinedValue("Catalog.QuotationStatuses.Converted"));
		Notify("Write_Quotation", NotifyParameter, ThisObject);
	EndIf;
	
	// Bundles
	RefreshBundlePictures(Object.Inventory);
	// End Bundles
	
	PrepaymentWasChanged = False;
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.TaxInvoiceIssued.Form.DocumentForm" Then
		TaxInvoiceText = SelectedValue;
	ElsIf ChoiceSource.FormName = "CommonForm.SelectionFromOrders" Then
		OrderedProductsSelectionProcessingAtClient(SelectedValue.TempStorageInventoryAddress);
	ElsIf ChoiceSource.FormName = "Document.GoodsIssue.Form.SelectionForm" Then
		Items.Inventory.CurrentData.GoodsIssue = SelectedValue;
	ElsIf GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf ChoiceSource.FormName = "CommonForm.InventoryOwnership" Then
		EditOwnershipProcessingAtClient(SelectedValue.TempStorageInventoryOwnershipAddress);
	ElsIf ChoiceSource.FormName = "Catalog.BillsOfMaterials.Form.ChoiceForm" Then
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OperationKindOnChange(Item)
	
	If Object.OperationKind = OldOperationKind Then
		Return;
	ElsIf OldOperationKind = PredefinedValue("Enum.OperationTypesSalesInvoice.ClosingInvoice") Then
		HasNegativeQtyAmounts = False;
		For Each InventoryRow In Object.Inventory Do
			If InventoryRow.Quantity < 0
				Or InventoryRow.Amount < 0
				Or InventoryRow.VATAmount < 0
				Or InventoryRow.Total < 0 Then
				HasNegativeQtyAmounts = True;
				Break;
			EndIf;
		EndDo;
		If HasNegativeQtyAmounts Then
			Object.OperationKind = OldOperationKind;
			MessageText = NStr("en = 'Cannot change the Sales invoice type. The Products tab contains negative numbers.
				|Only Sales invoices with the Closing invoice type can contain negative numbers.
				|To be able to set another Sales invoice type, edit the Products tab data so that it contains only positive numbers.'; 
				|ru = 'Невозможно изменить тип инвойса покупателю. На вкладке ""Номенклатура"" содержатся отрицательные числа.
				|Только инвойсы покупателю с типом ""Заключительный инвойс"" могут содержать отрицательные числа.
				|Чтобы установить другой тип инвойса покупателю, измените данные на вкладке ""Номенклатура"" так, чтобы они содержали только положительные числа.';
				|pl = 'Nie można zmienić typu Faktury sprzedaży. Karta Produkty zawiera liczby ujemne.
				|Tylko Faktury sprzedaży o typie Faktura końcowa mogą zawierać liczby ujemne.
				|Aby mieć możliwość ustawienia innego typu Faktury sprzedaży, edytuj dane na karcie Produkty, tak aby ona zawierała liczby dodatnie.';
				|es_ES = 'No se puede cambiar el tipo de factura de Ventas. La pestaña Productos contiene números negativos. 
				|Sólo las facturas de ventas con el tipo de factura de cierre pueden contener números negativos.
				|Para poder establecer otro tipo de factura de venta, edite los datos de la pestaña Productos para que sólo contenga números positivos.';
				|es_CO = 'No se puede cambiar el tipo de factura de Ventas. La pestaña Productos contiene números negativos. 
				|Sólo las facturas de ventas con el tipo de factura de cierre pueden contener números negativos.
				|Para poder establecer otro tipo de factura de venta, edite los datos de la pestaña Productos para que sólo contenga números positivos.';
				|tr = 'Satış faturası türü değiştirilemiyor. Ürünler sekmesinde negatif sayılar var.
				|Sadece Kapanış faturası türündeki Satış faturaları negatif sayı içerebilir.
				|Başka bir Satış faturası türü belirleyebilmek için, Ürünler sekmesindeki verileri sadece pozitif sayı içerecek şekilde düzenleyin.';
				|it = 'Impossibile modificare il tipo di Fattura di vendita. La scheda Articoli contiene numeri negativi. 
				|Solo le Fatture di vendita con il tipo Fattura di chiusura possono contenere numeri negativi. 
				|Per poter impostare un altro tipo di Fattura di vendita, modificare i dati della scheda Articoli così che contenga solo numeri positivi.';
				|de = 'Kann den Typ der Abschlussrechnung nicht ändern. Die Registerkarte Produkte enthält negative Zahlen.
				|Nur Verkaufsrechnungen mit dem Typ Abschlussrechnungen dürfen negative Zahlen enthalten.
				|Um einen anderen Typ von Verkaufsrechnungen festlegen zu können, bearbeiten Sie die Daten der Registerkarte Produkte damit diese nur positive Zahlen enthält.'");
			CommonClientServer.MessageToUser(MessageText);
			Return;
		EndIf;
	EndIf; 
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", UseDefaultTypeOfAccounting);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	IsGoodsIssueFilled = False;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesInvoice.AdvanceInvoice") Then
		
		For Each LineInventory In Object.Inventory Do
			
			If ValueIsFilled(LineInventory.GoodsIssue) Then
				
				IsGoodsIssueFilled = True;
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesInvoice.ZeroInvoice") Then
		
		Mode = QuestionDialogMode.YesNo;
		Notification = New NotifyDescription("OperationKindOnChangeEnd", ThisObject, ParametersStructure);
		TextQuery = NStr("en = 'If you change the invoice type to Zero invoice, 
			|the details specified on the invoice tabs will be cleared.
			|Continue?'; 
			|ru = 'Если изменить тип инвойса на нулевой,
			|описание, указанное на вкладках, будет удалено.
			|Продолжить?';
			|pl = 'Jeśli zmieniasz typ faktury na fakturę zerową, 
			|szczegóły określone na kartach faktura zostaną wyczyszczone.
			|Kontynuować?';
			|es_ES = 'Si cambia el tipo de factura a Factura con importe cero, 
			|los detalles especificados en las pestañas de la factura se borrarán.
			|¿Continuar?';
			|es_CO = 'Si cambia el tipo de factura a Factura con importe cero, 
			|los detalles especificados en las pestañas de la factura se borrarán.
			|¿Continuar?';
			|tr = 'Fatura türünü Sıfır bedelli fatura olarak değiştirirseniz 
			|fatura sekmelerinde belirtilen bilgiler silinir.
			|Devam edilsin mi?';
			|it = 'Modificando il tipo di fattura in Fattura a zero, 
			|i dettagli specificati nelle schede della fattura saranno cancellati. 
			|Continuare?';
			|de = 'Wenn Sie den Rechnungstyp auf Null-Rechnung ändern, 
			|werden die auf den Registerkarten Rechnungen angegebenen Details gelöscht.
			|Fortfahren?'"); 
		ShowQueryBox(Notification, TextQuery, Mode, 0);
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesInvoice.AdvanceInvoice") 
		And IsGoodsIssueFilled 
		And Object.Inventory.Count() > 0 Then
		
		Mode = QuestionDialogMode.YesNo;
		Notification = New NotifyDescription("OperationKindOnChangeToAdvanceInvoice", ThisObject, ParametersStructure);
		TextQuery = NStr("en = 'If you change the invoice type to Advance invoice,
			|Goods issues specified on the Products tab will be cleared.
			|Continue?'; 
			|ru = 'Если изменить тип инвойса на авансовый,
			|отпуск товаров, указанный на вкладке ""Номенклатура"", будет очищен.
			|Продолжить?';
			|pl = 'Jeśli zmieniasz typ faktury na fakturę zaliczkową,
			|Wydania zewnętrzne, określone na karcie Produkty zostanie wyczyszczona.
			|Kontynuować?';
			|es_ES = 'Si cambia el tipo de factura a Factura avanzada,
			|las salidas de mercancías especificadas en la pestaña Productos se borrarán.
			|¿Continuar?';
			|es_CO = 'Si cambia el tipo de factura a Factura avanzada,
			|las salidas de mercancías especificadas en la pestaña Productos se borrarán.
			|¿Continuar?';
			|tr = 'Fatura türünü Avans faturası olarak değiştirirseniz
			|Ürünler sekmesinde belirtilen Ambar çıkışları silinir.
			|Devam edilsin mi?';
			|it = 'Modificando il tipo di fattura in Fattura anticipata, 
			|Spedizione merce/DDT specificata nella scheda Articoli sarà cancellata. 
			|Continuare?';
			|de = 'Wenn Sie die Rechnungstyp auf Vorausrechnung ändern, werden
			|Warenausgaben, die auf der Registerkarte Produkte angegeben sind, gelöscht.
			|Fortfahren?'"); 
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
Procedure OperationKindOnChangeToAdvanceInvoice(Result, ParametersStructure) Export
	
	If Result = DialogReturnCode.No Then
		
		Object.OperationKind = OldOperationKind;
		
		SetVisibleAccordingToInvoiceType();
		
		Return;
		
	EndIf;
	
	For Each LineInventory In Object.Inventory Do
		
		LineInventory.GoodsIssue = Undefined;
		
	EndDo;
	
	SetMeasurementUnits();
	
	FillAddedColumns(ParametersStructure);
	
	OldOperationKind = Object.OperationKind; 
	
	SetVisibleAccordingToInvoiceType();
	
	SetVisibleEarlyPaymentDiscounts();
	
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

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	// Company change event data processor.
	Object.BankAccount	= "";
	Object.Number	= "";
	StructureData	= GetDataCompanyOnChange();
	ParentCompany = StructureData.Company;
	ExchangeRateMethod = StructureData.ExchangeRateMethod;
	
	Object.ChiefAccountant	= StructureData.ChiefAccountant;
	Object.Released			= StructureData.Released;
	Object.ReleasedPosition	= StructureData.ReleasedPosition;
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	// Generate price and currency label.
	GenerateLabelPricesAndCurrency(ThisObject);
	
	If Object.SetPaymentTerms And ValueIsFilled(Object.PaymentMethod) Then
		PaymentTermsServerCall.FillPaymentTypeAttributes(
			Object.Company, Object.CashAssetType, Object.BankAccount, Object.PettyCash);
	EndIf;
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	ProcessCounterpartyChange();
	
EndProcedure

&AtClient
Procedure CounterpartyChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If SelectedValue <> Object.Counterparty
		And Object.Prepayment.Count() > 0 Then
		
		StandardProcessing = False;
		
		DocumentParameters = New Structure;
		DocumentParameters.Insert("CounterpartyChange", True);
		DocumentParameters.Insert("NewCounterparty", SelectedValue);
		
		NotifyDescription = New NotifyDescription("PrepaymentClearingQuestionEnd", ThisObject, DocumentParameters);
		QuestionText = NStr("en = 'Advances will be cleared. Do you want to continue?'; ru = 'Зачет аванса будет очищен, продолжить?';pl = 'Zaliczki zostaną rozliczone. Czy chcesz kontynuować?';es_ES = 'Anticipos se liquidarán. ¿Quiere continuar?';es_CO = 'Anticipos se liquidarán. ¿Quiere continuar?';tr = 'Avanslar silinecek. Devam etmek istiyor musunuz?';it = 'Gli anticipi saranno compensati. Volete continuare?';de = 'Vorauszahlungen werden gelöscht. Wollen Sie fortsetzen?'");
		
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;

EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormParameters(
		Object.Ref,
		Object.Company,
		Object.Counterparty, 
		CounterpartyAttributes.DoOperationsByContracts,
		Object.Contract);
	
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OrderStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	StructureFilter = New Structure();
	StructureFilter.Insert("Company", Object.Company);
	StructureFilter.Insert("Counterparty", Object.Counterparty);
	StructureFilter.Insert("IncludeTransferOrders", False);
	
	If ValueIsFilled(Object.Contract) Then
		StructureFilter.Insert("Contract", Object.Contract);
	EndIf;
	
	ParameterStructure = New Structure("Filter", StructureFilter);
	
	OpenForm("CommonForm.SelectDocumentOrder", ParameterStructure, Item);
	
EndProcedure

&AtClient
Procedure OrderChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	ProcessOrderDocumentSelection(SelectedValue);

EndProcedure

&AtClient
Procedure OrderOnChange(Item)
	
	If Object.Prepayment.Count() > 0
		AND Object.Order <> Order Then
		
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("OrderOnChangeEnd", ThisObject), NStr("en = 'Advances will be cleared. Do you want to continue?'; ru = 'Зачет аванса будет очищен, продолжить?';pl = 'Zaliczki zostaną rozliczone. Czy chcesz kontynuować?';es_ES = 'Anticipos se liquidarán. ¿Quiere continuar?';es_CO = 'Anticipos se liquidarán. ¿Quiere continuar?';tr = 'Avanslar silinecek. Devam etmek istiyor musunuz?';it = 'Gli anticipi saranno compensati. Volete continuare?';de = 'Vorauszahlungen werden gelöscht. Wollen Sie fortsetzen?'"), Mode, 0);
		Return;
		
	EndIf;
	
	If Order <> Object.Order
		And ValueIsFilled(Object.Order) Then
		SalesRep = SalesRep(Object.Order);
		If ValueIsFilled(SalesRep) Then
			For Each Row In Object.Inventory Do
				Row.SalesRep = SalesRep;
			EndDo;
		EndIf;
	EndIf;
	
	OrderOnChangeFragment();
	
EndProcedure

&AtClient
Procedure OrderOnChangeEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		Object.Prepayment.Clear();
	Else
		Object.Order = Items.Order.TypeRestriction.AdjustValue(Order);
		Return;
	EndIf;
	
	OrderOnChangeFragment();
	
EndProcedure

&AtClient
Procedure OrderOnChangeFragment()
	
	Order = Object.Order;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("OrderOnChange");
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure DeliveryOptionOnChange(Item)
	SetVisibleDeliveryAttributes();
EndProcedure

&AtClient
Procedure ShippingAddressOnChange(Item)
	ProcessShippingAddressChange();
EndProcedure

&AtClient
Procedure SalesRepOnChange(Item)
	
	If Object.Inventory.Count() > 2 Then
		
		SalesRep = Object.Inventory[0].SalesRep;
		For Each InventoryRow In Object.Inventory Do
			InventoryRow.SalesRep = SalesRep;
		EndDo;
		
	EndIf;
		
EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", False);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure GLAccountsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	GLAccountsInDocumentsClient.OpenCounterpartyGLAccountsForm(ThisObject, Object, "Header");
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure ThirdPartyPaymentOnChange(Item)
	
	DoOperationsByOrders = False;
	
	If Object.ThirdPartyPayment And IsOnlineReceiptAdvanceClearingAvailable(DoOperationsByOrders) Then
		
		If DoOperationsByOrders Then
			Message = NStr("en = 'There are Online receipts that register advances for the source Sales order. If you create a Sales invoice that requires third-party payment, you delegate a payment to a third party in full. The advances cannot be cleared. Continue?'; ru = 'Существуют онлайн-чеки, в которых регистрируются авансы для исходного заказа покупателя. Если вы создаете инвойс покупателю со сторонним платежом, оплата полностью передается третьей стороне. Авансы не могут быть погашены. Продолжить?';pl = 'Istnieją Paragony online, które rejestrują zaliczki dla źródłowego Zamówienia sprzedaży. Jeśli utworzysz Fakturę sprzedaży, która wymaga płatności trzeciej strony, przekażesz płatność stronie trzeciej w całości. Zaliczki nie mogą być rozliczone. Kontynuować?';es_ES = 'Existen Recibos en línea que registran anticipos para el Pedido de cliente de fuente. Si se crea una Factura de ventas que requiere el pago de terceros, se delega un pago a un tercero en su totalidad. Los anticipos no pueden ser liquidados. ¿Continuar?';es_CO = 'Existen Recibos en línea que registran anticipos para el Pedido de cliente de fuente. Si se crea una Factura de ventas que requiere el pago de terceros, se delega un pago a un tercero en su totalidad. Los anticipos no pueden ser liquidados. ¿Continuar?';tr = 'Kaynak Satış siparişi için avans ödemeleri kaydeden Çevrimiçi tahsilatlar var. Üçüncü taraf ödemesi gerektiren bir Satış faturası oluşturursanız, ödemeyi tamamen üçüncü tarafa aktarırsınız. Avanslar silinemez. Devam edilsin mi?';it = 'Ci sono Ricevute online che registrano pagamenti anticipati per la fonte Ordine cliente. Creando una Fattura di vendita che richiede un pagamento di terze parti, si delega pienamente un pagamento a una terza parte. I pagamenti anticipati non possono essere cancellati. Continuare?';de = 'Es gibt Onlinebelege die Vorauszahlungen aus der Quelle Kundenauftrag registrieren. Falls Sie eine Verkaufsrechnung mit der erforderlichen Zahlung von Dritten erstellen, beauftragen Sie mit einer Zahlung in vollem Umfang den Dritten. Die Vorauszahlungen können nicht gelöscht werden. Fortfahren?'");
		Else
			Message = NStr("en = 'There are Online receipts that register advances from the selected customer. If you create a Sales invoice that requires third-party payment, you delegate a payment to a third party in full. The advances cannot be cleared. Continue?'; ru = 'Существуют онлайн-чеки, в которых регистрируются авансы от выбранного покупателя. Если вы создаете инвойс покупателю со сторонним платежом, оплата полностью передается третьей стороне. Авансы не могут быть погашены. Продолжить?';pl = 'Istnieją Paragony online, które rejestrują zaliczki dla wybranego nabywcy. Jeśli utworzysz Fakturę sprzedaży, która wymaga płatności trzeciej strony, przekażesz płatność stronie trzeciej w całości. Zaliczki nie mogą być rozliczone. Kontynuować?';es_ES = 'Existen Recibos en línea que registran anticipos del cliente seleccionado. Si se crea una Factura de ventas que requiere el pago de terceros, se delega un pago a un tercero en su totalidad. Los anticipos no pueden ser liquidados. ¿Continuar?';es_CO = 'Existen Recibos en línea que registran anticipos del cliente seleccionado. Si se crea una Factura de ventas que requiere el pago de terceros, se delega un pago a un tercero en su totalidad. Los anticipos no pueden ser liquidados. ¿Continuar?';tr = 'Seçilen müşteriden alınan avans ödemeleri kaydeden Çevrimiçi tahsilatlar var. Üçüncü taraf ödemesi gerektiren bir Satış faturası oluşturursanız, ödemeyi tamamen üçüncü tarafa aktarırsınız. Avanslar silinemez. Devam edilsin mi?';it = 'Ci sono Ricevute online che registrano pagamenti anticipati dal cliente selezionato. Creando una Fattura di vendita che richiede un pagamento di terze parti, si delega pienamente un pagamento a una terza parte. I pagamenti anticipati non possono essere cancellati. Continuare?';de = 'Es gibt Onlinebelege die Vorauszahlungen von dem ausgewählten Kunden registrieren. Falls Sie eine Verkaufsrechnung mit der erforderlichen Zahlung von Dritten erstellen, beauftragen Sie mit einer Zahlung in vollem Umfang den Dritten. Die Vorauszahlungen können nicht verrechnet werden. Fortfahren?'");
		EndIf;
		
		ShowQueryBox(New NotifyDescription("ProcessOnlineReceiptsAdvancesWithThirdPartyPaymentQueryBox", ThisObject),
			Message, QuestionDialogMode.YesNo);
		
	Else
		ProcessThirdPartyPaymentChange();
	EndIf;
	
EndProcedure

&AtClient
Procedure PayerOnChange(Item)
	
	ProcessPayerChange();
	
EndProcedure

&AtClient
Procedure PayerStartChoice(Item, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(SettlementCurrency) Then
		
		StandardProcessing = False;
		
		FormParameters = New Structure;
		FormParameters.Insert("Currency", SettlementCurrency);
		FormParameters.Insert("Filter", New Structure("OtherRelationship", True));
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("CloseOnChoice", True);
		
		OpenForm("Catalog.Counterparties.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PayerContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormParameters(
		Object.Ref,
		Object.Company,
		Object.Payer, 
		PayerAttributes.DoOperationsByContracts,
		Object.PayerContract);
	
	FormParameters.Insert("Currency", SettlementCurrency);
	
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PayerCreating(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	FillingValues = New Structure("OtherRelationship, SettlementsCurrency", True, SettlementCurrency);
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode",			True);
	FormParameters.Insert("ChoiceParameters",	FillingValues);
	FormParameters.Insert("FillingValues",		FillingValues);
	
	OpenForm("Catalog.Counterparties.ObjectForm", FormParameters, Item);
	
EndProcedure

&AtClient
Procedure IsDeliveryDateInTableOnChange(Item)
	
	If IsDeliveryDateInTable Then
		Object.DeliveryDatePosition = PredefinedValue("Enum.AttributeStationing.InTabularSection");
		SetDeliveryDates();
	Else 
		Object.DeliveryDatePosition = PredefinedValue("Enum.AttributeStationing.InHeader");
		GetDeliveryDates();
	EndIf;
	
	SetDeliveryDatePeriodVisible(ThisObject);
	
EndProcedure

&AtClient
Procedure DeliveryDatePeriodOnChange(Item)
	
	If Object.DeliveryDatePeriod = PredefinedValue("Enum.DeliveryDatePeriod.Date") Then
		If IsDeliveryDateInTable Then
			For Each InventoryLine In Object.Inventory Do
				InventoryLine.DeliveryEndDate = InventoryLine.DeliveryStartDate;
			EndDo;
		Else
			Object.DeliveryEndDate = Object.DeliveryStartDate;
		EndIf;
	EndIf;
	
	SetDeliveryDatePeriodVisible(ThisObject);
	
EndProcedure

&AtClient
Procedure DeliveryDateOnChange(Item)
	
	If Object.DeliveryDatePeriod = PredefinedValue("Enum.DeliveryDatePeriod.Date")
		Or Object.DeliveryEndDate < Object.DeliveryStartDate Then
		Object.DeliveryEndDate = Object.DeliveryStartDate;
	EndIf;
	
	SetDeliveryDatePeriodVisible(ThisObject);
	
EndProcedure

&AtClient
Procedure DeliveryEndDateOnChange(Item)
	
	If Object.DeliveryEndDate < Object.DeliveryStartDate Then
		Object.DeliveryStartDate = Object.DeliveryEndDate;
	EndIf;
	
	SetDeliveryDatePeriodVisible(ThisObject);
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableInventory

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
			
		ElsIf TableCurrentColumn.Name = "InventoryIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			
			SelectedRow = Items.Inventory.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Inventory");
			
		EndIf;
		
	EndIf;
	
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
Procedure InventoryProductsOnChange(Item)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesInvoice.ZeroInvoice") Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", True);
		ParametersStructure.Insert("FillHeader", False);
		ParametersStructure.Insert("FillInventory", True);
		ParametersStructure.Insert("FillAmountAllocation", True);
		
		FillAddedColumns(ParametersStructure);
		
		Return;
		
	EndIf;
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Inventory", TabularSectionRow);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate"		, Object.Date);
		StructureData.Insert("DocumentCurrency"		, Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT"	, Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind"			, Object.PriceKind);
		StructureData.Insert("Factor"				, 1);
		StructureData.Insert("DiscountMarkupKind"	, Object.DiscountMarkupKind);
	
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	// End DiscountCards
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Inventory", StructureData);
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData, Object.Date);
	
	// Bundles
	If StructureData.IsBundle And Not StructureData.UseCharacteristics Then
		
		ReplaceInventoryLineWithBundleData(ThisObject, TabularSectionRow, StructureData);
		ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
		RecalculateSubtotal();
		
	Else
	// End Bundles
	
		FillPropertyValues(TabularSectionRow, StructureData); 
		ThisIsNewRow = False;
		
		TabularSectionRow.Quantity				= 1;
		TabularSectionRow.Content				= "";
		TabularSectionRow.ProductsTypeInventory = StructureData.ProductsTypeInventory;
		
		// Serial numbers
		WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,,UseSerialNumbersBalance);
		
		CalculateAmountInTabularSectionLine();
	
	// Bundles
	EndIf;
	// End Bundles
EndProcedure

&AtClient
Procedure InventoryProductsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Item.Parent.CurrentData;
	
	ParametersFormProducts = New Structure;
	
	If ValueIsFilled(Object.StructuralUnit) Then
		ParametersFormProducts.Insert("FilterWarehouse", Object.StructuralUnit);
	EndIf;
	
	If ValueIsFilled(Object.Company) Then
		ParametersFormProducts.Insert("FilterBalancesCompany", Object.Company);
	EndIf; 
	
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

&AtClient
Procedure InventoryProductsStartChoiceEnd(ResultValue, AdditionalParameters) Export
	
	If ResultValue = Undefined Then
		Return;
	EndIf;
	
	AdditionalParameters.CurrentData.Products = ResultValue;
	
	InventoryProductsOnChange(AdditionalParameters.Item);
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
		
	StructureData = New Structure;
	StructureData.Insert("Company", 				Object.Company);
	StructureData.Insert("Products",	TabularSectionRow.Products);
	StructureData.Insert("Characteristic",		TabularSectionRow.Characteristic);
		
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",		Object.Date);
		StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
		StructureData.Insert("Price",			 	TabularSectionRow.Price);
		
		StructureData.Insert("PriceKind",		Object.PriceKind);
		StructureData.Insert("MeasurementUnit",	TabularSectionRow.MeasurementUnit);
		
	EndIf;
	
	AddIncomeAndExpenseItemsToStructure(ThisObject, "Inventory", StructureData);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Inventory", StructureData);
	EndIf;
	
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date);
	
	If StructureData.Property("Specification") Then
		TabularSectionRow.Specification = StructureData.Specification;
	EndIf;
	
	// Bundles
	If StructureData.IsBundle Then
		
		ReplaceInventoryLineWithBundleData(ThisObject, TabularSectionRow, StructureData);
		ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
		RecalculateSubtotal();
	Else
	// End Bundles

		TabularSectionRow.Price		= StructureData.Price;
		TabularSectionRow.Content	= "";
		
		CalculateAmountInTabularSectionLine();
	
	// Bundles
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
		SelectionParameters	= DriveClient.GetMatrixParameters(ThisObject, TabularSectionName, True);
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
Procedure InventoryBatchOnChange(Item)
	
	InventoryBatchOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure InventoryBatchOnChangeAtClient()
	
	TabRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	AddIncomeAndExpenseItemsToStructure(ThisObject, "Inventory", StructureData);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Inventory", StructureData);
	EndIf;
	
	StructureData.Insert("Products", TabRow.Products);
	
	InventoryBatchOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
EndProcedure

&AtServer
Procedure InventoryBatchOnChangeAtServer(StructureData)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	StructureData.Insert("ObjectParameters", ObjectParameters);
	
	ProductsTypeInventory = 
		(Common.ObjectAttributeValue(StructureData.Products, "ProductsType") = Enums.ProductsTypes.InventoryItem);
		
	StructureData.Insert("ProductsTypeInventory", ProductsTypeInventory);
	
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryContentAutoComplete(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow	= Items.Inventory.CurrentData;
		ContentPattern		= DriveServer.GetContentText(TabularSectionRow.Products, TabularSectionRow.Characteristic);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryGoodsIssueChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	InventoryGoodsIssueChoiceEnd(SelectedValue);
	
EndProcedure

&AtServer
Procedure InventoryGoodsIssueOnChangeAtServer(StructureData)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	StructureData.Insert("ObjectParameters", ObjectParameters);
	
	ProductsTypeInventory = 
		(Common.ObjectAttributeValue(StructureData.Products, "ProductsType") = Enums.ProductsTypes.InventoryItem);
		
	StructureData.Insert("ProductsTypeInventory", ProductsTypeInventory);
	
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryGoodsIssueOnChange(Item)
	
	TabRow = Items.Inventory.CurrentData;
	InventoryGoodsIssueChoiceEnd(TabRow.GoodsIssue);
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
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
	
	// Price.
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine();
	
	TabularSectionRow.MeasurementUnit = ValueSelected;
	
EndProcedure

&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

&AtClient
Procedure InventoryDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	// Discount.
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Price = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / ((1 - TabularSectionRow.DiscountMarkupPercent / 100) * TabularSectionRow.Quantity);
	EndIf;
	
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculateSalesTax();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RefillDiscountAmountOfEPD();
	RecalculateSubtotal();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RefillDiscountAmountOfEPD();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RefillDiscountAmountOfEPD();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure InventoryDeliveryDateOnChange(Item)
	
	InventoryLine = Items.Inventory.CurrentData;
	InventoryLine.DeliveryEndDate = InventoryLine.DeliveryStartDate;
	
EndProcedure

&AtClient
Procedure InventoryDeliveryStartDateOnChange(Item)
	
	InventoryLine = Items.Inventory.CurrentData;
	
	If InventoryLine.DeliveryEndDate < InventoryLine.DeliveryStartDate Then
		InventoryLine.DeliveryEndDate = InventoryLine.DeliveryStartDate;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryDeliveryEndDateOnChange(Item)
	
	InventoryLine = Items.Inventory.CurrentData;
	
	If InventoryLine.DeliveryEndDate < InventoryLine.DeliveryStartDate Then
		InventoryLine.DeliveryStartDate = InventoryLine.DeliveryEndDate;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Inventory", StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableConsumerMaterials

&AtClient
Procedure ConsumerMaterialsCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	// Bundles
	CurrentRow = Items.ConsumerMaterials.CurrentData;
	
	If DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "ConsumerMaterials";
		SelectionParameters	= DriveClient.GetMatrixParameters(ThisObject, TabularSectionName, False);
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

#EndRegion

#Region FormItemEventHandlersFormTablePrepayment

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

&AtClient
Procedure PrepaymentExchangeRateOnChange(Item)
	
	CalculatePrepaymentPaymentAmount();
	
EndProcedure

&AtClient
Procedure PrepaymentMultiplicityOnChange(Item)
	
	CalculatePrepaymentPaymentAmount();
	
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

#Region FormItemEventHandlersFormTableAmountAllocation

&AtClient
Procedure AmountAllocationSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableSelection(ThisObject, "AmountAllocation", SelectedRow, Field, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure AmountAllocationOnActivateCell(Item)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnActivateCell(ThisObject, "AmountAllocation", ThisIsNewRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure AmountAllocationOnStartEdit(Item, NewRow, Clone)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	EndIf;
	
EndProcedure

&AtClient
Procedure AmountAllocationOnEditEnd(Item, NewRow, CancelEdit)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnEditEnd(ThisIsNewRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure AmountAllocationGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	GLAccountsInDocumentsClient.GLAccountsStartChoice(ThisObject, "AmountAllocation", StandardProcessing);  
	
EndProcedure

&AtClient
Procedure AmountAllocationDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.AmountAllocation.CurrentData;
	
	If TabularSectionRow.AdvanceFlag Then
		
		ShowMessageBox(, NStr("en = 'Document is not required for an advance payment.'; ru = 'Для авансового платежа документ не требуется.';pl = 'Dokument nie jest wymagany dla zaliczki.';es_ES = 'El documento no es necesario para el pago adelantado.';es_CO = 'El documento no es necesario para el pago adelantado.';tr = 'Avans ödeme için belge gerekli değil.';it = 'Il documento non è richiesto per il pagamento di anticipo.';de = 'Für eine Vorauszahlung ist kein Dokument erforderlich.'"));
		
	Else
		
		StructureFilter = New Structure();
		StructureFilter.Insert("Company",			Object.Company);
		StructureFilter.Insert("Counterparty",		Object.Counterparty);
		StructureFilter.Insert("Contract",			Object.Contract);
		StructureFilter.Insert("DocumentCurrency",	Object.DocumentCurrency);
		
		ParameterStructure = New Structure("Filter, ThisIsAccountsReceivable, DocumentType",
											StructureFilter,
											True,
											TypeOf(Object.Ref));
		
		OpenForm("CommonForm.SelectDocumentOfSettlements", ParameterStructure, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AmountAllocationDocumentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	ProcessAccountsDocumentSelection(SelectedValue);
	
EndProcedure

#EndRegion

#Region TableEventHandlers

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies();
		
EndProcedure

&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		MessagesToUserClient.ShowMessageSelectBaseDocument();
		Return;
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'Do you want to refill the sales invoice?'; ru = 'Инвойс покупателю будет перезаполнен. Продолжить?';pl = 'Czy chcesz uzupełnić fakturę sprzedaży?';es_ES = '¿Quiere volver a rellenar la factura de ventas?';es_CO = '¿Quiere volver a rellenar la factura de ventas?';tr = 'Satış faturasını yeniden doldurmak istiyor musunuz?';it = 'Volete ricompilare la fattura di vendita?';de = 'Möchten Sie die Verkaufsrechnung auffüllen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		FillByDocument(Object.BasisDocument);
		SetVisibleEnablePaymentTermItems();
	EndIf;

EndProcedure

&AtClient
Procedure FillByOrder(Command)
	
	If ValueIsFilled(Object.Order) Then
		
		Response = Undefined;
		
		If TypeOf(Object.Order) = Type("DocumentRef.SalesOrder") Then
			Message = NStr("en = 'The document will be repopulated from the selected Sales order. Do you want to continue?'; ru = 'Документ будет перезаполнен из выбранного заказа покупателя. Продолжить?';pl = 'Dokument zostanie ponownie wypełniony z wybranego Zamówienia sprzedaży. Czy chcesz kontynuować?';es_ES = 'El documento se volverá a rellenar de la orden de ventas seleccionada. ¿Quiere continuar?';es_CO = 'El documento se volverá a rellenar de la orden de ventas seleccionada. ¿Quiere continuar?';tr = 'Belge, seçilen Satış siparişinden tekrar doldurulacak. Devam etmek istiyor musunuz?';it = 'Il documento sarà ripopolato dall''Ordine cliente selezionato. Continuare?';de = 'Das Dokument wird aus dem ausgewählten Kundenauftrag neu aufgefüllt. Möchten Sie fortsetzen?'");
		ElsIf TypeOf(Object.Order) = Type("DocumentRef.WorkOrder") Then
			Message = NStr("en = 'The document will be repopulated from the selected Work order. Do you want to continue?'; ru = 'Документ будет перезаполнен из выбранного заказ-наряда. Продолжить?';pl = 'Dokument zostanie ponownie wypełniony z wybranego Zlecenia pracy. Czy chcesz kontynuować?';es_ES = 'El documento se volverá a rellenar de la orden de trabajo seleccionada. ¿Quiere continuar?';es_CO = 'El documento se volverá a rellenar de la orden de trabajo seleccionada. ¿Quiere continuar?';tr = 'Belge, seçilen İş emrinden tekrar doldurulacak. Devam etmek istiyor musunuz?';it = 'Il documento sarà ripopolato a partire dalla commessa selezionata. Continuare?';de = 'Das Dokument wird aus dem ausgewählten Arbeitsauftrag neu aufgefüllt. Möchten Sie fortsetzen?'");
		EndIf;
		
		ShowQueryBox(New NotifyDescription("FillByOrderEnd", ThisObject), Message, QuestionDialogMode.YesNo, 0);
	Else
		MessagesToUserClient.ShowMessageSelectOrder();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByOrderEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		Object.Inventory.Clear();
		FillByDocument(Object.Order);
		SetVisibleAndEnabled();
	EndIf;
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffset(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en = 'Please specify the customer.'; ru = 'Укажите контрагента!';pl = 'Określ klienta.';es_ES = 'Por favor, especifique el cliente.';es_CO = 'Por favor, especifique el cliente.';tr = 'Lütfen, müşteri belirtin.';it = 'Si prega di specificare il cliente.';de = 'Bitte geben Sie den Kunden an.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Contract) Then
		ShowMessageBox(, NStr("en = 'Please specify the contract.'; ru = 'Укажите договор контрагента!';pl = 'Określ umowę.';es_ES = 'Por favor, especifique el contrato.';es_CO = 'Por favor, especifique el contrato.';tr = 'Lütfen, sözleşmeyi belirtin.';it = 'Per piacere specificate il contratto.';de = 'Bitte geben Sie den Vertrag an.'"));
		Return;
	EndIf;
	
	OrdersArray = New Array;
	For Each CurItem In Object.Inventory Do
		OrderStructure = New Structure("Order, Total");
		OrderStructure.Order = ?(CurItem.Order = Undefined, PredefinedValue("Document.SalesOrder.EmptyRef"), CurItem.Order);
		OrderStructure.Total = CurItem.Total;
		OrdersArray.Add(OrderStructure);
	EndDo;
	
	AddressPrepaymentInStorage = PlacePrepaymentToStorage();
	
	OrderParameter = ?(CounterpartyAttributes.DoOperationsByOrders, ?(OrderInHeader, Object.Order, OrdersArray), Undefined);
	
	SelectionParameters = New Structure;
	SelectionParameters.Insert("AddressPrepaymentInStorage", AddressPrepaymentInStorage);
	SelectionParameters.Insert("Pick", True);
	SelectionParameters.Insert("IsOrder", True);
	SelectionParameters.Insert("OrderInHeader", OrderInHeader);
	SelectionParameters.Insert("Company", ParentCompany);
	SelectionParameters.Insert("Order", OrderParameter);
	SelectionParameters.Insert("Date", Object.Date);
	SelectionParameters.Insert("Ref", Object.Ref);
	SelectionParameters.Insert("Counterparty", Object.Counterparty);
	SelectionParameters.Insert("Contract", Object.Contract);
	SelectionParameters.Insert("ContractCurrencyExchangeRate", Object.ContractCurrencyExchangeRate);
	SelectionParameters.Insert("ContractCurrencyMultiplicity", Object.ContractCurrencyMultiplicity);
	SelectionParameters.Insert("DocumentCurrency", Object.DocumentCurrency);
	SelectionParameters.Insert("ExchangeRate", Object.ExchangeRate);
	SelectionParameters.Insert("Multiplicity", Object.Multiplicity);
	SelectionParameters.Insert("DocumentAmount", Object.Inventory.Total("Total"));
	
	ReturnCode = Undefined;
	OpenForm("CommonForm.SelectAdvancesReceivedFromTheCustomer",
		SelectionParameters,,,,,
		New NotifyDescription("EditPrepaymentOffsetEnd",
			ThisObject,
			New Structure("AddressPrepaymentInStorage, SelectionParameters", AddressPrepaymentInStorage, SelectionParameters)));
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetEnd(Result, AdditionalParameters) Export
	
	AddressPrepaymentInStorage = AdditionalParameters.AddressPrepaymentInStorage;
	SelectionParameters = AdditionalParameters.SelectionParameters;
	
	ReturnCode = Result;
	
	EditPrepaymentOffsetFragment(AddressPrepaymentInStorage, ReturnCode);
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetFragment(Val AddressPrepaymentInStorage, Val ReturnCode)
	
	If ReturnCode = DialogReturnCode.OK Then
		GetPrepaymentFromStorage(AddressPrepaymentInStorage);
		Modified = True;
		PrepaymentWasChanged = True;
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
		
		ShowMessageBox(Undefined, NStr("en = 'Select a line to get the weight for.'; ru = 'Необходимо выбрать строку, для которой необходимо получить вес.';pl = 'Wybierz wiersz, aby uzyskać wagę.';es_ES = 'Seleccionar una línea para obtener el peso para.';es_CO = 'Seleccionar una línea para obtener el peso para.';tr = 'Ağırlığı alınacak bir satır seçin.';it = 'Selezionare una linea per ottenere il peso.';de = 'Wählen Sie eine Linie aus, für die das Gewicht ermittelt werden soll.'"));
		
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
			MessageText = NStr("en = 'The electronic scale returned zero weight.'; ru = 'Электронные весы вернули нулевой вес.';pl = 'Waga elektroniczna zwróciła wagę zerową.';es_ES = 'Las escalas electrónicas han devuelto el peso cero.';es_CO = 'Las escalas electrónicas han devuelto el peso cero.';tr = 'Elektronik tartı sıfır ağırlık gösteriyor.';it = 'La bilancia elettronica ha dato peso pari a zero.';de = 'Die elektronische Waage gab Nullgewicht zurück.'");
			CommonClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
			CalculateAmountInTabularSectionLine(TabularSectionRow);
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

// Procedure - clicking handler on the hyperlink InvoiceText.
//
&AtClient
Procedure TaxInvoiceTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithVATClient.OpenTaxInvoice(ThisForm);
	
EndProcedure

&AtClient
Procedure DocumentSetup(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("SalesOrderPositionInShipmentDocuments", 	Object.SalesOrderPosition);
	ParametersStructure.Insert("WereMadeChanges",							False);
	
	InvCount = Object.Inventory.Count();
	If InvCount > 1 Then
		CurrOrder = Object.Inventory[0].Order;
		MultipleOrders = False;
		For Index = 1 To InvCount - 1 Do
			If CurrOrder <> Object.Inventory[Index].Order Then
				MultipleOrders = True;
				Break;
			EndIf;
			CurrOrder = Object.Inventory[Index].Order;
		EndDo;
		If MultipleOrders Then
			ParametersStructure.Insert("ReadOnly", True);
		EndIf;
	EndIf;
	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.SalesOrderPosition = StructureDocumentSetting.SalesOrderPositionInShipmentDocuments;
		If Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
			If Object.Inventory.Count() Then
				
				FirstRow = Object.Inventory[0];
				Object.Order = FirstRow.Order;
				SalesRep = FirstRow.SalesRep;
				
				For Each InventoryRow In Object.Inventory Do
					InventoryRow.SalesRep = SalesRep;
				EndDo;
				
			EndIf;
		ElsIf Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InTabularSection") Then
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
		SetVisibleSalesRep();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeReserveFillByReserves(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'There are no products to reserve.'; ru = 'Табличная часть ""Товары"" не заполнена!';pl = 'Brak produktów do zarezerwowania.';es_ES = 'No hay productos para reservar.';es_CO = 'No hay productos para reservar.';tr = 'Rezerve edilecek ürün yok.';it = 'Non ci sono articoli da riservare.';de = 'Es gibt keine Produkte zu reservieren.'");
		Message.Message();
		Return;
	EndIf;
	
	FillColumnReserveByReservesAtServer();
	
	// Bundles
	SetBundlePictureVisible();
	SetBundleConditionalAppearance();
	// End Bundles
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", False);
	
	FillAddedColumns(ParametersStructure);

EndProcedure

&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'There is nothing to clear.'; ru = 'Невозможно заполнить колонку ""Резерв"", потому что табличная часть ""Запасы и услуги"" не заполнена!';pl = 'Nie ma nic do wyczyszczenia.';es_ES = 'No hay nada para liquidar.';es_CO = 'No hay nada para liquidar.';tr = 'Temizlenecek bir şey yok.';it = 'Non c''è nulla da cancellare.';de = 'Es gibt nichts zu löschen.'");
		Message.Message();
		Return;
	EndIf;
	
	For Each TabularSectionRow In Object.Inventory Do
		
		If TabularSectionRow.ProductsTypeInventory Then
			TabularSectionRow.Reserve = 0;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure InventoryGoodsIssueStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ParametersStructure = New Structure;
	
	If Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
		ParametersStructure.Insert("OrderFilter", Object.Order);
	Else
		ParametersStructure.Insert("OrderFilter", Items.Inventory.CurrentData.Order);
	EndIf;
	
	NotifyDescription = New NotifyDescription("InventoryGoodsIssueChoiceEnd", ThisObject);
	
	OpenForm("Document.GoodsIssue.ChoiceForm", ParametersStructure, ThisObject,,,, NotifyDescription);
	
EndProcedure

&AtClient
Procedure InventoryGoodsIssueChoiceEnd(SelectedValue, AdditionalParameters = Undefined) Export
	
	If SelectedValue = Undefined Then
		Return;
	EndIf;
	
	TabRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	AddIncomeAndExpenseItemsToStructure(ThisObject, "Inventory", StructureData);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Inventory", StructureData);
	EndIf;
	
	StructureData.Insert("Products", TabRow.Products);
	StructureData.Insert("GoodsIssue", SelectedValue);

	InventoryGoodsIssueOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	
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
Procedure CheckVATNumber(Command)
	
	CheckVATNumberAtServer();
	Notify("VATNumberWasChecked", Object.Counterparty);
	
EndProcedure

&AtClient
Procedure FillSalesTax(Command)
	
	RecalculateSalesTax();
	
EndProcedure

&AtClient
Procedure EditOwnership(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TempStorageAddress", PutEditOwnershipDataToTempStorage());
	
	OpenForm("CommonForm.InventoryOwnership", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure FillInAmountAllocation(Command)
	
	If Object.DocumentAmount >= 0 Then
		Return;
	EndIf;
	
	Response = Undefined;
	
	If Object.AmountAllocation.Count() <> 0 Then
		ShowQueryBox(New NotifyDescription("FillAllocationEnd", ThisObject), 
						NStr("en = 'The Amount allocation tab will be repopulated. Do you want to continue?'; ru = 'Вкладка Распределение суммы будет перезаполнена. Продолжить?';pl = 'Karta ""Opis transakcji"" zostanie wypełniona ponownie. Czy chcesz kontynuować?';es_ES = 'La pestaña Asignación de cantidad será rellenada. ¿Quiere continuar?';es_CO = 'La pestaña Asignación de cantidad será rellenada. ¿Quiere continuar?';tr = 'Tutar paylaştırma sekmesi yeniden doldurulacak. Devam etmek istiyor musunuz?';it = 'La scheda Allocazione importo sarà ricompilata. Continuare?';de = 'Die Registerkarte Verteilung wird neu ausgefüllt. Möchten Sie fortfahren?'"),
						QuestionDialogMode.YesNo);
	Else
		FillAmountAllocation();
	EndIf;
	
EndProcedure

#EndRegion

#Region TabularSectionCommandpanelsActions

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CommandFillBySpecification(Command)
	
	If Object.ConsumerMaterials.Count() <> 0 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("CommandToFillBySpecificationEnd", ThisObject),
						NStr("en = 'Tabular section ""Stock received from third-party"" will be filled in again. Do you want to continue?'; ru = 'Табличная часть ""Материалы, полученные от сторонних организаций"" будет перезаполнена. Вы хотите продолжить?';pl = 'Sekcja tabelaryczna ""Otrzymane zapasy od strony trzeciej"" zostanie ponownie wypełniona. Czy chcesz kontynuować?';es_ES = 'La sección tabular ""Stock recibido de un tercero"" se rellenará de nuevo. ¿Quieres continuar?';es_CO = 'La sección tabular ""Stock recibido de un tercero"" se rellenará de nuevo. ¿Quieres continuar?';tr = '“Üçüncü taraflardan alınan stok” başlıklı Tablo bölümü tekrar doldurulacaktır. Devam etmek istiyor musunuz?';it = 'Sezione tabella ""Merci ricevute da terze parti"" sarà compilato nuovamente. Volete continuare?';de = 'Der tabellarische Abschnitt ""Von Dritten erhaltener Bestand"" wird erneut ausgefüllt. Möchten Sie fortsetzen?'"), 
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
Procedure CommandFillByGoodsConsumed(Command)
	
	If Object.ConsumerMaterials.Count() <> 0 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("CommandToFillByGoodsConsumedEnd", ThisObject),
						NStr("en = 'Tabular section ""Stock received from third-party"" will be filled in again. Do you want to continue?'; ru = 'Табличная часть ""Материалы, полученные от сторонних организаций"" будет перезаполнена. Вы хотите продолжить?';pl = 'Sekcja tabelaryczna ""Otrzymane zapasy od strony trzeciej"" zostanie ponownie wypełniona. Czy chcesz kontynuować?';es_ES = 'La sección tabular ""Stock recibido de un tercero"" se rellenará de nuevo. ¿Quieres continuar?';es_CO = 'La sección tabular ""Stock recibido de un tercero"" se rellenará de nuevo. ¿Quieres continuar?';tr = '“Üçüncü taraflardan alınan stok” başlıklı Tablo bölümü tekrar doldurulacaktır. Devam etmek istiyor musunuz?';it = 'Sezione tabella ""Merci ricevute da terze parti"" sarà compilato nuovamente. Volete continuare?';de = 'Der tabellarische Abschnitt ""Von Dritten erhaltener Bestand"" wird erneut ausgefüllt. Möchten Sie fortsetzen?'"), 
						QuestionDialogMode.YesNo, 0);
        Return;
		
	EndIf;
	
	CommandToFillByGoodsConsumedFragment();
EndProcedure

&AtClient
Procedure CommandToFillByGoodsConsumedEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    CommandToFillByGoodsConsumedFragment();

EndProcedure

&AtClient
Procedure CommandToFillByGoodsConsumedFragment()
    
    FillByGoodsConsumedAtServer();

EndProcedure


#EndRegion

#Region Private

#Region ServiceProceduresAndFunctions

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.InventoryPrice);
	Fields.Add(Items.IssuedInvoicesPrice);
	
	Return Fields;
	
EndFunction

&AtClient
Procedure ProcessOnlineReceiptsAdvancesWithThirdPartyPaymentQueryBox(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		ProcessThirdPartyPaymentChange();
	Else
		Object.ThirdPartyPayment = False;
	EndIf;
	
EndProcedure

&AtServer
Function IsOnlineReceiptAdvanceClearingAvailable(DoOperationsByOrders)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		Return False;
	EndIf;
	
	DoOperationsByOrders = Common.ObjectAttributeValue(Object.Counterparty, "DoOperationsByOrders");
	
	OrdersToBeChecked = New Array;
	If DoOperationsByOrders Then
		If Object.SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
			OrdersToBeChecked = Object.Inventory.Unload().UnloadColumn("Order");
		Else
			OrdersToBeChecked.Add(Object.Order);
		EndIf;
	EndIf;
	
	Query = New Query;
	
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	AccountsReceivableBalance.AmountCurBalance AS AmountCurBalance
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND Contract = &Contract
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|				AND Document REFS Document.OnlineReceipt
	|				AND (NOT &DoOperationsByOrders
	|					OR Order IN (&OrdersToBeChecked))) AS AccountsReceivableBalance
	|WHERE
	|	AccountsReceivableBalance.AmountCurBalance < 0
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	AccountsReceivable.AmountCur
	|FROM
	|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	AccountsReceivable.Recorder = &Ref
	|	AND AccountsReceivable.Active
	|	AND AccountsReceivable.Company = &Company
	|	AND AccountsReceivable.Counterparty = &Counterparty
	|	AND AccountsReceivable.Contract = &Contract
	|	AND AccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|	AND AccountsReceivable.Document REFS Document.OnlineReceipt
	|	AND (NOT &DoOperationsByOrders
	|			OR AccountsReceivable.Order IN (&OrdersToBeChecked))
	|	AND AccountsReceivable.AmountCur > 0";
	
	Query.SetParameter("Ref", Object.Ref);
	Query.SetParameter("Company", Object.Company);
	Query.SetParameter("Counterparty", Object.Counterparty);
	Query.SetParameter("Contract", Object.Contract);
	Query.SetParameter("DoOperationsByOrders", DoOperationsByOrders);
	Query.SetParameter("OrdersToBeChecked", OrdersToBeChecked);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtClient
Procedure ProcessThirdPartyPaymentChange()
	
	SetVisibleThirdPartyPayer();
	SetVisibleThirdPartyPayerContract();
	
	SetVisiblePrepaymentAndPaymentCalendar();
	SetVisibleEarlyPaymentDiscounts();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", False);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

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

&AtClient
Procedure ProcessAccountsDocumentSelection(DocumentData)
	
	TabularSectionRow = Items.AmountAllocation.CurrentData;
	If TypeOf(DocumentData) = Type("Structure") Then
		
		TabularSectionRow.Document = DocumentData.Document;
		TabularSectionRow.Order = DocumentData.Order;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillAllocationEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Object.AmountAllocation.Clear();
	FillAmountAllocation();
	
EndProcedure

&AtServer
Procedure FillAmountAllocation()
	
	Document = FormAttributeToValue("Object");
	Document.FillAmountAllocation();
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillInventory", False);
	ParametersStructure.Insert("FillAmountAllocation", True);
	FillAddedColumns(ParametersStructure);
	
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", False);
	FillAddedColumns(ParametersStructure);
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_Selected()
	
	Params = New Structure;
	Params.Insert("TableName", "Inventory");
	Params.Insert("BatchOnChangeHandler", True);
	Params.Insert("QuantityOnChangeHandler", True);
	
	BatchesClient.FillBatchesByFEFO_Selected(ThisObject, Params);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_All()
	
	Params = New Structure;
	Params.Insert("TableName", "Inventory");
	Params.Insert("BatchOnChangeHandler", True);
	Params.Insert("QuantityOnChangeHandler", True);
	
	BatchesClient.FillBatchesByFEFO_All(ThisObject, Params);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_BatchOnChange(TableName) Export
	
	InventoryBatchOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_QuantityOnChange(TableName, RowData) Export
	
	CalculateAmountInTabularSectionLine(RowData);
	
EndProcedure

&AtClient
Function Attachable_FillByFEFOData(TableName, ShowMessages) Export
	
	Return FillByFEFOData(ShowMessages);
	
EndFunction

&AtServer
Function FillByFEFOData(ShowMessages)
	
	Params = New Structure;
	Params.Insert("CurrentRow", Object.Inventory.FindByID(Items.Inventory.CurrentRow));
	Params.Insert("StructuralUnit", Object.StructuralUnit);
	Params.Insert("ShowMessages", ShowMessages);
	
	If Not BatchesServer.FillByFEFOApplicable(Params) Then
		Return Undefined;
	EndIf;
	
	Params.Insert("Object", Object);
	Params.Insert("Company", Object.Company);
	Params.Insert("Cell", Object.Cell);
	If Object.SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		Params.Insert("SalesOrder", Object.Order);
	Else
		Params.Insert("SalesOrder", "Order");
	EndIf;
	
	Return BatchesServer.FillByFEFOData(Params);
	
EndFunction

&AtServer
Procedure EditOwnershipProcessingAtServer(TempStorageAddress)
	
	OwnershipTable = GetFromTempStorage(TempStorageAddress);
	
	Object.InventoryOwnership.Load(OwnershipTable);
	
EndProcedure

&AtClient
Procedure EditOwnershipProcessingAtClient(TempStorageAddress)
	
	EditOwnershipProcessingAtServer(TempStorageAddress);
	
EndProcedure

&AtServer
Function PutEditOwnershipDataToTempStorage()
	
	DocObject = FormAttributeToValue("Object");
	DataForOwnershipForm = InventoryOwnershipServer.GetDataForInventoryOwnershipForm(DocObject);
	TempStorageAddress = PutToTempStorage(DataForOwnershipForm, UUID);
	Return TempStorageAddress;
	
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
Procedure FillVATValidationAttributes()
	
	If GetFunctionalOption("UseVIESVATNumberValidation") Then
		WorkWithVIESServer.FillVATValidationAttributes(ThisObject, Object.Counterparty);
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	SetVisibleTaxAttributes();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
	RecalculateSubtotal();
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	SetContractVisible();
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange();
	
	If ValueIsFilled(SettlementCurrency) Then
		RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
	EndIf;	
	
	// Generate price and currency label.
	GenerateLabelPricesAndCurrency(ThisObject);
	
	// DiscountCards
	// In this procedure call not modal window of question is occurred.
	RecalculateDiscountPercentAtDocumentDateChange();
	// End DiscountCards
	
	// AutomaticDiscounts
	DocumentDateChangedManually = True;
	ClearCheckboxDiscountsAreCalculatedClient("DateOnChange");
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Function GetDataDateOnChange()
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
	
	StructureData = New Structure;
	StructureData.Insert("CurrencyRateRepetition", CurrencyRateRepetition);
	
	If Object.DocumentCurrency <> SettlementCurrency Then
		
		SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date, SettlementCurrency, Object.Company);
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", SettlementsCurrencyRateRepetition);
		
	Else
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", CurrencyRateRepetition);
		
	EndIf;
	
	SetAccountingPolicyValues();
	
	PaymentTermsServer.ShiftPaymentCalendarDates(Object, ThisObject);
	EarlyPaymentDiscountsClientServer.ShiftEarlyPaymentDiscountsDates(Object);
	
	ProcessingCompanyVATNumbers();
	
	FillVATRateByCompanyVATTaxation();
	FillSalesTaxRate();
	SetAutomaticVATCalculation();
	SetVisibleTaxInvoiceText();
	SetVisibleAndEnabled();
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetDataCompanyOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Object.Company));
	
	ResponsiblePersons = DriveServer.OrganizationalUnitsResponsiblePersons(Object.Company, Object.Date);
	
	StructureData.Insert("ChiefAccountant"   , ResponsiblePersons.ChiefAccountant);
	StructureData.Insert("Released"          , ResponsiblePersons.WarehouseSupervisor);
	StructureData.Insert("ReleasedPosition"  , ResponsiblePersons.WarehouseSupervisorPositionRef);
	StructureData.Insert("ExchangeRateMethod", DriveServer.GetExchangeMethod(Object.Company));
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
	SetAccountingPolicyValues();
	
	ProcessingCompanyVATNumbers(False);
	
	FillVATRateByCompanyVATTaxation();
	FillSalesTaxRate();
	SetAutomaticVATCalculation();
	SetVisibleTaxInvoiceText();
	SetVisibleAndEnabled();
	
	InformationRegisters.AccountingSourceDocuments.CheckNotifyTypesOfAccountingProblems(
		Object.Ref,
		Object.Company,
		DocumentDate);

	Return StructureData;
	
EndFunction

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
	
	ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products,
		"MeasurementUnit, ProductsType, VATRate, ReplenishmentMethod, Description, Taxable");
	
	StructureData.Insert("MeasurementUnit", ProductsAttributes.MeasurementUnit);
	StructureData.Insert("ProductsTypeInventory", ProductsAttributes.ProductsType = PredefinedValue("Enum.ProductsTypes.InventoryItem"));
	StructureData.Insert("ProductDescription", ProductsAttributes.Description);
	
	If StructureData.Property("VATTaxation") 
		AND Not StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		If StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
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
		StructureData.Insert("Taxable", ProductsAttributes.Taxable);
	EndIf;
	
	If Not ObjectDate = Undefined Then
		Specification = Undefined;
		If ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly
			Or ProductsAttributes.ProductsType = Enums.ProductsTypes.Work Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Assembly);
		EndIf;
		If ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production
			Or ProductsAttributes.ProductsType = Enums.ProductsTypes.Work
				And Not ValueIsFilled(Specification) Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Production);
		EndIf;
		StructureData.Insert("Specification", Specification);
		
		StructureData.Insert("ProductDescription", ProductsAttributes.Description);
		
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
	
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	// Bundles
	BundlesServer.AddBundleInformationOnGetProductsData(StructureData, True);
	// End Bundles
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData, ObjectDate = Undefined)
	
	If StructureData.Property("PriceKind")
		And StructureData.MeasurementUnit = Undefined Then 
		
		StructureData.Insert("Price", 0);
		
	ElsIf StructureData.Property("PriceKind") Then
		
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
			StructureData.Insert("Factor", 1);
		Else
			StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
		EndIf;
		
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	If Not ObjectDate = Undefined Then
		
		ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products, "ReplenishmentMethod, ProductsType");
		Specification = Undefined;
		If ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly
			Or ProductsAttributes.ProductsType = Enums.ProductsTypes.Work Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Assembly);
		EndIf;
		If ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production
			Or ProductsAttributes.ProductsType = Enums.ProductsTypes.Work
				And Not ValueIsFilled(Specification) Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				Enums.OperationTypesProductionOrder.Production);
		EndIf;
		StructureData.Insert("Specification", Specification);
		
	EndIf;
	
	// Bundles
	BundlesServer.AddBundleInformationOnGetProductsData(StructureData, True);
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

&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	FillVATRateByCompanyVATTaxation(True);
	FillSalesTaxRate();
	
	StructureData = GetDataContractOnChange(Date, DocumentCurrency, ContractByDefault, Company);
	
	StructureData.Insert("Contract", ContractByDefault);
	StructureData.Insert("CallFromProcedureAtCounterpartyChange", True);
	StructureData.Insert("DirectDebitMandate", ContractByDefault.DirectDebitMandate);
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetDataContractOnChange(Date, DocumentCurrency, Contract, Company)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", False);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
	StructureData = New Structure();
	
	StructureData.Insert("ContractDescription",					Contract.Description);
	StructureData.Insert("SettlementsCurrency",					Contract.SettlementsCurrency);
	StructureData.Insert("SettlementsCurrencyRateRepetition",	CurrencyRateOperations.GetCurrencyRate(Date, Contract.SettlementsCurrency, Company));
	StructureData.Insert("PriceKind",							Contract.PriceKind);
	StructureData.Insert("DiscountMarkupKind",					Contract.DiscountMarkupKind);
	StructureData.Insert("AmountIncludesVAT",					?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined));
	StructureData.Insert("DirectDebitMandate",					Contract.DirectDebitMandate);
		
	If CounterpartyAttributes.DoOperationsByContracts And ValueIsFilled(Contract) Then
		
		StructureData.Insert("ShippingAddress", Common.ObjectAttributeValue(Contract, "ShippingAddress"));
		
	EndIf;
	
	Return StructureData;
	
EndFunction

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
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
		
		For Each TabularSectionRow In Object.Inventory Do
			
			If ValueIsFilled(TabularSectionRow.Products.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.Products.VATRate;
			Else
				TabularSectionRow.VATRate = DefaultVATRate;
			EndIf;	
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
		For Each TabularSectionRow In Object.AmountAllocation Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
			TabularSectionRow.VATAmount		= ?(Object.AmountIncludesVAT, 
										  		TabularSectionRow.OffsetAmount - (TabularSectionRow.OffsetAmount) / ((VATRate + 100) / 100),
										  		TabularSectionRow.OffsetAmount * VATRate / 100);
			TabularSectionRow.OffsetAmount	= TabularSectionRow.OffsetAmount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
	Else
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
		
		For Each TabularSectionRow In Object.Inventory Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
		For Each TabularSectionRow In Object.AmountAllocation Do
		
			TabularSectionRow.OffsetAmount	= TabularSectionRow.OffsetAmount
				- ?(Object.AmountIncludesVAT, TabularSectionRow.VATAmount, 0);
			TabularSectionRow.VATRate		= DefaultVATRate;
			TabularSectionRow.VATAmount		= 0;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateVATAmount(TablePartRow)
	
	VATRate = DriveReUse.GetVATRateValue(TablePartRow.VATRate);
	
	TablePartRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  TablePartRow.Amount - (TablePartRow.Amount) / ((VATRate + 100) / 100),
									  TablePartRow.Amount * VATRate / 100);
	
EndProcedure

&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined, ResetFlagDiscountsAreCalculated = True, RecalcSalesTax = True)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		
		TabularSectionRow.Amount = 0;
		
	ElsIf Not TabularSectionRow.DiscountMarkupPercent = 0
		AND Not TabularSectionRow.Quantity = 0 Then
		
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
		
	EndIf;
	
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	If RecalcSalesTax Then
		RecalculateSalesTax();
	EndIf;
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RefillDiscountAmountOfEPD();
	RecalculateSubtotal();
	
	// AutomaticDiscounts.
	If ResetFlagDiscountsAreCalculated Then
		AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	EndIf;
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow);
	EndIf;
	
EndProcedure

&AtServer
Procedure RecalculateSubtotal()
	Totals = DriveServer.CalculateSubtotal(Object.Inventory.Unload(), Object.AmountIncludesVAT, Object.SalesTax.Unload());
	
	If Not Object.ForOpeningBalancesOnly
		Or Object.Inventory.Count() > 0 Then
		
		FillPropertyValues(ThisObject, Totals);
		FillPropertyValues(Object, Totals);
		
	EndIf;
	
	If Object.OperationKind = Enums.OperationTypesSalesInvoice.ClosingInvoice Then
		Items.GroupAmountAllocation.Visible	= (Object.DocumentAmount < 0);
		Items.GroupPrepayment.Visible		= (Object.DocumentAmount > 0);
	EndIf;
	
EndProcedure

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
		
		NotifyDescription = New NotifyDescription("QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export

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
			
		// Generate price and currency label.
		GenerateLabelPricesAndCurrency(ThisObject);
		
	EndIf;

EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange = Undefined, RefillPrices = False, RecalculatePrices = False, WarningText = "")
	
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
	ParametersStructure.Insert("Company",						ParentCompany);
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("RefillPrices",					RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",				RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",				False);
	ParametersStructure.Insert("WarningText",					WarningText);
	ParametersStructure.Insert("PriceKind",						Object.PriceKind);
	ParametersStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	ParametersStructure.Insert("DiscountCard",					Object.DiscountCard);
	ParametersStructure.Insert("OperationKind",					Object.OperationKind);
	
	If RegisteredForVAT Then
		ParametersStructure.Insert("AutomaticVATCalculation",	Object.AutomaticVATCalculation);
		ParametersStructure.Insert("PerInvoiceVATRoundingRule",	PerInvoiceVATRoundingRule);
		ParametersStructure.Insert("VATTaxation",				Object.VATTaxation);
		ParametersStructure.Insert("AmountIncludesVAT",			Object.AmountIncludesVAT);
		ParametersStructure.Insert("IncludeVATInPrice",			Object.IncludeVATInPrice);
	EndIf;
	
	If RegisteredForSalesTax Then
		ParametersStructure.Insert("SalesTaxRate",			Object.SalesTaxRate);
		ParametersStructure.Insert("SalesTaxPercentage",	Object.SalesTaxPercentage);
	EndIf;
	
	// Open form "Prices and Currency".
	// Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, AttributesBeforeChange);
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisForm,,,, NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	StructurePricesAndCurrency = ClosingResult;
	
	If TypeOf(StructurePricesAndCurrency) = Type("Structure") And StructurePricesAndCurrency.WereMadeChanges Then
		
		Object.PriceKind = StructurePricesAndCurrency.PriceKind;
		Object.DiscountMarkupKind = StructurePricesAndCurrency.DiscountKind;
		
		If ValueIsFilled(ClosingResult.DiscountCard) And ValueIsFilled(ClosingResult.Counterparty) And Not Object.Counterparty.IsEmpty() Then
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
		
		DocCurRecalcStructure = New Structure;
		DocCurRecalcStructure.Insert("DocumentCurrency", StructurePricesAndCurrency.DocumentCurrency);
		DocCurRecalcStructure.Insert("Rate", StructurePricesAndCurrency.ExchangeRate);
		DocCurRecalcStructure.Insert("Repetition", StructurePricesAndCurrency.Multiplicity);
		DocCurRecalcStructure.Insert("PrevDocumentCurrency", AdditionalParameters.DocumentCurrency);
		DocCurRecalcStructure.Insert("InitRate", AdditionalParameters.ExchangeRate);
		DocCurRecalcStructure.Insert("RepetitionBeg", AdditionalParameters.Multiplicity);
		
		Object.DocumentCurrency = StructurePricesAndCurrency.DocumentCurrency;
		Object.ExchangeRate = StructurePricesAndCurrency.ExchangeRate;
		Object.Multiplicity = StructurePricesAndCurrency.Multiplicity;
		Object.ContractCurrencyExchangeRate = StructurePricesAndCurrency.SettlementsRate;
		Object.ContractCurrencyMultiplicity = StructurePricesAndCurrency.SettlementsMultiplicity;
		
		If RegisteredForVAT Then
			
			Object.VATTaxation = StructurePricesAndCurrency.VATTaxation;
			Object.AmountIncludesVAT = StructurePricesAndCurrency.AmountIncludesVAT;
			Object.IncludeVATInPrice = StructurePricesAndCurrency.IncludeVATInPrice;
			Object.AutomaticVATCalculation = StructurePricesAndCurrency.AutomaticVATCalculation;
			
			// Recalculate the amount if VAT taxation flag is changed.
			If StructurePricesAndCurrency.VATTaxation <> StructurePricesAndCurrency.PrevVATTaxation Then
				
				FillVATRateByVATTaxation();
				
				ParametersStructure = New Structure;
				ParametersStructure.Insert("GetGLAccounts", True);
				ParametersStructure.Insert("FillHeader", True);
				ParametersStructure.Insert("FillInventory", False);
				ParametersStructure.Insert("FillAmountAllocation", True);
				
				FillAddedColumns(ParametersStructure);
				
			EndIf;
			
		EndIf;
		
		// Sales tax.
		If RegisteredForSalesTax Then
			
			Object.SalesTaxRate = StructurePricesAndCurrency.SalesTaxRate;
			Object.SalesTaxPercentage = StructurePricesAndCurrency.SalesTaxPercentage;
			
			If StructurePricesAndCurrency.SalesTaxRate <> StructurePricesAndCurrency.PrevSalesTaxRate
				Or StructurePricesAndCurrency.SalesTaxPercentage <> StructurePricesAndCurrency.PrevSalesTaxPercentage Then
				
				RecalculateSalesTax();
				
			EndIf;
			
		EndIf;
		
		SetVisibleTaxAttributes();
		
		// Recalculate prices by kind of prices.
		If StructurePricesAndCurrency.RefillPrices Then
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
		EndIf;
		
		// Recalculate prices by currency.
		If Not StructurePricesAndCurrency.RefillPrices
			And StructurePricesAndCurrency.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Inventory", PricesPrecision);
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not StructurePricesAndCurrency.RefillPrices
			And Not StructurePricesAndCurrency.AmountIncludesVAT = StructurePricesAndCurrency.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory", PricesPrecision);
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
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts Or ClosingResult.RefillPrices Or ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;
		
		Modified = True;
		
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RefillDiscountAmountOfEPD();
		OpenPricesAndCurrencyFormEndAtServer();
	
	EndIf;
	
	// Generate price and currency label.
	GenerateLabelPricesAndCurrency(ThisObject); 	
	
EndProcedure

&AtServer
Procedure OpenPricesAndCurrencyFormEndAtServer()
	
	RecalculateSubtotal();
	
	SetPrepaymentColumnsProperties();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillHeader", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

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
			
			StructureProductsData = CreateGeneralAttributeValuesStructure(StructureData, "Inventory", BarcodeData);
			
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
			
			IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInBarcodeData(
				StructureProductsData, StructureData.Object, "SalesInvoice");
				
			If StructureData.UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(StructureProductsData, StructureData.Object, "SalesInvoice");
			EndIf;
			
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
	StructureData.Insert("Object", Object);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
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
			FilterParameters.Insert("Products",			BarcodeData.Products);
			FilterParameters.Insert("Characteristic",	BarcodeData.Characteristic);
			FilterParameters.Insert("MeasurementUnit",	BarcodeData.MeasurementUnit);
			FilterParameters.Insert("Batch",			BarcodeData.Batch);
			// Bundles
			FilterParameters.Insert("BundleProduct",	PredefinedValue("Catalog.Products.EmptyRef"));
			// End Bundles
			TSRowsArray = Object.Inventory.FindRows(FilterParameters);
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsData.Price;
				NewRow.DiscountMarkupPercent = BarcodeData.StructureProductsData.DiscountMarkupPercent;
				NewRow.VATRate = BarcodeData.StructureProductsData.VATRate;
				
				NewRow.ProductsTypeInventory = BarcodeData.StructureProductsData.ProductsTypeInventory;
				
				// Bundles
				If BarcodeData.StructureProductsData.IsBundle Then
					ReplaceInventoryLineWithBundleData(ThisObject, NewRow, BarcodeData.StructureProductsData);
				Else
				// End Bundles
					CalculateAmountInTabularSectionLine(NewRow);
					Items.Inventory.CurrentRow = NewRow.GetID();
				EndIf;
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(NewRow);
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
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisForm, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisForm,,,,Notification
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
// End Peripherals

&AtServer
Procedure FillColumnReserveByReservesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByReserves();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

&AtServer
Procedure SetContractVisible()
	
	Items.Contract.Visible = CounterpartyAttributes.DoOperationsByContracts;
	
EndProcedure

&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText, Contract, Document, Company, Counterparty, Cancel)
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractKindsList = ManagerOfCatalog.GetContractTypesListForDocument(Document);
	
	If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList)
		AND GetFunctionalOption("CheckContractsOnPosting") Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, DoOperationsByContracts, Contract)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company);
	
EndFunction

&AtClient
Procedure ProcessContractChange()
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
		
	If ContractBeforeChange <> Object.Contract Then
		
		ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract, Object.Company);
		
		Object.DirectDebitMandate = ContractData.DirectDebitMandate;
		
		If Object.Prepayment.Count() > 0
			AND Object.Contract <> ContractBeforeChange Then
			
			DocumentParameters = New Structure;
			DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
			DocumentParameters.Insert("ContractData", ContractData);
			
			NotifyDescription = New NotifyDescription("PrepaymentClearingQuestionEnd", ThisObject, DocumentParameters);
			QuestionText = NStr("en = 'Advances will be cleared. Do you want to continue?'; ru = 'Зачет аванса будет очищен, продолжить?';pl = 'Rozliczenia zostaną wyczyszczone. Czy chcesz kontynuować?';es_ES = 'Anticipos se liquidarán. ¿Quiere continuar?';es_CO = 'Anticipos se liquidarán. ¿Quiere continuar?';tr = 'Avanslar silinecek. Devam etmek istiyor musunuz?';it = 'Gli anticipi saranno compensati. Volete continuare?';de = 'Vorauszahlungen werden gelöscht. Möchten Sie fortsetzen?'");
			
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			Return;
		EndIf;
		
		ProcessContractConditionsChange(ContractData, ContractBeforeChange);
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
		SetVisibleEnablePaymentTermItems();
		
		FillEarlyPaymentDiscounts();
		
	Else
		
		Object.Order = Items.Order.TypeRestriction.AdjustValue(Order);
		
	EndIf;
	
	Order = Object.Order;
	
EndProcedure

&AtClient
Procedure ProcessCounterpartyChange()
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Counterparty);
		
		Object.CounterpartyBankAcc = Undefined;
		Object.DeliveryOption = CounterpartyAttributes.DefaultDeliveryOption;
		
		SetVisibleDeliveryAttributes();
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		
		Object.Contract = StructureData.Contract;
		ContractBeforeChange = Contract;
		Contract = Object.Contract;
		
		ProcessContractConditionsChange(StructureData, ContractBeforeChange);
		
		If Not ValueIsFilled(Object.ShippingAddress) Then
			
			DeliveryData = GetDeliveryData(Object.Counterparty);
			
			If DeliveryData.ShippingAddress = Undefined Then
				CommonClientServer.MessageToUser(NStr("en = 'Delivery address is required'; ru = 'Укажите адрес доставки';pl = 'Wymagany jest adres dostawy';es_ES = 'Se requiere la dirección de entrega';es_CO = 'Se requiere la dirección de entrega';tr = 'Teslimat adresi gerekli';it = 'È richiesto l''indirizzo di consegna';de = 'Adresse ist ein Pflichtfeld'"));
			Else
				Object.ShippingAddress = DeliveryData.ShippingAddress;
			EndIf;
			
		EndIf;
		
		ProcessShippingAddressChange();
		
		SetVisibleEnablePaymentTermItems();
		
		FillVATValidationAttributes();
		
	Else
		
		Object.Contract	= Contract; // Restore the cleared contract automatically.
		Object.Order	= Items.Order.TypeRestriction.AdjustValue(Order);;
		
	EndIf;
	
	Order = Object.Order;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("CounterpartyOnChange");
	
EndProcedure

&AtClient
Procedure PrepaymentClearingQuestionEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.Prepayment.Clear();
		If AdditionalParameters.Property("CounterpartyChange") Then
			
			Object.Counterparty = AdditionalParameters.NewCounterparty;
			ProcessCounterpartyChange();
			
		Else
			
			ContractBeforeChange = AdditionalParameters.ContractBeforeChange;
			ProcessContractConditionsChange(AdditionalParameters.ContractData, ContractBeforeChange);
			
		EndIf;
		
	ElsIf Not AdditionalParameters.Property("CounterpartyChange") Then
		
		Object.Contract = ContractBeforeChange;
		Contract = ContractBeforeChange;
		Object.Order = Order;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessContractConditionsChange(ContractData, ContractBeforeChange)
	
	SettlementCurrency = ContractData.SettlementsCurrency;
	
	If Object.ThirdPartyPayment Then
		
		If ValueIsFilled(Object.Payer) Then
			ClearThirdPartyPayer();
		EndIf;
		
		If ValueIsFilled(Object.PayerContract) Then
			ClearPayerContract();
		EndIf;
		
		If ValueIsFilled(SettlementCurrency) And ValueIsFilled(Object.Payer) Then
			Object.PayerContract = GetContractByCurrency(Object.Ref, Object.Payer, Object.Company, SettlementCurrency);
		EndIf;
		
	EndIf;
	
	SetVisibleThirdPartyPayer();
	SetVisibleThirdPartyPayerContract();
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
	EndIf;
	
	AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
		Object.DocumentCurrency,
		Object.ExchangeRate,
		Object.Multiplicity);
	
	If ValueIsFilled(Object.Contract) Then 
		Object.ExchangeRate = ?(ContractData.SettlementsCurrencyRateRepetition.Rate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Rate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Repetition = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Repetition);
		Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
		Object.ContractCurrencyMultiplicity = Object.Multiplicity;
	EndIf;
	
	PriceKindChanged = Object.PriceKind <> ContractData.PriceKind 
		AND ValueIsFilled(ContractData.PriceKind);
	
	DiscountKindChanged = (Object.DiscountMarkupKind <> ContractData.DiscountMarkupKind);
	
	// Discount card (
	If ContractData.Property("CallFromProcedureAtCounterpartyChange") Then
		ClearDiscountCard = ValueIsFilled(Object.DiscountCard); // Attribute DiscountCard will be cleared later.
	Else
		ClearDiscountCard = False;
	EndIf;
	
	If ClearDiscountCard Then
		Object.DiscountCard = PredefinedValue("Catalog.DiscountCards.EmptyRef");
		Object.DiscountPercentByDiscountCard = 0;
	EndIf;
	// ) Discount card.
	
	QueryPriceKind = ValueIsFilled(Object.Contract) AND (PriceKindChanged OR DiscountKindChanged);
	If QueryPriceKind Then
		If PriceKindChanged Then
			Object.PriceKind = ContractData.PriceKind;
		EndIf; 
		If DiscountKindChanged Then
			Object.DiscountMarkupKind = ContractData.DiscountMarkupKind;
		EndIf; 
	EndIf;
	
	OpenFormPricesAndCurrencies = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementCurrency)
		AND Object.Contract <> ContractBeforeChange
		AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
		AND Object.Inventory.Count() > 0;
	
	If ValueIsFilled(SettlementCurrency) Then
		Object.DocumentCurrency = SettlementCurrency;
	EndIf;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If QueryPriceKind Then
			WarningText = MessagesToUserClientServer.GetPriceTypeOnChangeWarningText();
		EndIf;
		
		WarningText = WarningText
			+ ?(IsBlankString(WarningText), "", Chars.LF + Chars.LF)
			+ MessagesToUserClientServer.GetSettleCurrencyOnChangeWarningText();
		
		ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, PriceKindChanged, True, WarningText);
		
	ElsIf QueryPriceKind Then
		
		RecalculationRequired = (Object.Inventory.Count() > 0);
		
		GenerateLabelPricesAndCurrency(ThisObject);
		
		If RecalculationRequired Then
			
			QuestionText = NStr("en = 'The price and discount in the contract with counterparty differ from price and discount in the document. Recalculate the document according to the contract?'; ru = 'Договор с контрагентом предусматривает условия цен и скидок, отличные от установленных в документе! Пересчитать документ в соответствии с договором?';pl = 'Cena i rabaty w umowie z kontrahentem różnią się od cen i rabatów w dokumencie! Przeliczyć dokument zgodnie z umową?';es_ES = 'El precio y descuento en el contrato con la contraparte es diferente del precio y descuento en el documento. ¿Recalcular el documento según el contrato?';es_CO = 'El precio y descuento en el contrato con la contraparte es diferente del precio y descuento en el documento. ¿Recalcular el documento según el contrato?';tr = 'Cari hesap ile yapılan sözleşmede yer alan fiyat ve indirim koşulları, belgedeki fiyat ve indirimden farklılık gösterir. Belge sözleşmeye göre yeniden hesaplansın mı?';it = 'Il prezzo e lo sconto nel contratto con la controparte differiscono dal prezzo e lo sconto nel documento. Ricalcolare il documento in base al contratto?';de = 'Preis und Rabatt im Vertrag mit dem Geschäftspartner unterscheiden sich von Preis und Rabatt im Beleg. Das Dokument gemäß dem Vertrag neu berechnen?'");
			
			NotifyDescription = New NotifyDescription("RecalculationQuestionByPriceKindEnd", ThisObject);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	Else
		
		GenerateLabelPricesAndCurrency(ThisObject);
		
	EndIf;
	
	// Clear order.
	For Each CurRow In Object.Inventory Do
		CurRow.Order = Undefined;
	EndDo;
	
	If ContractBeforeChange <> Object.Contract Then
		
		If ContractData.Property("ShippingAddress") And ValueIsFilled(ContractData.ShippingAddress) Then
			
			If Object.ShippingAddress <> ContractData.ShippingAddress Then
				
				Object.ShippingAddress = ContractData.ShippingAddress;
				If Not ContractData.Property("CallFromProcedureAtCounterpartyChange") Then
					ProcessShippingAddressChange();
				EndIf;
				
			EndIf;
			
		EndIf;
		
		FillPaymentCalendar(SwitchTypeListOfPaymentCalendar);
		FillEarlyPaymentDiscounts();
		SetVisibleEnablePaymentTermItems();
		SetVisibleEarlyPaymentDiscounts();
	EndIf;
	
	Object.DirectDebitMandate = ContractData.DirectDebitMandate;

EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, DoOperationsByOrders, DefaultDeliveryOption, VATTaxation";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

&AtClient
Procedure RecalculationQuestionByPriceKindEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillPrepayment(CurrentObject)
	
	CurrentObject.FillPrepayment();
	
EndProcedure

&AtServer
Procedure SetVisibleTaxInvoiceText()
	Items.TaxInvoiceText.Visible = UseTaxInvoice;
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	
	RegisteredForVAT				= AccountingPolicy.RegisteredForVAT;
	PerInvoiceVATRoundingRule		= AccountingPolicy.PerInvoiceVATRoundingRule;
	RegisteredForSalesTax			= AccountingPolicy.RegisteredForSalesTax;
	Object.IsRegisterDeliveryDate	= AccountingPolicy.RegisterDeliveryDateInInvoices;
	UseTaxInvoice 					= RegisteredForVAT And Not AccountingPolicy.PostVATEntriesBySourceDocuments;
	
EndProcedure

&AtServer
Procedure SetAutomaticVATCalculation()
	
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
	
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
	ParametersStructure.Insert("FillAmountAllocation", False);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtServer
Procedure FillByGoodsConsumedAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillTabularSectionByGoodsConsumed();
	ValueToFormAttribute(Document, "Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	False);
	ParametersStructure.Insert("FillHeader",	False);
	ParametersStructure.Insert("FillInventory",	True);
	ParametersStructure.Insert("FillAmountAllocation", False);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtServerNoContext
Function GetContractByCurrency(Document, Counterparty, Company, Currency)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company, , , Currency);
	
EndFunction

&AtServer
Procedure ClearPayerContract()
	
	If ValueIsFilled(Object.PayerContract) Then
		PayerContractCurrency = Common.ObjectAttributeValue(Object.PayerContract, "SettlementsCurrency");
		If PayerContractCurrency <> SettlementCurrency Then
			Object.PayerContract = Catalogs.CounterpartyContracts.EmptyRef();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearThirdPartyPayer()
	
	If ValueIsFilled(Object.Payer) And Not PayerAttributes.DoOperationsByContracts Then
		If PayerAttributes.SettlementsCurrency <> SettlementCurrency Then
			Object.Payer = PredefinedValue("Catalog.Counterparties.EmptyRef");
			Object.PayerContract = PredefinedValue("Catalog.CounterpartyContracts.EmptyRef");
			ReadPayerAttributes(PayerAttributes, Object.Payer);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessPayerChange()
	
	PayerBeforeChange = Payer;
	Payer = Object.Payer;
	
	If PayerBeforeChange <> Object.Payer Then
		
		ReadPayerAttributes(PayerAttributes, Object.Payer);
		
		SetVisibleThirdPartyPayerContract();
		
		Object.PayerContract = GetContractByCurrency(Object.Ref, Object.Payer, Object.Company, SettlementCurrency);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkWithPick

&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'sales invoice'; ru = 'инвойс покупателю';pl = 'faktura sprzedaży';es_ES = 'factura de ventas';es_CO = 'factura de ventas';tr = 'satış faturası';it = 'fattura di vendita';de = 'Verkaufsrechnung'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, True, True, True);
	SelectionParameters.Insert("Company", ParentCompany);
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject, SelectionParameters);
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
Procedure MaterialsPick(Command)
	
	TabularSectionName	= "ConsumerMaterials";
	DocumentPresentaion	= NStr("en = 'sales invoice'; ru = 'инвойс покупателю';pl = 'faktura sprzedaży';es_ES = 'factura de ventas';es_CO = 'factura de ventas';tr = 'satış faturası';it = 'fattura di vendita';de = 'Verkaufsrechnung'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject,
		TabularSectionName, DocumentPresentaion, True, False, True);
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject, SelectionParameters);
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
		|PriceKind,
		|DiscountMarkupKind,
		|DiscountCard,
		|DocumentCurrency,
		|AmountIncludesVAT,
		|IncludeVATInPrice,
		|VATTaxation,
		|Order");
	FillPropertyValues(SelectionParameters, Object);
	
	SelectionParameters.Insert("TempStorageInventoryAddress", PutInventoryToTempStorage());
	SelectionParameters.Insert("ShowGoodsIssue", True);
	
	// Bundles
	SelectionParameters.Insert("ShowBundles", True);
	// End Bundles

	OpenForm("CommonForm.SelectionFromOrders", SelectionParameters, ThisForm, , , , , FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Function PutInventoryToTempStorage()
	
	InventoryTable = Object.Inventory.Unload();
	InventoryTable.Columns.Add("SalesInvoice", New TypeDescription("DocumentRef.SalesInvoice"));
	
	If ValueIsFilled(Object.Order) Then
		For Each InventoryRow In InventoryTable Do
			If Not ValueIsFilled(InventoryRow.Order) Then
				InventoryRow.Order = Object.Order;
			EndIf;
		EndDo;
	EndIf;
	
	Return PutToTempStorage(InventoryTable);
	
EndFunction

&AtClient
Procedure OrderedProductsSelectionProcessingAtClient(TempStorageInventoryAddress)
	
	OrderedProductsSelectionProcessingAtServer(TempStorageInventoryAddress);
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
	RefillDiscountAmountOfEPD();
	CalculateDiscountsMarkupsClient();
	RecalculateSubtotal();
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure OrderedProductsSelectionProcessingAtServer(TempStorageInventoryAddress)
	
	TablesStructure = GetFromTempStorage(TempStorageInventoryAddress);
	
	InventorySearchStructure = New Structure("Products, Characteristic, BundleProduct, BundleCharacteristic, Batch, Order, GoodsIssue");
	
	DiscountsMarkupsSearchStructure = New Structure("ConnectionKey");
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	For Each InventoryRow In TablesStructure.Inventory Do
		
		FillPropertyValues(InventorySearchStructure, InventoryRow);
		
		TS_InventoryRows = Object.Inventory.FindRows(InventorySearchStructure);
		For Each TS_InventoryRow In TS_InventoryRows Do
			Object.Inventory.Delete(TS_InventoryRow);
		EndDo;
			
		TS_InventoryRow = Object.Inventory.Add();
		FillPropertyValues(TS_InventoryRow, InventoryRow);
		
		IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, TS_InventoryRow, "Inventory");
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, TS_InventoryRow, "Inventory");
		EndIf;
		
	EndDo;
	
	// Bundles
	If TablesStructure.AddedBundles.Count() Then
		For Each AddedBundle In TablesStructure.AddedBundles Do
			NewRow = Object.AddedBundles.Add();
			FillPropertyValues(NewRow, AddedBundle);
		EndDo;
		
		RefreshBundlePictures(Object.Inventory);
		RefreshBundleAttributes(Object.Inventory);
		SetBundlePictureVisible();
	EndIf;
	// End Bundles
	
	OrdersTable = Object.Inventory.Unload( , "Order");
	OrdersTable.GroupBy("Order");
	If OrdersTable.Count() > 1 Then
		Object.Order = Undefined;
		Object.SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	ElsIf OrdersTable.Count() = 1 Then
		Object.Order = OrdersTable[0].Order;
		Object.SalesOrderPosition = Enums.AttributeStationing.InHeader;
	EndIf;
	SetVisibleFromUserSettings();
	
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
		
		// Bundles
		If ImportRow.IsBundle Then
			
			StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "Inventory", NewRow);
			
			If ValueIsFilled(Object.PriceKind) Then
				StructureData.Insert("ProcessingDate"		, Object.Date);
				StructureData.Insert("DocumentCurrency"		, Object.DocumentCurrency);
				StructureData.Insert("AmountIncludesVAT"	, Object.AmountIncludesVAT);
				StructureData.Insert("PriceKind"			, Object.PriceKind);
				StructureData.Insert("Factor"				, 1);
				StructureData.Insert("DiscountMarkupKind"	, Object.DiscountMarkupKind);
			EndIf;
			// DiscountCards
			StructureData.Insert("DiscountCard", Object.DiscountCard);
			StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
			// End DiscountCards
			
			If UseDefaultTypeOfAccounting Then
				AddGLAccountsToStructure(ThisObject, "Inventory", StructureData, NewRow);
			EndIf;
			
			StructureData = GetDataProductsOnChange(StructureData);
			
			ReplaceInventoryLineWithBundleData(ThisObject, NewRow, StructureData);
			
		// End Bundles
		Else
			If ValueIsFilled(ImportRow.Products)
				And TabularSectionName = "Inventory" Then
				
				NewRow.ProductsTypeInventory = (ImportRow.Products.ProductsType = PredefinedValue("Enum.ProductsTypes.InventoryItem"));
				
				IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, TabularSectionName);
				
				If UseDefaultTypeOfAccounting Then
					GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
				EndIf;
				
			EndIf;
		EndIf;
		
	EndDo;
	
	// AutomaticDiscounts
	If TabularSectionName = "Inventory"
		And TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;

EndProcedure

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

&AtServer
Procedure GetPrepaymentFromStorage(AddressPrepaymentInStorage)
	
	TableForImport = GetFromTempStorage(AddressPrepaymentInStorage);
	Object.Prepayment.Load(TableForImport);
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			TabularSectionName = AdditionalParameters.TabularSectionName;
			
			If TabularSectionName	= "Inventory" Then
				
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
				
				RecalculateSalesTax();
				PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
				RefillDiscountAmountOfEPD();
				RecalculateSubtotal();
				
			ElsIf TabularSectionName = "ConsumerMaterials" Then 
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
			EndIf;
			
			Object.StructuralUnit 	= ClosingResult.StockWarehouse;
			Object.Cell 			= ClosingResult.StockCell;
			
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
			
			CurrentPagesInventory		= (Items.Pages.CurrentPage = Items.GroupInventory);
			TabularSectionName			= ?(CurrentPagesInventory, "Inventory", "ConsumerMaterials");
			
			// Clear inventory
			Filter = New Structure;
			Filter.Insert("Products", ClosingResult.FilterProducts);
			If TabularSectionName	= "Inventory" Then
				Filter.Insert("IsBundle", False);
			EndIf;
			
			RowsToDelete = Object[TabularSectionName].FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				If TabularSectionName = "Inventory" Then
					WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
						Object.SerialNumbers, RowToDelete,, UseSerialNumbersBalance);
				EndIf;
				Object[TabularSectionName].Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
			
			If TabularSectionName	= "Inventory" Then
				
				RowsToRecalculate = Object[TabularSectionName].FindRows(Filter);
				For Each RowToRecalculate In RowsToRecalculate Do
					CalculateAmountInTabularSectionLine(RowToRecalculate, True, False);
				EndDo;
				
				RecalculateSalesTax();
				PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
				RefillDiscountAmountOfEPD();
				RecalculateSubtotal();
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormViewManagement

&AtServer
Procedure SetVisibleAndEnabled()
	
	Items.PricesAndCurrency.MaxWidth	= 34;
	
	// Discounts and discount cards.
	Items.Inventory.ChildItems.InventoryDiscountPercentMargin.Visible = True;
	Items.ReadDiscountCard.Visible = True; // DiscountCards
	
	// AutomaticDiscounts
	Items.Inventory.ChildItems.InventoryAutomaticDiscountPercent.Visible = True;
	Items.Inventory.ChildItems.InventoryAutomaticDiscountAmount.Visible = True;
	Items.InventoryCalculateDiscountsMarkups.Visible = True;
	// End AutomaticDiscounts
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	// Products.
	NewArray = New Array();
	NewArray.Add(PredefinedValue("Enum.ProductsTypes.InventoryItem"));
	NewArray.Add(PredefinedValue("Enum.ProductsTypes.Service"));
	NewArray.Add(PredefinedValue("Enum.ProductsTypes.Work"));
	ArrayInventoryAndServices = New FixedArray(NewArray);
	NewParameter = New ChoiceParameter("Filter.ProductsType", ArrayInventoryAndServices);
	NewParameter2 = New ChoiceParameter("Additionally.TypeRestriction", ArrayInventoryAndServices);
	NewArray = New Array();
	NewArray.Add(NewParameter);
	NewArray.Add(NewParameter2);
	NewParameters = New FixedArray(NewArray);
	Items.Inventory.ChildItems.InventoryProducts.ChoiceParameters = NewParameters;
	
	// Order when safe storage.
	Items.Order.Visible = True;
	Items.FillByOrder.Visible = OrderInHeader;
	Items.Inventory.ChildItems.InventoryOrder.Visible = Not OrderInHeader;
	Items.FormDocumentSetting.Visible = True;
	Items.InventorySelectOrderedProducts.Visible = True;
	
	// Reserves.
	Items.InventoryChangeReserve.Visible = True;
	Items.Inventory.ChildItems.InventoryReserve.Visible = True;
	
	Items.Department.AutoChoiceIncomplete = True;
	Items.Department.AutoMarkIncomplete = True And Not Object.ForOpeningBalancesOnly;
	
	// VAT Rate, VAT Amount, Total.
	SetVisibleTaxAttributes();
	
	NewParameter = New ChoiceParameter("Filter.StructuralUnitType", PredefinedValue("Enum.BusinessUnitsTypes.Warehouse"));
	NewArray = New Array();
	NewArray.Add(NewParameter);
	NewParameters = New FixedArray(NewArray);
	Items.StructuralUnit.ChoiceParameters = NewParameters;
	
	If Object.StructuralUnit.StructuralUnitType <> PredefinedValue("Enum.BusinessUnitsTypes.Warehouse") Then
		Object.StructuralUnit = "";
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPrice.ReadOnly					= Not AllowedEditDocumentPrices;
	Items.InventoryDiscountPercentMargin.ReadOnly	= Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly					= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly				= Not AllowedEditDocumentPrices;
	
	SetVisibleTaxInvoiceText();
	
	If AccessRight("InteractiveInsert", Metadata.Documents.GoodsReceipt) Then
		Items.FormDocumentGoodsReceiptCreateBasedOn.Visible = GetFunctionalOption("UseGoodsReturnFromCustomer");
	EndIf;
	
	SetDeliveryDatePeriodVisible(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetDeliveryDatePeriodVisible(Form)
	
	Object = Form.Object;
	Items = Form.Items;
	IsDeliveryDateInTable = Form.IsDeliveryDateInTable;
	
	DeliveryDatePeriodIsDate = (Object.DeliveryDatePeriod = PredefinedValue("Enum.DeliveryDatePeriod.Date"));
	IsClosingInvoice = (Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesInvoice.ClosingInvoice"));
	
	Items.GroupDeliveryDatePeriodSettings.Visible = Object.IsRegisterDeliveryDate Or IsClosingInvoice;
	Items.GroupDeliveryDatePeriod.Visible = Not IsDeliveryDateInTable Or IsClosingInvoice;
	Items.DeliveryEndDate.Visible = Not DeliveryDatePeriodIsDate;
	Items.SelectDeliveryPeriod.Visible = Not DeliveryDatePeriodIsDate;
	If DeliveryDatePeriodIsDate Then
		Items.DeliveryDate.Title = NStr("en = 'Delivery date'; ru = 'Дата доставки';pl = 'Data dostawy';es_ES = 'Fecha de entrega';es_CO = 'Fecha de entrega';tr = 'Teslimat tarihi';it = 'Data di consegna';de = 'Lieferdatum'");
	Else
		Items.DeliveryDate.Title = NStr("en = 'Delivery from'; ru = 'Доставка от';pl = 'Dostawa od';es_ES = 'Entrega desde';es_CO = 'Entrega desde';tr = 'Teslimat başlangıcı';it = 'Consegna da';de = 'Lieferung aus'");
	EndIf;
	
	Items.InventoryDeliveryDate.Visible = (Object.IsRegisterDeliveryDate Or IsClosingInvoice)
		And IsDeliveryDateInTable And DeliveryDatePeriodIsDate;
	Items.InventoryDeliveryStartDate.Visible = (Object.IsRegisterDeliveryDate Or IsClosingInvoice)
		And IsDeliveryDateInTable And Not DeliveryDatePeriodIsDate;
	Items.InventoryDeliveryEndDate.Visible = (Object.IsRegisterDeliveryDate Or IsClosingInvoice)
		And IsDeliveryDateInTable And Not DeliveryDatePeriodIsDate;
	
	If IsClosingInvoice Then
		DeliveryDateToolTip = NStr("en = 'The delivery date of the processed Sales invoices and Actual sales volume documents.'; ru = 'Дата доставки обработанных инвойсов покупателю и документов фактического объема продаж.';pl = 'Data dostawy przetwarzanych dokumentów Faktura sprzedaży i Rzeczywista wielkość sprzedaży.';es_ES = 'La fecha de entrega de las Facturas de venta procesadas y los Documentos sobre el volumen real de ventas.';es_CO = 'La fecha de entrega de las Facturas de venta procesadas y los Documentos sobre el volumen real de ventas.';tr = 'İşlenen Satış faturalarının ve Gerçekleşen satış hacmi belgelerinin teslimat tarihi.';it = 'Data di consegna delle Fatture di vendita e dei documenti dei volumi effettivi di vendita processati.';de = 'Das Lieferdatum der bearbeiteten Verkaufsrechnungen und Dokumente Aktuelle Verkaufsmenge.'");
		DeliveryPeriodToolTip = NStr("en = 'The delivery period of the processed Sales invoices and Actual sales volume documents.'; ru = 'Период доставки обработанных инвойсов покупателю и документов фактического объема продаж.';pl = 'Okres dostawy przetwarzanych dokumentów Faktura sprzedaży i Rzeczywista wielkość sprzedaży.';es_ES = 'El período de entrega de las Facturas de venta procesadas y los Documentos sobre el volumen real de ventas.';es_CO = 'El período de entrega de las Facturas de venta procesadas y los Documentos sobre el volumen real de ventas.';tr = 'İşlenen Satış faturalarının ve Gerçekleşen satış hacmi belgelerinin teslimat dönemi.';it = 'Periodo di consegna delle Fatture di vendita e dei documenti dei volumi effettivi di vendita processati.';de = 'Der Lieferzeitraum der bearbeiteten Verkaufsrechnungen und Dokumente Aktuelle Verkaufsmenge.'");
	Else
		DeliveryDateToolTip = "";
		DeliveryPeriodToolTip = "";
	EndIf;
	Items.InventoryDeliveryDate.ToolTip = DeliveryDateToolTip;
	Items.InventoryDeliveryStartDate.ToolTip = DeliveryPeriodToolTip;
	Items.InventoryDeliveryEndDate.ToolTip = DeliveryPeriodToolTip;
	
	If DeliveryDatePeriodIsDate Then
		If IsDeliveryDateInTable And Not IsClosingInvoice Then
			DeliveryGroupTitle = NStr("en = 'Delivery dates are shown on the Products tab'; ru = 'Даты доставки отображаются во вкладке Номенклатура';pl = 'Daty dostawy są pokazane na karcie Produkty';es_ES = 'Las fechas de entrega se muestran en la pestaña Productos';es_CO = 'Las fechas de entrega se muestran en la pestaña Productos';tr = 'Teslimat tarihleri Ürünler sekmesinde gösterilir';it = 'Le date di consegna sono mostrate nella scheda Articoli';de = 'Lieferdaten sind auf der Registerkarte Produkte angezeigt'");
		Else
			DeliveryGroupTitle = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Delivery date: %1'; ru = 'Дата доставки: %1';pl = 'Data dostawy: %1';es_ES = 'Fecha de entrega: %1';es_CO = 'Fecha de entrega: %1';tr = 'Teslimat tarihi: %1';it = 'Data di consegna: %1';de = 'Lieferdatum: %1'"),
				Format(Object.DeliveryStartDate, "DLF=D"));
		EndIf;
	Else
		If IsDeliveryDateInTable And Not IsClosingInvoice Then
			DeliveryGroupTitle = NStr("en = 'Delivery periods are shown on the Products tab'; ru = 'Периоды доставки отображаются во вкладке Номенклатура';pl = 'Okresy dostawy są pokazane na karcie Produkty';es_ES = 'Los períodos de entrega se muestran en la pestaña Productos';es_CO = 'Los períodos de entrega se muestran en la pestaña Productos';tr = 'Teslimat dönemleri Ürünler sekmesinde gösterilir';it = 'I periodi di consegna sono mostrate nella scheda Articoli';de = 'Lieferzeiträume sind auf der Registerkarte Produkte angezeigt'");
		Else
			DeliveryGroupTitle = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Delivery period: %1 - %2'; ru = 'Период доставки: %1 - %2';pl = 'Okres dostawy: %1 - %2';es_ES = 'Período de entrega: %1 - %2';es_CO = 'Período de entrega: %1 - %2';tr = 'Teslimat dönemi: %1 - %2';it = 'Periodo di consegna: %1 - %2';de = 'Lieferzeitraum: %1 - %2'"),
				Format(Object.DeliveryStartDate, "DLF=D"),
				Format(Object.DeliveryEndDate, "DLF=D"));
		EndIf;
	EndIf;
	Items.GroupDeliveryDatePeriodSettings.Title = DeliveryGroupTitle;
	
EndProcedure

&AtServer
Procedure SetVisibleFromUserSettings()
	
	VisibleValue = (Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader"));
	
	Items.Order.Enabled = VisibleValue;
	If VisibleValue Then
		Items.Order.InputHint = "";
	Else 
		Items.Order.InputHint = NStr("en = '<Multiple orders mode>'; ru = '<Режим нескольких заказов>';pl = '<Tryb wielu zamówień>';es_ES = '<Modo de órdenes múltiples>';es_CO = '<Modo de órdenes múltiples>';tr = '<Birden fazla sipariş modu>';it = '<Modalità ordini multipli>';de = '<Mehrfach-Bestellungen Modus>'");
	EndIf;
	Items.InventoryOrder.Visible = Not VisibleValue;
	Items.FillByOrder.Visible = VisibleValue;
	OrderInHeader = VisibleValue;
	
EndProcedure

&AtClient
Procedure SetVisibleDeliveryAttributes()
	
	VisibleFlags			= GetFlagsForFormItemsVisible(Object.DeliveryOption);
	DeliveryOptionIsFilled	= ValueIsFilled(Object.DeliveryOption);

	Items.LogisticsCompany.Visible	= DeliveryOptionIsFilled AND VisibleFlags.DeliveryOptionLogisticsCompany;
	Items.ShippingAddress.Visible	= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.ContactPerson.Visible		= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.GoodsMarking.Visible		= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.DeliveryTimeFrom.Visible	= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.DeliveryTimeTo.Visible	= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.Incoterms.Visible			= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	
EndProcedure

&AtServerNoContext
Function GetFlagsForFormItemsVisible(DeliveryOption)
	
	VisibleFlags = New Structure;
	VisibleFlags.Insert("DeliveryOptionLogisticsCompany", (DeliveryOption = Enums.DeliveryOptions.LogisticsCompany));
	VisibleFlags.Insert("DeliveryOptionSelfPickup", (DeliveryOption = Enums.DeliveryOptions.SelfPickup));
	
	Return VisibleFlags;
	
EndFunction

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	ColorTextSpecifiedInDocument = StyleColors.TextSpecifiedInDocument;
	
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
	
	ItemAppearance.Presentation = NStr("en = 'Blank field formatting'; ru = 'Формат незаполненного поля';pl = 'Formatowanie pola puste';es_ES = 'Formateo del campo en blanco';es_CO = 'Formateo del campo en blanco';tr = 'Boş alan biçimlendirme';it = 'Formattazione del campo vuoto';de = 'Leere Feldformatierung'");
	
	//InventoryAmount
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Inventory.TotalDiscountAmountIsMoreThanAmount");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("MarkIncomplete", False);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("InventoryAmount");
	FieldAppearance.Use = True;
	
	ItemAppearance.Presentation = NStr("en = 'Blank field formatting'; ru = 'Формат незаполненного поля';pl = 'Formatowanie pola puste';es_ES = 'Formateo del campo en blanco';es_CO = 'Formateo del campo en blanco';tr = 'Boş alan biçimlendirme';it = 'Formattazione del campo vuoto';de = 'Leere Feldformatierung'");
	
	//InventoryReserve, InventoryGoodsIssue
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Inventory.ProductsTypeInventory");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<For products>'; ru = '<Для номенклатуры>';pl = '<Dla produktów>';es_ES = '<Para los productos>';es_CO = '<Para los productos>';tr = '<Ürünler için>';it = '<Per articoli>';de = '<Für Produkte>'"));
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextSpecifiedInDocument);
	ItemAppearance.Appearance.SetParameterValue("Enabled", False);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("InventoryReserve");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("InventoryGoodsIssue");
	FieldAppearance.Use = True;
	
	ItemAppearance.Presentation = NStr("en = 'Availability of the Reserve column'; ru = 'Доступность колонки Резерв';pl = 'Dostępność kolumny Rezerwy';es_ES = 'Disponibilidad de la columna de Reserva';es_CO = 'Disponibilidad de la columna de Reserva';tr = 'Rezerv sütununun kullanılabilirliği';it = 'Disponibilità della colonna Riserva';de = 'Verfügbarkeit der Reservespalte'");
	
	//InventoryInventorySerialNumbers
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Inventory.GoodsIssue");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotEqual;
	DataFilterItem.RightValue		= Documents.GoodsIssue.EmptyRef();
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<Specified in Goods issue>'; ru = '<Указано в отпуске товаров>';pl = '<Określony w wydaniu zewnętrznym>';es_ES = '<Especificado en la emisión de Mercancías>';es_CO = '<Especificado en la emisión de Mercancías>';tr = '<Ambar çıkışında belirtilen>';it = '<Specificato nella Spedizione merce>';de = '<In Warenausgang angegeben>'"));
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextSpecifiedInDocument);
	ItemAppearance.Appearance.SetParameterValue("Enabled", False);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("InventoryInventorySerialNumbers");
	FieldAppearance.Use = True;
	
	ItemAppearance.Presentation = NStr("en = 'Goods issue without serial numbers'; ru = 'Отпуск товаров без серийных номеров';pl = 'Wydanie zewnętrzne bez numerów seryjnych';es_ES = 'Emisión de mercancías sin los números de serie';es_CO = 'Emisión de mercancías sin los números de serie';tr = 'Seri numarasız ambar çıkışı';it = 'Documento di Trasporto senza numeri di serie';de = 'Warenausgang ohne Seriennummern'");
	
	IncomeAndExpenseItemsInDocuments.SetConditionalAppearance(ThisObject, "Inventory");
	
	// Drop shipping
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Inventory.ProductsTypeInventory");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Enabled", False);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("InventoryDropShipping");
	FieldAppearance.Use = True;
	
EndProcedure

#EndRegion

#Region AutomaticDiscounts

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

&AtServer
Procedure CalculateMarkupsDiscountsForOrderServer()

	DiscountsMarkupsServer.FillLinkingKeysInSpreadsheetPartProducts(Object, "Inventory");
	
	OrdersArray = New Array;
	
	If Not ValueIsFilled(Object.SalesOrderPosition) Then
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(Object.SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	Else
		SalesOrderPosition = Object.SalesOrderPosition;
	EndIf;
	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		OrdersArray.Add(Object.Order);
	Else
		OrdersGO = Object.Inventory.Unload(, "Order");
		OrdersGO.GroupBy("Order");
		OrdersArray = OrdersGO.UnloadColumn("Order");
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	DiscountsMarkups.Ref AS Order,
	|	DiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	DiscountsMarkups.Amount AS AutomaticDiscountAmount,
	|	CASE
	|		WHEN SalesOrderInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsTypeInventory,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE SalesOrderInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	SalesOrderInventory.Products,
	|	SalesOrderInventory.Characteristic,
	|	SalesOrderInventory.MeasurementUnit,
	|	SalesOrderInventory.Quantity
	|FROM
	|	Document.SalesOrder.DiscountsMarkups AS DiscountsMarkups
	|		INNER JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|		ON DiscountsMarkups.Ref = SalesOrderInventory.Ref
	|			AND DiscountsMarkups.ConnectionKey = SalesOrderInventory.ConnectionKey
	|WHERE
	|	DiscountsMarkups.Ref IN(&OrdersArray)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	
	ResultsArray = Query.ExecuteBatch();
	
	OrderDiscountsMarkups = ResultsArray[0].Unload();
	
	Object.DiscountsMarkups.Clear();
	For Each CurrentDocumentRow In Object.Inventory Do
		CurrentDocumentRow.AutomaticDiscountsPercent = 0;
		CurrentDocumentRow.AutomaticDiscountAmount = 0;
	EndDo;
	
	DiscountsMarkupsCalculationResult = Object.DiscountsMarkups.Unload();
	
	For Each CurrentOrderRow In OrderDiscountsMarkups Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Order", CurrentOrderRow.Order);
		StructureForSearch.Insert("Products", CurrentOrderRow.Products);
		StructureForSearch.Insert("Characteristic", CurrentOrderRow.Characteristic);
		
		DocumentRowsArray = Object.Inventory.FindRows(StructureForSearch);
		If DocumentRowsArray.Count() = 0 Then
			Continue;
		EndIf;
		
		QuantityInOrder = CurrentOrderRow.Quantity * CurrentOrderRow.Factor;
		Distributed = 0;
		For Each CurrentDocumentRow In DocumentRowsArray Do
			QuantityToWriteOff = CurrentDocumentRow.Quantity * 
									?(TypeOf(CurrentDocumentRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), 1, CurrentDocumentRow.MeasurementUnit.Factor);
			
			RecalculateAmounts = QuantityInOrder <> QuantityToWriteOff;
			DiscountRecalculationCoefficient = ?(RecalculateAmounts, QuantityToWriteOff / QuantityInOrder, 1);
			If DiscountRecalculationCoefficient <> 1 Then
				CurrentAutomaticDiscountAmount = ROUND(CurrentOrderRow.AutomaticDiscountAmount * DiscountRecalculationCoefficient,2);
			Else
				CurrentAutomaticDiscountAmount = CurrentOrderRow.AutomaticDiscountAmount;
			EndIf;
			
			DiscountString = DiscountsMarkupsCalculationResult.Add();
			FillPropertyValues(DiscountString, CurrentOrderRow);
			DiscountString.Amount = CurrentAutomaticDiscountAmount;
			DiscountString.ConnectionKey = CurrentDocumentRow.ConnectionKey;
			
			CurrentOrderRow.AutomaticDiscountAmount = CurrentOrderRow.AutomaticDiscountAmount - CurrentAutomaticDiscountAmount;
			QuantityInOrder = QuantityInOrder - QuantityToWriteOff;
			If QuantityInOrder <=0 Or CurrentOrderRow.AutomaticDiscountAmount <=0 Then
				Break;
			EndIf;
		EndDo;
		
	EndDo;
	
	DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(Object, "Inventory", DiscountsMarkupsCalculationResult);
	
EndProcedure

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
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

// Function compares discount calculating data on current moment with data of the discount last calculation in document.
// If discounts changed the function returns the value True.
//
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
Function GetAutomaticDiscountCalculationParametersStructureServer()

	OrderParametersStructure = New Structure("ImplementationByOrders, SalesExceedingOrder", False, False);
	
	If Not ValueIsFilled(Object.SalesOrderPosition) Then
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	Else
		SalesOrderPosition = Object.SalesOrderPosition;
	EndIf;
	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		If ValueIsFilled(Object.Order) Then
			OrderParametersStructure.ImplementationByOrders = True;
		Else
			OrderParametersStructure.ImplementationByOrders = False;
		EndIf;
		OrderParametersStructure.SalesExceedingOrder = False;
	Else
		Query = New Query;
		Query.Text = 
			"SELECT
			|	SalesInvoiceInventory.Order AS Order
			|INTO TU_Inventory
			|FROM
			|	&Inventory AS SalesInvoiceInventory
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	TU_Inventory.Order AS Order
			|FROM
			|	TU_Inventory AS TU_Inventory
			|
			|GROUP BY
			|	TU_Inventory.Order";
		
		Query.SetParameter("Inventory", Object.Inventory.Unload());
		QueryResult = Query.Execute();
		
		Selection = QueryResult.Select();
		
		While Selection.Next() Do
			If ValueIsFilled(Selection.Order) Then
				OrderParametersStructure.ImplementationByOrders = True;
			Else
				OrderParametersStructure.SalesExceedingOrder = True;
			EndIf;
		EndDo;
	EndIf;
	
	Return OrderParametersStructure;
	
EndFunction

&AtServer
Procedure CalculateDiscountsMarkupsOnServer(ParameterStructure)
	
	OrderParametersStructure = GetAutomaticDiscountCalculationParametersStructureServer(); // If there are orders in TS "Goods", then for such rows the automatic discount shall be calculated by the order.
	If OrderParametersStructure.ImplementationByOrders Then
		CalculateMarkupsDiscountsForOrderServer();
		If OrderParametersStructure.SalesExceedingOrder Then
			ParameterStructure.Insert("SalesExceedingOrder", True);
			AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
		Else
			ParameterStructure.Insert("ApplyToObject", False);
			AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
		EndIf;
	Else
		AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	EndIf;
	
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
Procedure OpenInformationAboutDiscounts(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient()
	
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
		
	EndIf;
	// End Bundles
	
	If Item.CurrentItem = Items.InventoryAutomaticDiscountPercent
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient()
		
	EndIf;
	
	If Field.Name = "InventoryGLAccounts" Then
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
		StandardProcessing = False;
	ElsIf Field.Name = "InventoryIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Inventory");
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	// AutomaticDiscounts
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
	EndIf;
	// End AutomaticDiscounts
	
	ThisIsNewRow = NewRow;	
	
	If NewRow AND Copy Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;	
	
	If Item.CurrentItem.Name = "SerialNumbersInventory" Then
		OpenSerialNumbersSelection();
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	
EndProcedure

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Bundles
	If Items.Inventory.SelectedRows.Count() = Object.Inventory.Count() Then
		
		Object.AddedBundles.Clear();
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
	
	If Not Cancel Then
		// Serial numbers
		CurrentData = Items.Inventory.CurrentData;
		WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData,,UseSerialNumbersBalance);
	EndIf;
	
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

&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
	RecalculateSalesTax();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RefillDiscountAmountOfEPD();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure InventoryOrderStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	StructureFilter = New Structure();
	StructureFilter.Insert("Company",		Object.Company);
	StructureFilter.Insert("Counterparty",	Object.Counterparty);
	
	If ValueIsFilled(Object.Contract) Then
		StructureFilter.Insert("Contract", Object.Contract);
	EndIf;
	
	ParameterStructure = New Structure("Filter", StructureFilter);
	
	OpenForm("CommonForm.SelectDocumentOrder", ParameterStructure, Item);

EndProcedure

&AtClient
Procedure InventoryOrderChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	ProcessInventoryOrderSelection(SelectedValue);

EndProcedure

&AtClient
Procedure InventoryOrderOnChange(Item)
	
	// AutomaticDiscounts
	If ClearCheckboxDiscountsAreCalculatedClient("InventoryOrderOnChange") Then
		CalculateAmountInTabularSectionLine(Undefined, False);
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure PaymentMethodOnChange(Item)
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	SetVisiblePaymentMethod();
	
	If Object.PaymentMethod <> PredefinedValue("Catalog.PaymentMethods.DirectDebit") Then
		Object.DirectDebitMandate = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure FieldSwitchTypeListOfPaymentCalendarOnChange(Item)
	
	PaymentCalendarCount = Object.PaymentCalendar.Count();
	
	If Not SwitchTypeListOfPaymentCalendar Then
		If PaymentCalendarCount > 1 Then
			ClearMessages();
			TextMessage = NStr("en = 'You can''t change the mode of payment terms because there is more than one payment date'; ru = 'Вы не можете переключить режим отображения платежного календаря, т.к. указано более одной даты оплаты.';pl = 'Nie możesz zmienić trybu warunków płatności, ponieważ istnieje kilka dat płatności';es_ES = 'Usted no puede cambiar el modo de los términos de pago porque hay más de una fecha de pago';es_CO = 'Usted no puede cambiar el modo de los términos de pago porque hay más de una fecha de pago';tr = 'Birden fazla ödeme tarihi olduğundan, ödeme şartlarının modu değiştirilemez';it = 'Non è possibile modificare i termini di pagamento, perché c''è più di una data di pagamento';de = 'Sie können den Modus der Zahlungsbedingungen nicht ändern, da es mehr als einen Zahlungsdatum gibt.'");
			CommonClientServer.MessageToUser(TextMessage);
			
			SwitchTypeListOfPaymentCalendar = 1;
		ElsIf PaymentCalendarCount = 0 Then
			NewLine = Object.PaymentCalendar.Add();
		EndIf;
	EndIf;
		
	SetVisiblePaymentCalendar();
	SetVisiblePaymentMethod();
	
EndProcedure

&AtClient
Procedure PaymentCalendarPaymentAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	TotalAmount = Object.Inventory.Total("Amount") + Object.SalesTax.Total("Amount");
	TotalVATAmount = Object.Inventory.Total("VATAmount");
	
	If TotalAmount = 0 Then
		CurrentRow.PaymentPercentage	= 0;
		CurrentRow.PaymentVATAmount			= 0;
	Else
		CurrentRow.PaymentPercentage	= Round(CurrentRow.PaymentAmount / TotalAmount * 100, 2, 1);
		CurrentRow.PaymentVATAmount			= Round(TotalVATAmount * CurrentRow.PaymentAmount / TotalAmount, 2, 1);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	CurrentRow.PaymentAmount	= Round((Object.Inventory.Total("Amount") + Object.SalesTax.Total("Amount")) * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount	= Round(Object.Inventory.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	TotalVAT = Object.Inventory.Total("VATAmount");
	
	If PaymentCalendarTotal > TotalVAT Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - TotalVAT);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Clone)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	If NewRow Then
		CurrentRow.PaymentBaselineDate = PredefinedValue("Enum.BaselineDateForPayment.InvoicePostingDate");
	EndIf;
	
	If CurrentRow.PaymentPercentage = 0 Then
		CurrentRow.PaymentPercentage = 100 - Object.PaymentCalendar.Total("PaymentPercentage");
		CurrentRow.PaymentAmount = Object.Inventory.Total("Amount") + Object.SalesTax.Total("Amount") - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = Object.Inventory.Total("VATAmount") - Object.PaymentCalendar.Total("PaymentVATAmount");
	EndIf;
	
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
Procedure PrepaymentOnChange(Item)
	PrepaymentWasChanged = True;
EndProcedure

&AtClient
Procedure DirectDebitMandateOnChange(Item)
	Object.CounterpartyBankAcc = GetCounterpartyBankAccFromDirectDebitMandate(Object.DirectDebitMandate);
EndProcedure

&AtClient
Procedure PaymentCalendarBeforeDeleteRow(Item, Cancel)
	
	If Object.PaymentCalendar.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region DiscountCards

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
		Text = NStr("en = 'Do you want to update the discounts in all lines?'; ru = 'Перезаполнить скидки во всех строках?';pl = 'Czy chcesz zaktualizować rabaty we wszystkich wierszach?';es_ES = '¿Quiere actualizar los descuentos en todas las líneas?';es_CO = '¿Quiere actualizar los descuentos en todas las líneas?';tr = 'Tüm satırlardaki indirimleri güncellemek istiyor musunuz?';it = 'Volete aggiornare gli sconti in tutte le linee?';de = 'Möchten Sie die Rabatte in allen Linien aktualisieren?'");
		Notification = New NotifyDescription("DiscountCardIsSelectedAdditionallyEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;

EndProcedure

&AtClient
Procedure DiscountCardIsSelectedAdditionallyEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
	EndIf;
	
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
				NStr("en = 'Do you want to change the card discount percent from %1% to %2% and recalculate discounts in all rows?'; ru = 'Процент скидки карты изменится с %1% на %2% и будет перезаполнен в документе. Продолжить?';pl = 'Czy chcesz zmienić procent karty rabatowej z %1% na %2% i obliczyć rabaty we wszystkich wierszach?';es_ES = '¿Quiere cambiar el por ciento del descuento de la tarjeta de %1% a %2% y recalcular los descuentos en todas las filas?';es_CO = '¿Quiere cambiar el por ciento del descuento de la tarjeta de %1% a %2% y recalcular los descuentos en todas las filas?';tr = '%1% ile %2% arasında kart indirimi yüzdesini değiştirmek ve tüm satırlardaki indirimleri yeniden hesaplamak istiyor musunuz?';it = 'Volete cambiare la percentuale di sconto della carta da %1% a %2% e ricalcolare gli sconti in tutte le righe?';de = 'Möchten Sie den Prozentsatz der Kartenrabatte von %1% bis %2% ändern und die Rabatte in allen Zeilen neu berechnen?'"),
				PreDiscountPercentByDiscountCard,
				NewDiscountPercentByDiscountCard);
			AdditionalParameters	= New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, True);
			Notification			= New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
			
		Else
			
			Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Change the percent of discount of the card from %1% to %2%?'; ru = 'Изменить процент скидки карты с %1% на %2%?';pl = 'Zmienić procent rabatu na karcie z %1% na %2%?';es_ES = '¿Cambiar el por ciento del descuento de la tarjeta de %1% a %2%?';es_CO = '¿Cambiar el por ciento del descuento de la tarjeta de %1% a %2%?';tr = 'Kartın indirim yüzdesi %1%''den %2%''ye değiştirilsin mi?';it = 'Cambiare la percentuale di sconto della carta da %1% a %2%';de = 'Ändern des Prozentsatzes des Rabattes der Karte von %1% auf %2%?'"),
				PreDiscountPercentByDiscountCard,
				NewDiscountPercentByDiscountCard);
			AdditionalParameters	= New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, False);
			Notification			= New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
			
		EndIf;
		
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChangeEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		Object.DiscountPercentByDiscountCard = AdditionalParameters.NewDiscountPercentByDiscountCard;
		
		GenerateLabelPricesAndCurrency(ThisObject);
		
		If AdditionalParameters.RecalculateTP Then
			DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
		EndIf;
				
	EndIf;
	
EndProcedure

&AtClient
Procedure ReadDiscountCardClick(Item)
	
	ParametersStructure = New Structure("Counterparty", Object.Counterparty);
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);	
	
EndProcedure

&AtClient
Procedure ReadDiscountCardClickEnd(ReturnParameters, Parameters) Export

	If TypeOf(ReturnParameters) = Type("Structure") Then
		DiscountCardRead = ReturnParameters.DiscountCardRead;
		DiscountCardIsSelected(ReturnParameters.DiscountCard);
	EndIf;

EndProcedure

#EndRegion

#Region LibrariesHandlers

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileInventory(Command)
	
	DataLoadSettings.Insert("TabularSectionFullName",	"SalesInvoice.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import inventory from file'; ru = 'Загрузка запасов из файла';pl = 'Import zapasów z pliku';es_ES = 'Importar el inventario del archivo';es_CO = 'Importar el inventario del archivo';tr = 'Stoku dosyadan içe aktar';it = 'Importazione delle scorte da file';de = 'Bestand aus Datei importieren'"));
	
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
	
EndProcedure

#EndRegion

&AtClient
Procedure EDIStateDecorationClick(Item)
	
	EDIClient.EDIStateDecorationClick(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_EDIExecuteCommand(Command)
	
	EDIClient.EDIExecuteCommand(Command, ThisObject, Object);
	
EndProcedure

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

#Region CopyPasteRows

&AtClient
Procedure CopyRows(Command)
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
Procedure PasteRows(Command)
	
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
	
	Count = Object[TabularPartName].Count();
	
	For Iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - Iterator];
		CalculateAmountInTabularSectionLine(Row, , False);
		
	EndDo; 
	
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
		
		AddIncomeAndExpenseItemsToStructure(ThisObject, TabularPartName, StructureData, Row);
		
		If UseDefaultTypeOfAccounting Then 
			AddGLAccountsToStructure(ThisObject, TabularPartName, StructureData, Row);
		EndIf;
		
		StructureData = GetDataProductsOnChange(StructureData);
		
		If Not ValueIsFilled(Row.MeasurementUnit) Then
			Row.MeasurementUnit = StructureData.MeasurementUnit;
		EndIf;
		
		Row.VATRate = StructureData.VATRate;
		Row.ProductsTypeInventory = StructureData.ProductsTypeInventory;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

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

&AtClient
Procedure ClearPaymentCalendarContinue(Answer, Parameters) Export
	If Answer = DialogReturnCode.Yes Then
		Object.PaymentCalendar.Clear();
		SetEnableGroupPaymentCalendarDetails();
	ElsIf Answer = DialogReturnCode.No Then
		Object.SetPaymentTerms = True;
	EndIf;
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

&AtClient
Procedure SetEnableGroupPaymentCalendarDetails()
	Items.GroupPaymentCalendarDetails.Enabled = Object.SetPaymentTerms;
EndProcedure

&AtServer
Procedure SetSwitchTypeListOfPaymentCalendar()
	
	If Object.PaymentCalendar.Count() > 1 Then
		SwitchTypeListOfPaymentCalendar = 1;
	Else
		SwitchTypeListOfPaymentCalendar = 0;
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
	
	If Object.PaymentMethod = PredefinedValue("Catalog.PaymentMethods.DirectDebit") Then
		Items.DirectDebitMandate.Visible = True;
		Items.BankAccount.Visible = True;
		Items.PettyCash.Visible = False;
	Else
		Items.DirectDebitMandate.Visible = False;
	EndIf;
	
EndProcedure
	
&AtServerNoContext
Function PaymentMethodCashAssetType(PaymentMethod)
	
	Return Common.ObjectAttributeValue(PaymentMethod, "CashAssetType");
	
EndFunction

&AtClient
Procedure SetVisiblePaymentCalendar()
	
	If SwitchTypeListOfPaymentCalendar Then
		Items.PagesPaymentCalendar.CurrentPage = Items.PagePaymentCalendarAsList;
	Else
		Items.PagesPaymentCalendar.CurrentPage = Items.PagePaymentCalendarWithoutSplitting;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVisibleEarlyPaymentDiscounts()
	
	VisibleFlag = GetVisibleFlagForEPD(Object.Counterparty, Object.Contract);
	
	Items.GroupEarlyPaymentDiscounts.Visible = (VisibleFlag
		And Not Object.ThirdPartyPayment
		And Object.OperationKind <> PredefinedValue("Enum.OperationTypesSalesInvoice.ZeroInvoice"));
	
EndProcedure

&AtServerNoContext
Function GetVisibleFlagForEPD(Counterparty, Contract)
	
	If ValueIsFilled(Contract) Then
		ContractKind		= Common.ObjectAttributeValue(Contract, "ContractKind");
		ContractKindFlag	= ContractKind = Enums.ContractType.WithCustomer;
	Else
		ContractKindFlag	= False;
	EndIf;
	
	Return (ValueIsFilled(Counterparty) AND ContractKindFlag);
	
EndFunction

&AtServer
Procedure SetPrepaymentColumnsProperties()
	
	Items.PrepaymentSettlementsAmount.Title =
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Clearing amount (%1)'; ru = 'Сумма зачета (%1)';pl = 'Kwota rozliczenia (%1)';es_ES = 'Importe de liquidaciones (%1)';es_CO = 'Importe de liquidaciones (%1)';tr = 'Mahsup edilen tutar (%1)';it = 'Importo di compensazione (%1)';de = 'Ausgleichsbetrag (%1)'"),
			SettlementCurrency);
	
	If Object.DocumentCurrency = SettlementCurrency Then
		Items.PrepaymentAmountDocCur.Visible = False;
	Else
		Items.PrepaymentAmountDocCur.Visible = True;
		Items.PrepaymentAmountDocCur.Title =
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Amount (%1)'; ru = 'Сумма (%1)';pl = 'Wartość (%1)';es_ES = 'Importe (%1)';es_CO = 'Cantidad (%1)';tr = 'Tutar (%1)';it = 'Importo (%1)';de = 'Betrag (%1)'"),
				Object.DocumentCurrency);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillEarlyPaymentDiscounts()
	
	EarlyPaymentDiscountsServer.FillEarlyPaymentDiscounts(Object, Enums.ContractType.WithCustomer);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", False);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure RefillDiscountAmountOfEPD()
	RefillDiscountAmountOfEPDNoContext(Object);
EndProcedure

&AtClientAtServerNoContext
Procedure RefillDiscountAmountOfEPDNoContext(Object)
	
	TotalAmount = Object.Inventory.Total("Total");
	
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

&AtClient
Procedure EarlyPaymentDiscountsPeriodOnChange(Item)
	
	CurrentData = Items.EarlyPaymentDiscounts.CurrentData;
	EarlyPaymentDiscountsClientServer.CalculateDueDateOfEPD(Object.Date, CurrentData);
	
EndProcedure

&AtClient
Procedure EarlyPaymentDiscountsDiscountOnChange(Item)
	DiscountRow = Items.EarlyPaymentDiscounts.CurrentData;
	CalculateRowDiscountAmountOfEPD(Object.Inventory.Total("Total"), DiscountRow);
EndProcedure

&AtClient
Procedure ProcessShippingAddressChange()
	
	DeliveryData = GetDeliveryAttributes(Object.ShippingAddress);
	
	FillPropertyValues(Object, DeliveryData);
	If ValueIsFilled(DeliveryData.SalesRep) Then
		For Each Row In Object.Inventory Do
			Row.SalesRep = DeliveryData.SalesRep;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Function GetDeliveryData(Counterparty)
	Return ShippingAddressesServer.GetDeliveryDataForCounterparty(Counterparty, False);
EndFunction

&AtServer
Function GetDeliveryAttributes(ShippingAddress)
	Return ShippingAddressesServer.GetDeliveryAttributesForAddress(ShippingAddress);
EndFunction

&AtServer
Function CheckEarlyPaymentDiscounts()
	
	Return EarlyPaymentDiscountsServer.CheckEarlyPaymentDiscounts(Object.EarlyPaymentDiscounts, Object.ProvideEPD);
	
EndFunction

&AtClient
Procedure SetVisibleSalesRep()
	
	If Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
		Items.SalesRep.Visible = True;
	Else 
		Items.SalesRep.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Function SalesRep(Source)
	Return Common.ObjectAttributeValue(Source, "SalesRep");
EndFunction

&AtClient
Procedure ProcessOrderDocumentSelection(DocumentData)
	
	If TypeOf(DocumentData) = Type("Structure") Then
		
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = DocumentData.Contract;
			ProcessContractChange();
		EndIf;
		
		Object.Order = DocumentData.Document;
		
		If Object.Prepayment.Count() > 0
			AND Object.Order <> Order Then
			
			Mode = QuestionDialogMode.YesNo;
			Response = Undefined;
			ShowQueryBox(New NotifyDescription("OrderOnChangeEnd", ThisObject), NStr("en = 'Advances will be cleared. Do you want to continue?'; ru = 'Зачет аванса будет очищен, продолжить?';pl = 'Zaliczki zostaną rozliczone. Czy chcesz kontynuować?';es_ES = 'Anticipos se liquidarán. ¿Quiere continuar?';es_CO = 'Anticipos se liquidarán. ¿Quiere continuar?';tr = 'Avanslar silinecek. Devam etmek istiyor musunuz?';it = 'Gli anticipi saranno compensati. Volete continuare?';de = 'Vorauszahlungen werden gelöscht. Möchten Sie fortsetzen?'"), Mode, 0);
			Return;
			
		EndIf;
		
		If Order <> Object.Order
			And ValueIsFilled(Object.Order) Then
			SalesRep = SalesRep(Object.Order);
			If ValueIsFilled(SalesRep) Then
				For Each Row In Object.Inventory Do
					Row.SalesRep = SalesRep;
				EndDo;
			EndIf;
		EndIf;
		
		OrderOnChangeFragment();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessInventoryOrderSelection(DocumentData)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	If TypeOf(DocumentData) = Type("Structure") Then
		
		TabularSectionRow.Order = DocumentData.Document;
		
		If ClearCheckboxDiscountsAreCalculatedClient("InventoryOrderOnChange") Then
			CalculateAmountInTabularSectionLine(Undefined, False);
		EndIf;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting Then
	
		If ParametersStructure.FillHeader Then
			
			Header = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Header", Object);
			GLAccountsInDocuments.CompleteCounterpartyStructureData(Header, ObjectParameters, "Header");
			StructureArray.Add(Header);
			
		EndIf;
	
		If ParametersStructure.FillAmountAllocation Then
			
			StructureData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "AmountAllocation");
			GLAccountsInDocuments.CompleteCounterpartyStructureData(StructureData, ObjectParameters, "AmountAllocation");
			StructureArray.Add(StructureData);
			
		EndIf;
		
	EndIf;
	
	If ParametersStructure.FillInventory Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
		EndIf;
		
		StructureArray.Add(StructureData);
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
	If UseDefaultTypeOfAccounting And ParametersStructure.FillHeader Then
		GLAccounts = Header.GLAccounts;
	EndIf;
	
EndProcedure

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
		|Taxable,
		|Batch,
		|GoodsIssue,
		|ProductsTypeInventory,
		|UseDefaultTypeOfAccounting,
		|IncomeAndExpenseItems,
		|IncomeAndExpenseItemsFilled,
		|RevenueItem,
		|COGSItem");
	
	FillPropertyValues(StructureData, Form);
	FillPropertyValues(StructureData, Object);
	FillPropertyValues(StructureData, TabRow);
	
	StructureData.Insert("TabName", TabName);
	
	Return StructureData;
	
EndFunction

&AtClientAtServerNoContext
Procedure AddGLAccountsToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("Object",					Form.Object);
	StructureData.Insert("ProductGLAccounts",		True);
	StructureData.Insert("ProductsTypeInventory",	TabRow.ProductsTypeInventory);
	StructureData.Insert("Batch",					TabRow.Batch);
	StructureData.Insert("GoodsIssue",				TabRow.GoodsIssue);
	StructureData.Insert("GLAccounts",				TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",		TabRow.GLAccountsFilled);
	StructureData.Insert("InventoryGLAccount",		TabRow.InventoryGLAccount);
	StructureData.Insert("RevenueGLAccount",		TabRow.RevenueGLAccount);
	StructureData.Insert("COGSGLAccount",			TabRow.COGSGLAccount);
	StructureData.Insert("VATOutputGLAccount",		TabRow.VATOutputGLAccount);
	StructureData.Insert("InventoryReceivedGLAccount",			TabRow.InventoryReceivedGLAccount);
	StructureData.Insert("GoodsShippedNotInvoicedGLAccount",	TabRow.GoodsShippedNotInvoicedGLAccount);
	StructureData.Insert("UnearnedRevenueGLAccount",			TabRow.UnearnedRevenueGLAccount);
	
EndProcedure

&AtClientAtServerNoContext
Procedure AddIncomeAndExpenseItemsToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("Object",					Form.Object);
	StructureData.Insert("ProductsTypeInventory",	TabRow.ProductsTypeInventory);
	StructureData.Insert("Batch",					TabRow.Batch);
	StructureData.Insert("GoodsIssue",				TabRow.GoodsIssue);
	StructureData.Insert("RevenueItem",				TabRow.RevenueItem);
	StructureData.Insert("COGSItem",				TabRow.COGSItem);
	StructureData.Insert("TabName",					TabName);
	
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateLabelPricesAndCurrency(Form)
	
	Object = Form.Object;
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Form.SettlementCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		Form.ForeignExchangeAccounting);
	LabelStructure.Insert("ExchangeRateNationalCurrency",	Form.ExchangeRateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				Form.RegisteredForVAT);
	LabelStructure.Insert("RegisteredForSalesTax",			Form.RegisteredForSalesTax);
	LabelStructure.Insert("SalesTaxRate",					Object.SalesTaxRate);
	
	Form.PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

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
			Object.AddedBundles);
			
		Modified = True;
		RecalculateSalesTax();
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
		RecalculateSubtotal();
		SetBundlePictureVisible();
		
	ElsIf Result = "DeleteOne" Then
		
		FilterStructure = New Structure;
		FilterStructure.Insert("BundleProduct",			BundleRow.BundleProduct);
		FilterStructure.Insert("BundleCharacteristic",	BundleRow.BundleCharacteristic);
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
			OldCount);
			
		BundleRows = Object.Inventory.FindRows(FilterStructure);
		For Each Row In BundleRows Do
			CalculateAmountInTabularSectionLine(Row, , False);
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
	
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, BundleLine, , Form.UseSerialNumbersBalance);
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
	FillingParameters.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	BundlesServer.RefreshBundleComponentsInTable(BundleProduct, BundleCharacteristic, Quantity, BundleComponents, FillingParameters);
	Modified = True;
	
	// AutomaticDiscounts
	ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure ActionsAfterDeleteBundleLine()
	
	RecalculateSalesTax();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow")
	
EndProcedure

&AtClient
Procedure EditBundlesComponents(InventoryLine)
	
	OpeningStructure = New Structure;
	OpeningStructure.Insert("BundleProduct", InventoryLine.BundleProduct);
	OpeningStructure.Insert("BundleCharacteristic", InventoryLine.BundleCharacteristic);
	
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

#EndRegion

&AtServerNoContext
Function GetCounterpartyBankAccFromDirectDebitMandate(DirectDebitMandate)
	Return Common.ObjectAttributeValue(DirectDebitMandate, "BankAccount");
EndFunction	

&AtClient
Procedure SetVisibleThirdPartyPayer()
	
	Items.Payer.Visible = (Object.ThirdPartyPayment And ValueIsFilled(SettlementCurrency));
	
EndProcedure

&AtClient
Procedure SetVisibleThirdPartyPayerContract()
	
	Items.PayerContract.Visible = (Object.ThirdPartyPayment
		And ValueIsFilled(SettlementCurrency)
		And PayerAttributes.DoOperationsByContracts);
	
EndProcedure

&AtClient
Procedure SetVisiblePrepaymentAndPaymentCalendar()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesInvoice.Invoice")
		Or Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesInvoice.AdvanceInvoice") Then
		Items.GroupPrepayment.Visible = Not Object.ThirdPartyPayment;
		Items.GroupPaymentCalendar.Visible = Not Object.ThirdPartyPayment;
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure ReadPayerAttributes(StructureAttributes, Val Payer)
	
	Attributes = "DoOperationsByContracts, SettlementsCurrency";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, Payer, Attributes);
	
EndProcedure

&AtClient
Procedure SetDeliveryDates()
	
	For Each LineInventory In Object.Inventory Do
		
		LineInventory.DeliveryStartDate = Object.DeliveryStartDate;
		LineInventory.DeliveryEndDate = Object.DeliveryEndDate;
		
	EndDo;
		
EndProcedure

&AtClient
Procedure GetDeliveryDates()
	
	If Object.Inventory.Count() > 0 Then
		
		InventoryLine = Object.Inventory[0];
		Object.DeliveryStartDate = InventoryLine.DeliveryStartDate;
		Object.DeliveryEndDate = InventoryLine.DeliveryEndDate;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ReadDeliveryDatePosition()
	
	IsDeliveryDateInTable = (Object.DeliveryDatePosition = Enums.AttributeStationing.InTabularSection);
	
EndProcedure

&AtServer
Procedure SetDeliveryDatePosition()
	
	If IsDeliveryDateInTable Then
		Object.DeliveryDatePosition = Enums.AttributeStationing.InTabularSection;
	Else 
		Object.DeliveryDatePosition = Enums.AttributeStationing.InHeader;
	EndIf;
	
EndProcedure

#EndRegion

#Region SalesTax

&AtServer
Procedure SetVisibleTaxAttributes()
	
	IsSubjectToVAT = (Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT);
	
	Items.InventoryVATRate.Visible				= IsSubjectToVAT;
	Items.InventoryVATAmount.Visible			= IsSubjectToVAT;
	Items.InventoryAmountTotal.Visible			= IsSubjectToVAT;
	Items.PaymentVATAmount.Visible				= IsSubjectToVAT;
	Items.PaymentCalendarPayVATAmount.Visible	= IsSubjectToVAT;
	Items.DocumentTax.Visible					= IsSubjectToVAT Or RegisteredForSalesTax;
	Items.InventoryTaxable.Visible				= RegisteredForSalesTax;
	Items.GroupSalesTax.Visible					= RegisteredForSalesTax;
	Items.InventorySalesTaxAmount.Visible		= RegisteredForSalesTax;
	
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
	
	InventoryTaxable = Object.Inventory.Unload(New Structure("Taxable", True));
	
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
	FormObject.RecalculateSalesTax();
	ValueToFormAttribute(FormObject, "Object");
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillHeader", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAmountAllocation", False);
	
	FillAddedColumns(ParametersStructure);
	
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	
EndProcedure

&AtClient
Procedure InventoryTaxableOnChange(Item)
	
	RecalculateSalesTax();
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(Object);
	RecalculateSubtotal();
	
EndProcedure

#EndRegion

#Region InvoiceType

&AtServer
Procedure SetZeroInvoiceData(ParametersStructure)
	
	InventoryAttributes	= Metadata.Documents.SalesInvoice.TabularSections.Inventory.Attributes;
	
	For Each LineInventory In Object.Inventory Do
	
		For Each MetaAttribute In InventoryAttributes Do
			
			If MetaAttribute.Name = "Products"
				Or MetaAttribute.Name = "ProductsTypeInventory" Then
			
				Continue;
			
			EndIf;
			
			LineInventory[MetaAttribute.Name] = Undefined;
			
		EndDo;
	
	EndDo;
	
	Object.Order			= Documents.PurchaseOrder.EmptyRef();
	Object.BasisDocument	= Undefined;
	Object.SetPaymentTerms	= False;
	
	Object.ConsumerMaterials.Clear();
	Object.Prepayment.Clear();
	Object.AmountAllocation.Clear();
	Object.IssuedInvoices.Clear();
	Object.SerialNumbers.Clear();
	Object.PaymentCalendar.Clear();
	Object.PrepaymentVAT.Clear();
	Object.EarlyPaymentDiscounts.Clear();
	Object.SalesTax.Clear();
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure SetVisibleAccordingToInvoiceType()
	
	ValueAutoMarkIncomplete	= Undefined;
	IsReadOnly				= False;
	VisibleRegularInvoice	= True;
	VisibleClosingInvoice	= False;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesInvoice.ZeroInvoice") Then
		
		ValueAutoMarkIncomplete = False;
		IsReadOnly				= True;
		VisibleRegularInvoice	= False;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesInvoice.ClosingInvoice") Then
		
		VisibleClosingInvoice = True;
		
	ElsIf Object.ForOpeningBalancesOnly Then
		
		ValueAutoMarkIncomplete = False;
		
	EndIf;
	
	Items.InventoryAmount.AutoMarkIncomplete			= ValueAutoMarkIncomplete;
	Items.InventoryQuantity.AutoMarkIncomplete			= ValueAutoMarkIncomplete;
	Items.InventoryPrice.AutoMarkIncomplete				= ValueAutoMarkIncomplete;
	Items.InventoryMeasurementUnit.AutoMarkIncomplete	= ValueAutoMarkIncomplete;
	Items.InventoryVATRate.AutoMarkIncomplete			= ValueAutoMarkIncomplete;
	
	Items.GroupConsumerMaterials.Visible		= VisibleRegularInvoice And Not VisibleClosingInvoice;
	Items.GroupPaymentCalendar.Visible			= VisibleRegularInvoice;
	Items.GroupSalesTax.Visible					= VisibleRegularInvoice And RegisteredForSalesTax;
	Items.GroupDelivery.Visible					= VisibleRegularInvoice;
	Items.GroupBasisDocument.Visible			= VisibleRegularInvoice And Not VisibleClosingInvoice; 	
	Items.TaxInvoiceText.Visible				= VisibleRegularInvoice And UseTaxInvoice;
	Items.ThirdPartyPayment.Visible				= VisibleRegularInvoice And Not VisibleClosingInvoice;
	Items.FolderOrderBasis.Visible				= VisibleRegularInvoice And Not VisibleClosingInvoice;
	Items.Totals.Visible						= VisibleRegularInvoice;
	Items.InventoryReserve.Visible				= VisibleRegularInvoice And Not VisibleClosingInvoice;
	
	Items.InventorySearchByBarcode.Visible					= VisibleRegularInvoice And Not VisibleClosingInvoice;
	
	Items.InventoryDataImportFromExternalSources.Visible = Items.InventoryDataImportFromExternalSources.Visible
		And VisibleRegularInvoice And Not VisibleClosingInvoice;
	
	Items.FillBatchesByFEFO.Visible	= VisibleRegularInvoice And Not VisibleClosingInvoice;
	
	Items.InventoryImportDataFromDCT.Visible = Items.InventoryImportDataFromDCT.Visible And Not VisibleClosingInvoice;
	Items.InventoryGetWeight.Visible = Items.InventoryGetWeight.Visible And Not VisibleClosingInvoice;
	
	// Products
	Items.InventoryGroupSelect.Visible					= VisibleRegularInvoice And Not VisibleClosingInvoice;
	Items.InventoryChangeReserve.Visible				= VisibleRegularInvoice And Not VisibleClosingInvoice;
	Items.InventoryCalculateDiscountsMarkups.Visible	= VisibleRegularInvoice;
	
	Items.InventoryActualQuantity.Visible	= VisibleClosingInvoice;
	Items.InventoryInvoicedQuantity.Visible	= VisibleClosingInvoice;
	Items.GroupIssuedInvoices.Visible		= VisibleClosingInvoice;
	
	Items.InventorySpecification.Visible = Not VisibleClosingInvoice;
	Items.InventoryGoodsIssue.Visible	 = Not VisibleClosingInvoice;
	
	Items.GroupAmountAllocation.Visible		= VisibleClosingInvoice And Object.DocumentAmount < 0;
	Items.GroupPrepayment.Visible			= VisibleRegularInvoice Or VisibleClosingInvoice And Object.DocumentAmount > 0;
	
	If VisibleClosingInvoice Then
		Items.DeliveryDate.AutoMarkIncomplete = True;
		Items.DeliveryEndDate.AutoMarkIncomplete = True;
		Items.InventoryDeliveryDate.AutoMarkIncomplete = True;
		Items.InventoryDeliveryStartDate.AutoMarkIncomplete = True;
		Items.InventoryDeliveryEndDate.AutoMarkIncomplete = True;
		Items.DeliveryDatePeriod.AutoMarkIncomplete = True;
	Else
		Items.DeliveryDate.AutoMarkIncomplete = False;
		Items.DeliveryDate.MarkIncomplete = False;
		Items.DeliveryEndDate.AutoMarkIncomplete = False;
		Items.DeliveryEndDate.MarkIncomplete = False;
		Items.InventoryDeliveryDate.AutoMarkIncomplete = False;
		Items.InventoryDeliveryDate.MarkIncomplete = False;
		Items.InventoryDeliveryStartDate.AutoMarkIncomplete = False;
		Items.InventoryDeliveryStartDate.MarkIncomplete = False;
		Items.InventoryDeliveryEndDate.AutoMarkIncomplete = False;
		Items.InventoryDeliveryEndDate.MarkIncomplete = False;
		Items.DeliveryDatePeriod.AutoMarkIncomplete = False;
		Items.DeliveryDatePeriod.MarkIncomplete = False;
	EndIf;
	
	If VisibleClosingInvoice Then
		NewSign = AllowedSign.Any;
	Else
		NewSign = AllowedSign.Nonnegative;
	EndIf;
	NewTypeRestriction = New TypeDescription("Number", New NumberQualifiers(15, 3, NewSign));
	Items.InventoryQuantity.TypeRestriction = NewTypeRestriction;
	NewTypeRestriction = New TypeDescription("Number", New NumberQualifiers(15, 2, NewSign));
	Items.InventoryAmount.TypeRestriction = NewTypeRestriction;
	Items.InventoryVATAmount.TypeRestriction = NewTypeRestriction;
	Items.InventoryAmountTotal.TypeRestriction = NewTypeRestriction;
	
	For Each ItemInventory In Items.Inventory.ChildItems Do
		
		If ItemInventory = Items.InventoryProducts Or ItemInventory = Items.InventoryAmountTotal Then
		
			Continue;
		
		EndIf; 
		
		ItemInventory.ReadOnly = IsReadOnly;
	
	EndDo;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesInvoice.AdvanceInvoice") Then
		
		Items.InventoryGoodsIssue.ReadOnly = True;
		
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesInvoice.Invoice")
		And DriveAccessManagementReUse.ExpiredBatchesInSalesDocumentsIsAllowed() Then
		Items.AllowExpiredBatches.Visible = True;
	Else
		Items.AllowExpiredBatches.Visible = False;
	EndIf;
	
	If Not AllowedEditDocumentPrices Then
		
		Items.InventoryPrice.ReadOnly					= Not AllowedEditDocumentPrices;
		Items.InventoryDiscountPercentMargin.ReadOnly	= Not AllowedEditDocumentPrices;
		Items.InventoryAmount.ReadOnly					= Not AllowedEditDocumentPrices;
		Items.InventoryVATAmount.ReadOnly				= Not AllowedEditDocumentPrices;
		
	EndIf;
	
	IsZeroInvoice = Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesInvoice.ZeroInvoice");
	Items.InventoryIncomeAndExpenseItems.Visible = Not IsZeroInvoice;
	
	If UseDefaultTypeOfAccounting Then
		Items.InventoryGLAccounts.Visible = Not IsZeroInvoice;
	EndIf;
	
	SetDeliveryDatePeriodVisible(ThisObject);
	
EndProcedure

&AtClient
Procedure SetMeasurementUnits()
	
	If Not OldOperationKind = PredefinedValue("Enum.OperationTypesSalesInvoice.ZeroInvoice") Then
		Return;
	EndIf;
	
	For Each LineInventory In Object.Inventory Do
	
		LineInventory.MeasurementUnit = GetMeasurementUnitOfProduct(LineInventory.Products);
	
	EndDo; 
	
EndProcedure

&AtServerNoContext
Function GetMeasurementUnitOfProduct(RefProducts)
	
	Return Common.ObjectAttributeValue(RefProducts, "MeasurementUnit");
	
EndFunction

#EndRegion

#Region Prepayment

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
	ParametersStructure.Insert("Company", ParentCompany);
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

#EndRegion

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion