#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Initializes the document receipt CR.
//
Procedure InitializeDocument()
	
	POSTerminal = Catalogs.POSTerminals.GetPOSTerminalByDefault(CashCR);
	
EndProcedure

// Fills document Receipt CR by cash register.
//
// Parameters
//  FillingData - Structure with the filter values
//
Procedure FillDocumentByCachRegister(CashCR)
	
	StatusCashCRSession = Documents.ShiftClosure.GetCashCRSessionStatus(CashCR);
	FillPropertyValues(ThisObject, StatusCashCRSession);
	
EndProcedure

// Fills document CR receipt in compliance with filter.
//
// Parameters
//  FillingData - Structure with the filter values
//
Procedure FillDocumentByFilter(FillingData)
	
	If FillingData.Property("CashCR") Then
		
		FillDocumentByCachRegister(FillingData.CashCR);
		
	EndIf;
	
EndProcedure

// Adds additional attributes necessary for document
// posting to passed structure.
//
// Parameters:
//  StructureAdditionalProperties - Structure of additional document properties.
//
Procedure AddAttributesToAdditionalPropertiesForPosting(StructureAdditionalProperties)
	
	StructureAdditionalProperties.ForPosting.Insert("CheckIssued", Status = Enums.SalesSlipStatus.Issued);
	StructureAdditionalProperties.ForPosting.Insert("ProductReserved", Status = Enums.SalesSlipStatus.ProductReserved);
	StructureAdditionalProperties.ForPosting.Insert("Archival", Archival);
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - handler of the OnCopy event.
//
Procedure OnCopy(CopiedObject)
	
	SalesSlipNumber = "";
	Archival = False;
	Status = Enums.SalesSlipStatus.ReceiptIsNotIssued;
	
	CashReceived = 0;
	PaymentWithPaymentCards.Clear();
		
	StatusCashCRSession = Documents.ShiftClosure.GetCashCRSessionStatus(CashCR);
	FillPropertyValues(ThisObject, StatusCashCRSession);
	
	InitializeDocument();
	
	If SerialNumbers.Count() Then
		
		For Each InventoryLine In Inventory Do
			InventoryLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbers.Clear();
		
	EndIf;
	
	InventoryOwnership.Clear();
	
EndProcedure

