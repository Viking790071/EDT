#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// The procedure of filling in the document on the basis of cash payment voucher.
//
// Parameters:
// BasisDocument - DocumentRef.ApplicationForCashExpense - Application
// for payment FillingData - Structure - Document filling data
//	
Procedure FillBySalesSlip(Val BasisDocument, FillingData)
	
	// Fill document header data.
	QueryText = 
	"SELECT ALLOWED
	|	SalesSlip.DocumentCurrency AS DocumentCurrency,
	|	SalesSlip.Ref AS SalesSlip,
	|	SalesSlip.PriceKind AS PriceKind,
	|	SalesSlip.DiscountMarkupKind AS DiscountMarkupKind,
	|	SalesSlip.Company AS Company,
	|	SalesSlip.CompanyVATNumber AS CompanyVATNumber,
	|	SalesSlip.VATTaxation AS VATTaxation,
	|	SalesSlip.CashCR AS CashCR,
	|	SalesSlip.CashCRSession AS CashCRSession,
	|	SalesSlip.StructuralUnit AS StructuralUnit,
	|	SalesSlip.Department AS Department,
	|	SalesSlip.Responsible AS Responsible,
	|	SalesSlip.DocumentAmount AS DocumentAmount,
	|	SalesSlip.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesSlip.IncludeVATInPrice AS IncludeVATInPrice,
	|	SalesSlip.POSTerminal AS POSTerminal,
	|	SalesSlip.DiscountCard AS DiscountCard,
	|	SalesSlip.DiscountPercentByDiscountCard AS DiscountPercentByDiscountCard,
	|	SalesSlip.Inventory.(
	|		Products AS Products,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		Quantity AS Quantity,
	|		MeasurementUnit AS MeasurementUnit,
	|		Price AS Price,
	|		DiscountMarkupPercent AS DiscountMarkupPercent,
	|		Amount AS Amount,
	|		VATRate AS VATRate,
	|		VATAmount AS VATAmount,
	|		Total AS Total,
	|		AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|		AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|		ConnectionKey AS ConnectionKey,
	|		SerialNumbers AS SerialNumbers,
	|		CASE
	|			WHEN &UseDefaultTypeOfAccounting
	|				THEN RevenueGLAccount
	|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		END AS RevenueGLAccount,
	|		CASE
	|			WHEN &UseDefaultTypeOfAccounting
	|				THEN VATOutputGLAccount
	|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		END AS VATOutputGLAccount
	|	) AS Inventory,
	|	SalesSlip.PaymentWithPaymentCards.(
	|		ChargeCardKind AS ChargeCardKind,
	|		ChargeCardNo AS ChargeCardNo,
	|		Amount AS Amount,
	|		RefNo AS RefNo,
	|		ETReceiptNo AS ETReceiptNo
	|	) AS PaymentWithPaymentCards,
	|	SalesSlip.SalesSlipNumber AS SalesSlipNumber,
	|	SalesSlip.Posted AS Posted,
	|	SalesSlip.DiscountsMarkups.(
	|		Ref AS Ref,
	|		LineNumber AS LineNumber,
	|		ConnectionKey AS ConnectionKey,
	|		DiscountMarkup AS DiscountMarkup,
	|		Amount AS Amount
	|	) AS DiscountsMarkups,
	|	SalesSlip.DiscountsAreCalculated AS DiscountsAreCalculated
	|FROM
	|	Document.SalesSlip AS SalesSlip
	|WHERE
	|	SalesSlip.Ref = &Ref";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Selection = Query.Execute().Select();
	Selection.Next();
	FillPropertyValues(ThisObject, Selection, ,"SalesSlipNumber, Posted");
	
	ErrorText = "";
	
	If Not Documents.ShiftClosure.SessionIsOpen(Selection.CashCRSession, CurrentSessionDate(), ErrorText) Then
		
		ErrorText = ErrorText + NStr("en = 'Please close the shift and register the product return with a supplier invoice.'; ru = 'Закройте смену и оформите возврат с помощью инвойса поставщика.';pl = 'Zamknij zmianę i zarejestruj zwrot produktu za pomocą faktury zakupu.';es_ES = 'Por favor, elija el turno y registre la devolución del producto con una factura del proveedor.';es_CO = 'Por favor, elija el turno y registre la devolución del producto con una factura del proveedor.';tr = 'Lütfen, vardiyayı kapatın ve ürün iadesini bir satın alma faturasıyla kaydedin.';it = 'Si prega di chiudere il turno e registrare il prodotto restituito con una fattura fornitore.';de = 'Bitte schließen Sie die Verschiebung und registrieren Sie die Produktrückgabe mit einer Lieferantenrechnung.'");
		
		Raise ErrorText;
		
	EndIf;
	
	If Not Selection.Posted Then
		
		ErrorText = NStr("en = 'Please select a posted sales slip.'; ru = 'Кассовый чек не проведен. Ввод на основании невозможен';pl = 'Wybierz wysłany paragon kasowy.';es_ES = 'Por favor, selecciona un comprobante de venta enviado.';es_CO = 'Por favor, selecciona un comprobante de venta enviado.';tr = 'Lütfen, kaydedilmiş bir satış fişi seçin.';it = 'Si prega di selezionare una ricevuta di pagamento pubblicata.';de = 'Bitte wählen Sie einen veröffentlichten Kaufbeleg.'");
		
		Raise ErrorText;
		
	EndIf;
	
	If Not ValueIsFilled(Selection.SalesSlipNumber) Then
		
		ErrorText = NStr("en = 'Please select an issued sales slip.'; ru = 'Кассовый чек не пробит. Ввод на основании невозможен';pl = 'Wybierz wystawiony paragon kasowy.';es_ES = 'Por favor, seleccione un comprobante de venta emitido.';es_CO = 'Por favor, seleccione un comprobante de venta emitido.';tr = 'Lütfen, düzenlenmiş bir satış fişi seçin.';it = 'Si prega di selezionare una ricevuta di pagamento emessa.';de = 'Bitte wählen Sie einen ausgestellten Kaufbeleg.'");
	
		Raise ErrorText;
		
	EndIf;
	
	Inventory.Load(Selection.Inventory.Unload());
	PaymentWithPaymentCards.Load(Selection.PaymentWithPaymentCards.Unload());
	
	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData);
	
	// AutomaticDiscounts
	If GetFunctionalOption("UseAutomaticDiscounts") Then
		DiscountsMarkups.Load(Selection.DiscountsMarkups.Unload());
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

#EndRegion

#Region EventsHandlers

// Procedure - event handler "On copy".
//
Procedure OnCopy(CopiedObject)
	
	Raise NStr("en = 'Please generate a product return from a sales slip.'; ru = 'Кассовые чеки на возврат должны вводится на основании кассовых чеков.';pl = 'Wygeneruj zwrot produktu z paragonu kasowego.';es_ES = 'Por favor, genere una devolución del producto del comprobante de venta.';es_CO = 'Por favor, genere una devolución del producto del comprobante de venta.';tr = 'Lütfen, satış fişinden ürün iadesi oluşturun.';it = 'Si prega di generare la restituzione di un articolo da uno scontrino.';de = 'Bitte generieren Sie eine Produktretoure aus einem Kassenbeleg.'");
	
EndProcedure

// Procedure - event handler "FillingProcessor".
//
Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	DataTypeFill = TypeOf(FillingData);
	
	If TypeOf(FillingData) = Type("DocumentRef.SalesSlip") Then
		
		FillBySalesSlip(FillingData, FillingData);
		
	Else
		
		Raise NStr("en = 'Please generate a product return from a sales slip.'; ru = 'Кассовые чеки на возврат должны вводится на основании кассовых чеков.';pl = 'Wygeneruj zwrot produktu z paragonu kasowego.';es_ES = 'Por favor, genere una devolución del producto del comprobante de venta.';es_CO = 'Por favor, genere una devolución del producto del comprobante de venta.';tr = 'Lütfen, satış fişinden ürün iadesi oluşturun.';it = 'Si prega di generare la restituzione di un articolo da uno scontrino.';de = 'Bitte generieren Sie eine Produktretoure aus einem Kassenbeleg.'");
		
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
EndProcedure