// Procedure - FillCheckProcessing event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If PaymentWithPaymentCards.Count() > 0 AND Not ValueIsFilled(POSTerminal) Then
		
		MessageText = NStr("en = 'The ""POS terminal"" field is not filled in'; ru = 'Поле ""Эквайринговый терминал"" не заполнено';pl = 'Nie wypełniono pola ""terminal POS""';es_ES = 'El campo ""Terminal TPV"" no está rellenado';es_CO = 'El campo ""Terminal TPV"" no está rellenado';tr = '""POS terminali"" alanı doldurulmadı';it = 'Il campo ""terminale POS"" non è compilato';de = 'Das Feld ""POS-Terminal"" ist nicht ausgefüllt'");

		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			,
			,
			"POSTerminal",
			Cancel
		);
		
	EndIf;
	
	If PaymentWithPaymentCards.Total("Amount") > DocumentAmount Then
		
		MessageText = NStr("en = 'Card payment amount is greater than the document amount'; ru = 'Сумма оплаты по карте превышает сумму документа';pl = 'Suma opłaty płatniczymi kartami przekracza sumę dokumentu';es_ES = 'Importe del pago con tarjeta es mayor al importe del documento';es_CO = 'Importe del pago con tarjeta es mayor al importe del documento';tr = 'Kart ödeme tutarı, belge tutarından daha büyüktür';it = 'L''importo del pagamento con carta è superiore all''importo del documento';de = 'Kartenzahlungsbetrag ist größer als der Belegbetrag'");
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			,
			,
			"PaymentWithPaymentCards",
			Cancel
		);

	EndIf;
	
	MessageText = NStr("en = 'Register shift is not opened'; ru = 'Кассовая смена не открыта';pl = 'Kasowa zmiana nie została otwarta';es_ES = 'Turno del registro no está abierto';es_CO = 'Turno del registro no está abierto';tr = 'Kasa vardiyası açılmadı';it = 'Il turno di cassa non è aperto';de = 'Kassenschicht ist nicht geöffnet'");
	
	If Not Documents.ShiftClosure.SessionIsOpen(CashCRSession, Date, MessageText) Then
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			,
			,
			"CashCRSession",
			Cancel
		);

	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	// Bundles
	BundlesServer.CheckTableFilling(ThisObject, "Inventory", Cancel);
	// End Bundles
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	DataTypeFill = TypeOf(FillingData);
	
	If DataTypeFill = Type("Structure") Then
		
		FillDocumentByFilter(FillingData);
		
	Else
		
		CashCR = Catalogs.CashRegisters.GetCashCRByDefault();
		If CashCR <> Undefined Then
			FillDocumentByCachRegister(CashCR);
		EndIf;
		
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
	InitializeDocument();
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
EndProcedure

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Status = Enums.SalesSlipStatus.Issued
	   AND WriteMode = DocumentWriteMode.UndoPosting
	   AND Not CashCR.UseWithoutEquipmentConnection Then
		
		MessageText = NStr("en = 'Cash receipt was issued on the fiscal data recorder. Cannot cancel posting'; ru = 'Кассовый чек пробит на фискальном регистраторе. Отмена проведения невозможна';pl = 'Paragon został wydrukowany przez rejestrator fiskalny. Nie można anulować księgowania';es_ES = 'Recibo de efectivo se ha emitido en el registro de datos fiscales. No se puede cancelar el envío';es_CO = 'Recibo de efectivo se ha emitido en el registro de datos fiscales. No se puede cancelar el envío';tr = 'Mali veri kaydedicide Nakit tahsilat fişi verildi. Onay iptal edilemiyor';it = 'L''Entrata di cassa è stata emessa dal registratore di cassa. Impossibile l''annullamento';de = 'Der Zahlungseingang wurde auf dem Fiskal-Datenbuchungsdokument ausgegeben. Die Buchung kann nicht storniert werden'");
		
		DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				,
				Cancel
			);
		
		Return;
		
	EndIf;
	
	If WriteMode = DocumentWriteMode.UndoPosting
	   AND CashCR.UseWithoutEquipmentConnection
	   AND CashCRSession.Posted
	   AND CashCRSession.CashCRSessionStatus = Enums.ShiftClosureStatus.Closed Then
		
		MessageText = NStr("en = 'Register shift is closed. Cannot cancel posting'; ru = 'Кассовая смена закрыта. Отмена проведения невозможна';pl = 'Zmiana kasowa została zamknięta. Nie można anulować księgowania';es_ES = 'Turno del registro está cerrado. No se puede cancelar el envío';es_CO = 'Turno del registro está cerrado. No se puede cancelar el envío';tr = 'Kasa vardiyası kapalı. Onay iptal edilemiyor';it = 'Il turno di cassa è chiuso. Non è possibile cancellare la pubblicazione';de = 'Kassenschicht geschlossen. Die Buchung kann nicht storniert werden'");
		
		DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				,
				Cancel
			);
		
		Return;
		
	EndIf;
	
	DocumentSubtotal = 0;	
	For Each InventoryRow In Inventory Do
		DocumentSubtotal = DocumentSubtotal + InventoryRow.Price * InventoryRow.Quantity  * (1 - InventoryRow.DiscountMarkupPercent / 100);
	EndDo;
		
	DocumentAmount = Inventory.Total("Total");
	DocumentTax = Inventory.Total("VATAmount");
	
	If WriteMode = DocumentWriteMode.UndoPosting Then
		SalesSlipNumber = 0;
		Status = Undefined;
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("IsNew", IsNew());
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillOwnershipTable(ThisObject, WriteMode, Cancel);
	
EndProcedure

// Procedure - event handler Posting().
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	AddAttributesToAdditionalPropertiesForPosting(AdditionalProperties);
	
	// Document data initialization.
	Documents.SalesSlip.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);

	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCashAssetsInCashRegisters(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// DiscountCards
	DriveServer.ReflectSalesByDiscountCard(AdditionalProperties, RegisterRecords, Cancel);
	// AutomaticDiscounts
	DriveServer.FlipAutomaticDiscountsApplied(AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.SalesSlip.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.SalesSlip.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, AdditionalProperties.WriteMode, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

#EndRegion

#EndIf