// Procedure - event handler "Filling check processor".
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	ProductReturn.Ref
	|FROM
	|	Document.ProductReturn AS ProductReturn
	|WHERE
	|	ProductReturn.Ref <> &Ref
	|	AND ProductReturn.Posted
	|	AND ProductReturn.SalesSlip = &SalesSlip
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesSlip.CashCRSession AS CashCRSession,
	|	SalesSlip.Date AS Date,
	|	SalesSlip.Posted AS Posted,
	|	SalesSlip.SalesSlipNumber AS SalesSlipNumber
	|FROM
	|	Document.SalesSlip AS SalesSlip
	|WHERE
	|	SalesSlip.Ref = &SalesSlip";
	
	Query.SetParameter("SalesSlip", SalesSlip);
	Query.SetParameter("Ref", Ref);
	
	Result = Query.ExecuteBatch();
	Selection = Result[0].Select();
	
	While Selection.Next() Do
		
		ErrorText = NStr("en = 'Product return has already been entered for this receipt'; ru = 'Для данного чека уже введен чек на возврат';pl = 'Zwrot produktu został już wprowadzony dla tego pokwitowania';es_ES = 'Devolución del producto ya se ha introducido para este recibo';es_CO = 'Devolución del producto ya se ha introducido para este recibo';tr = 'Bu makbuz için ürün iade fişi zaten girilmiş';it = 'Una ricevuta di rimborso è già stata inserita per questa scontrino';de = 'Die Produktrückgabe wurde für diesen Beleg bereits erfasst.'");
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			ErrorText,
			Undefined,
			Undefined,
			"SalesSlip",
			Cancel
		); 
		
	EndDo;
	
	Selection = Result[1].Select();
	
	While Selection.Next() Do
		
		If BegOfDay(Selection.Date) <> BegOfDay(Date) Then
			
			ErrorText = NStr("en = 'Product return date should correspond to sales receipt date'; ru = 'Дата чека на возврат должна соответствовать дате чека продажи';pl = 'Data zwrotu produktu powinna odpowiadać dacie otrzymania sprzedaży';es_ES = 'Fecha de la devolución del producto tiene que corresponder a la fecha del recibo de ventas';es_CO = 'Fecha de la devolución del producto tiene que corresponder a la fecha del recibo de ventas';tr = 'Ürün iade fişi tarihi satış fişi tarihine karşılık gelmelidir';it = 'La data dello scontrino di rimborso dovrebbe corrispondere alla data della vendita';de = 'Das Rückgabedatum des Produkts sollte dem Eingangsdatum des Verkaufs entsprechen.'");
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				Undefined,
				Undefined,
				"Date",
				Cancel
			); 

		EndIf;
		
		If CashCRSession <> Selection.CashCRSession Then
			
			ErrorText = NStr("en = 'Product return register shift should correspond to sale receipt register shift'; ru = 'Кассовая смена чека на возврат должна соответствовать кассовой смене чека продажи';pl = 'Zmiana rejestru zwrotu produktu powinna odpowiadać zmianie rejestru odbioru sprzedaży';es_ES = 'Turno del registro de la devolución del producto tiene que corresponder al turno del registro del recibo de la venta';es_CO = 'Turno del registro de la devolución del producto tiene que corresponder al turno del registro del recibo de la venta';tr = 'Ürün iade fişin kasa vardiyası satış fişlerinin kasa vardiyasına karşılık gelmelidir';it = 'Il turno di cassa per la restituzione dell''articolo deve corrispendore al turno di cassa della ricevuta di vendita';de = 'Die Verschiebung des Produktrückgaberegisters sollte der Schicht des Verkaufsbelegsregisters entsprechen.'");
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				Undefined,
				Undefined,
				"CashCRSession",
				Cancel
			); 

		EndIf;
		
		If Not Selection.Posted Then
			
			ErrorText = NStr("en = 'Cash receipt is not posted'; ru = 'Кассовый чек не проведен';pl = 'Paragon nie został zaksięgowany';es_ES = 'Recibo de efectivo no se ha enviado';es_CO = 'Recibo de efectivo no se ha enviado';tr = 'Nakit tahsilat fişi kaydedilmedi';it = 'Entrata di cassa non viene pubblicata';de = 'Der Zahlungseingang wird nicht gebucht'");
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				Undefined,
				Undefined,
				"SalesSlip",
				Cancel
			); 

		EndIf;
		
		If Not ValueIsFilled(Selection.SalesSlipNumber) Then
			
			ErrorText = NStr("en = 'Cash receipt of a sale is not issued'; ru = 'Кассовый чек продажи не пробит';pl = 'Paragon sprzedaży nie został wystawiony';es_ES = 'Recibo de efectivo de una venta no se ha emitido';es_CO = 'Recibo de efectivo de una venta no se ha emitido';tr = 'Bir satışın Nakit tahsilat fişi verilmez';it = 'L''Entrata di cassa di una vendita non viene rilasciato';de = 'Der Zahlungseingang eines Verkaufs wird nicht ausgestellt'");
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				Undefined,
				Undefined,
				"SalesSlip",
				Cancel
			);
			
		EndIf;
		
		ErrorText = NStr("en = 'Register shift is not opened'; ru = 'Кассовая смена не открыта';pl = 'Kasowa zmiana nie została otwarta';es_ES = 'Turno del registro no está abierto';es_CO = 'Turno del registro no está abierto';tr = 'Kasa vardiyası açılmadı';it = 'Il turno di cassa non è aperto';de = 'Kassenschicht ist nicht geöffnet'");
		If Not Documents.ShiftClosure.SessionIsOpen(CashCRSession, Date, ErrorText) Then
			
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				Undefined,
				Undefined,
				"CashCRSession",
				Cancel
			);

		EndIf;
		
	EndDo;
	
	If PaymentWithPaymentCards.Count() > 0 AND Not ValueIsFilled(POSTerminal) Then
		
		ErrorText = NStr("en = 'The ""POS terminal"" field is not filled in'; ru = 'Поле ""Эквайринговый терминал"" не заполнено';pl = 'Nie wypełniono pola ""terminal POS""';es_ES = 'El campo ""Terminal TPV"" no está rellenado';es_CO = 'El campo ""Terminal TPV"" no está rellenado';tr = '""POS terminali"" alanı doldurulmadı';it = 'Il campo ""Terminale POS"" non è compilato';de = 'Das Feld ""POS-Terminal"" ist nicht ausgefüllt'");
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			ErrorText,
			Undefined,
			Undefined,
			"POSTerminal",
			Cancel
		);
		
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
EndProcedure

// Procedure - event handler "BeforeWrite".
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(SalesSlipNumber)
	   AND WriteMode = DocumentWriteMode.UndoPosting
	   AND Not CashCR.UseWithoutEquipmentConnection Then
		
		Cancel = True;
		
		ErrorText = NStr("en = 'Cash receipt for return is issued on the fiscal data recorder. Cannot cancel posting'; ru = 'Кассовый чек на возврат пробит на фискальном регистраторе. Отмена проведения невозможна';pl = 'Paragon na zwrot został wydrukowany przez rejestrator fiskalny. Nie można anulować księgowania';es_ES = 'Recibo de efectivo para la devolución está emitido en el registro de datos fiscales. No se puede cancelar el envío';es_CO = 'Recibo de efectivo para la devolución está emitido en el registro de datos fiscales. No se puede cancelar el envío';tr = 'Mali veri kayıt cihazında iade için Nakit tahsilat fişi verildi. Onay iptal edilemiyor';it = 'L''Entrata di cassa è stata emessa dal registratore di cassa. Impossibile l''annullamento';de = 'Der Zahlungseingang für die Reklamation wird auf dem Fiskal-Datenbuchungsdokument ausgegeben. Die Buchung kann nicht storniert werden'");
		
		CommonClientServer.MessageToUser(
			ErrorText,
			ThisObject);
			
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
	
	DocumentAmount = Inventory.Total("Total");
	DocumentTax = Inventory.Total("VATAmount");   
	DocumentSubtotal = DocumentAmount - DocumentTax;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("IsNew",    IsNew());
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillOwnershipTable(ThisObject, WriteMode, Cancel);
	
EndProcedure

// Procedure - event handler "Posting".
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Document data initialization.
	Documents.ProductReturn.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCashAssetsInCashRegisters(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	
	// DiscountCards
	DriveServer.ReflectSalesByDiscountCard(AdditionalProperties, RegisterRecords, Cancel);
	
	// AutomaticDiscounts
	DriveServer.FlipAutomaticDiscountsApplied(AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ProductReturn.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

// Procedure - event handler "UndoPosting".
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ProductReturn.RunControl(Ref, AdditionalProperties, Cancel, True);
	
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