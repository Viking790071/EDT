
#Region Public

// Checks for correctness of the early payments discounts
//  Parameters:
//   TabularSectionEPD - FormDataCollection - tabular section with EPD from Contract,
//                                            Sales invoice or Supplier invoice
//  Returns:
//   boolean - EPD correct or not
//
Function CheckEarlyPaymentDiscounts(TabularSectionEPD, ProvideEPD) Export
	
	Result = True;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EarlyPaymentDiscounts.Period AS Period,
	|	EarlyPaymentDiscounts.Discount AS Discount
	|INTO TempEarlyPaymentDiscounts
	|FROM
	|	&EarlyPaymentDiscounts AS EarlyPaymentDiscounts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Table.Period AS Period,
	|	Table.Discount AS Discount
	|FROM
	|	TempEarlyPaymentDiscounts AS Table
	|
	|ORDER BY
	|	Period";
	
	Query.SetParameter("EarlyPaymentDiscounts", TabularSectionEPD.Unload());
	
	DataSelection = Query.Execute().Select();
	
	PreviousDiscount = 100;
	PreviousPeriod = 0;
	
	If TabularSectionEPD.Count() > 0 AND NOT ValueIsFilled(ProvideEPD) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Select a EPD provision option'; ru = 'Укажите вариант предоставления скидки за досрочную оплату';pl = 'Wybierz opcję udzielenia skonta';es_ES = 'Seleccione la opción de la provisión de EPD';es_CO = 'Seleccione la opción de la provisión de EPD';tr = 'Bir EPD sağlama seçeneği seçin';it = 'Selezionare una opzione di provisione EPD';de = 'Auswählen einer Skonto-Bereitstellungsoption'"));
		
		Result = False;
		
	EndIf;
	
	While DataSelection.Next() Do
		
		If DataSelection.Discount = 0 OR DataSelection.Discount >= 100 Then
			
			TextMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The early payment discount can''t be %1%'; ru = 'Скидка за досрочную оплату не может быть %1%';pl = 'Skonto nie może być %1%';es_ES = 'El descuento por pronto pago no puede ser %1%';es_CO = 'El descuento por pronto pago no puede ser %1%';tr = 'Erken ödeme indirimi %%1 olamaz';it = 'Lo sconto per pagamento anticipato non può essere %1%';de = 'Der Skonto kann nicht sein %1%'"),
				DataSelection.Discount);
			
			CommonClientServer.MessageToUser(TextMessage);
			
			Result = False;
			
		ElsIf PreviousDiscount <= DataSelection.Discount Then
			
			TextError = NStr("en = 'The early payment discount %1% with the period %2 days should be less then the discount %3% with the period %4 days'; ru = 'Скидка за досрочную оплату %1% за период %2 дней должна быть меньше скидки %3% за период %4 дней';pl = 'Skonto %1% z datą %2 dni powinno być niższe, niż %3% rabat z okresu %4 dni';es_ES = 'El descuento por pronto pago %1% con el período de %2 días debe ser menor que el descuento %3% con el período de %4 días';es_CO = 'El descuento por pronto pago %1% con el período de %2 días debe ser menor que el descuento %3% con el período de %4 días';tr = '%2 ödeme süresi ile %1% erken ödeme indirimi, %4 gün süre ile %3% indirimden daha düşük olmalıdır';it = 'Lo sconto per pagamento anticipato %1% nel periodo di %2 giorni deve essere inferiore allo sconto %3% con il periodo di %4 giorni';de = 'Der Skonto %1% mit dem Zeitraum%2 Tage sollte kleiner sein als der Skonto %3% mit dem Zeitraum %4 Tage'");
			
			TextMessage = StringFunctionsClientServer.SubstituteParametersToString(
				TextError,
				DataSelection.Discount,
				DataSelection.Period,
				PreviousDiscount,
				PreviousPeriod);
			
			CommonClientServer.MessageToUser(TextMessage);
			
			Result = False;
			
		EndIf;
		
		PreviousDiscount = DataSelection.Discount;
		PreviousPeriod = DataSelection.Period;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Sets hyperlink label for credit note
//
Procedure SetTextAboutCreditNote(DocumentForm, BasisDocument) Export
	
	CreditNoteFound = GetSubordinateCreditNote(BasisDocument);
	
	If ValueIsFilled(CreditNoteFound) Then
		DocumentForm.CreditNoteText = EarlyPaymentDiscountsClientServer.CreditNotePresentation(CreditNoteFound.Date, CreditNoteFound.Number);
	Else
		DocumentForm.CreditNoteText = NStr("en = 'To record EPD, create a Credit note'; ru = 'Для записи скидки за досрочную оплату создайте кредитовое авизо';pl = 'Aby zapisać skonto, utwórz Notę kredytową';es_ES = 'Para grabar un DPP, cree una Nota de crédito';es_CO = 'Para grabar un DPP, cree una Nota de crédito';tr = 'Erken ödeme indirimi kaydetmek için Alacak dekontu oluşturun';it = 'Per registrare lo Sconto per Pagamento Anticipato, creare una Nota di credito';de = 'Um Skonto einzutragen, erstellen Sie eine Gutschrift'");
	EndIf;
	
EndProcedure

// Returns reference to the subordinate credit note
//
Function GetSubordinateCreditNote(BasisDocument) Export
	
	If NOT ValueIsFilled(BasisDocument) Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	CreditNote.Ref AS Ref
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.BasisDocument = &BasisDocument
	|	AND NOT CreditNote.DeletionMark";
	
	Query.SetParameter("BasisDocument", BasisDocument);
	
	Result = Undefined;
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Result = Selection.Ref;
	EndIf;
	
	Return Result;
	
EndFunction

// Gets errors when filling in a credit note
//
Function CheckBeforeCreditNoteFilling(Documents, FindCreditNote = True) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	CreditNote.BasisDocument AS Recorder,
	|	TRUE AS ThereAreCreditNote,
	|	FALSE AS IncorrectOperation
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.BasisDocument IN(&Documents)
	|	AND NOT CreditNote.DeletionMark
	|	AND &FindCreditNote
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	CashReceipt.Ref,
	|	FALSE,
	|	CASE
	|		WHEN CashReceipt.OperationKind <> VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|			THEN TRUE
	|		ELSE FALSE
	|	END
	|FROM
	|	Document.CashReceipt AS CashReceipt
	|WHERE
	|	CashReceipt.Ref IN(&Documents)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	PaymentReceipt.Ref,
	|	FALSE,
	|	CASE
	|		WHEN PaymentReceipt.OperationKind <> VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|			THEN TRUE
	|		ELSE FALSE
	|	END
	|FROM
	|	Document.PaymentReceipt AS PaymentReceipt
	|WHERE
	|	PaymentReceipt.Ref IN(&Documents)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	OnlineReceipt.Ref,
	|	FALSE,
	|	CASE
	|		WHEN OnlineReceipt.OperationKind <> VALUE(Enum.OperationTypesOnlineReceipt.FromCustomer)
	|			THEN TRUE
	|		ELSE FALSE
	|	END
	|FROM
	|	Document.OnlineReceipt AS OnlineReceipt
	|WHERE
	|	OnlineReceipt.Ref IN(&Documents)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	CashReceiptPaymentDetails.Contract AS Contract
	|FROM
	|	Document.CashReceipt.PaymentDetails AS CashReceiptPaymentDetails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON CashReceiptPaymentDetails.Document = SalesInvoice.Ref
	|WHERE
	|	CashReceiptPaymentDetails.SettlementsEPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|	AND CashReceiptPaymentDetails.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|	AND CashReceiptPaymentDetails.Ref IN(&Documents)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	PaymentReceiptPaymentDetails.Contract
	|FROM
	|	Document.PaymentReceipt.PaymentDetails AS PaymentReceiptPaymentDetails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON PaymentReceiptPaymentDetails.Document = SalesInvoice.Ref
	|WHERE
	|	PaymentReceiptPaymentDetails.SettlementsEPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|	AND PaymentReceiptPaymentDetails.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|	AND PaymentReceiptPaymentDetails.Ref IN(&Documents)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	OnlineReceiptPaymentDetails.Contract
	|FROM
	|	Document.OnlineReceipt.PaymentDetails AS OnlineReceiptPaymentDetails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON OnlineReceiptPaymentDetails.Document = SalesInvoice.Ref
	|WHERE
	|	OnlineReceiptPaymentDetails.SettlementsEPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|	AND OnlineReceiptPaymentDetails.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|	AND OnlineReceiptPaymentDetails.Ref IN(&Documents)";
	
	Query.SetParameter("Documents", Documents);
	Query.SetParameter("FindCreditNote", FindCreditNote);
	
	Cancel = False;
	Errors = Undefined;
	
	ResultArray = Query.ExecuteBatch();
	
	Selection = ResultArray[0].Select();
	
	TextCreditNoteError = NStr("en = 'There is already a credit note based on %1.'; ru = 'На основании %1 уже создано кредитовое авизо.';pl = 'Istnieje już nota kredytowa na podstawie %1.';es_ES = 'Ya hay una nota de crédito basada en %1.';es_CO = 'Ya hay una nota del haber basada en %1.';tr = '%1 bazlı bir alacak dekontu zaten var.';it = 'Esiste già una Nota di Credito basata su %1.';de = 'Es gibt bereits eine Gutschrift basierend auf %1.'");
	
	IncorrectOperation = NStr("en = 'The Credit note is needed only to provide an early payment discount to a customer.'; ru = 'Кредитовое авизо используется только для предоставления клиенту скидки за досрочную оплату.';pl = 'Nota kredytowa jest potrzebna tylko w celu zapewnienia skonto na rzecz nabywcy.';es_ES = 'La nota de crédito es necesaria solo para proveer el descuento por pronto pago al cliente.';es_CO = 'La nota de crédito es necesaria solo para proveer el descuento por pronto pago al cliente.';tr = 'Alacak dekontu sadece müşteriye erken ödeme indirimi sağlamak için gereklidir.';it = 'La nota di credito serve solo a fornire un pagamento anticipato a un cliente.';de = 'Die Gutschrift wird nur benötigt, um einem Kunden einen Skonto zu gewähren.'");
	
	While Selection.Next() Do
		
		If Selection.ThereAreCreditNote Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(TextCreditNoteError, Selection.Recorder);
			CommonClientServer.AddUserError(Errors, , ErrorText, Undefined);
		EndIf;
		
		If Selection.IncorrectOperation Then
			CommonClientServer.AddUserError(Errors, , IncorrectOperation, Undefined);
		EndIf;
		
	EndDo;
	
	SelectionTable = ResultArray[1].Unload();
	
	TextEPDError = NStr("en = 'There are no rows with early payment discount in the Payment allocation tab.'; ru = 'В расшифровке платежа отсутствуют строки со скидкой за досрочную оплату.';pl = 'Na karcie Alokacja płatności nie ma wierszy które zawierają skonto.';es_ES = 'No hay filas con el descuento por pronto pago en la pestaña de la Asignación de pagos.';es_CO = 'No hay filas con el descuento por pronto pago en la pestaña de la Asignación de pagos.';tr = 'Ödeme tahsisi sekmesinde erken ödeme indirimi olan herhangi bir satır yoktur.';it = 'Non ci sono righe con sconti per pagamento anticipato nella sezione assegnazione Pagamento.';de = 'Auf der Registerkarte Zahlungszuordnung sind keine Zeilen mit Skonto.'");
	
	If SelectionTable.Count() = 0 Then
		
		CommonClientServer.AddUserError(Errors, , TextEPDError, Undefined);
		
	EndIf;
	
	TextContractError = NStr("en = 'To generate Credit note, the payment allocation rows should contain the same contract.'; ru = 'Чтобы создать кредитовое авизо, необходимо, чтобы договор в строках расшифровки платежа совпадал.';pl = 'Aby wygenerować notę kredytową, wiersze Alokacji płatności powinny zawierać ten sam kontrakt.';es_ES = 'Para generar la Nota de crédito, las filas de la Asignación del pago contienen el mismo contrato.';es_CO = 'Para generar la Nota del haber, las filas de la Asignación del pago contienen el mismo contrato.';tr = 'Alacak dekontu oluşturmak için, ödeme tahsis satırları aynı sözleşmeyi içermelidir.';it = 'Per generare una Nota di Credito, la riga di assegnazione pagamento dovrebbe contenere lo stesso contratto.';de = 'Um eine Gutschrift zu generieren, sollten die Zahlungszuordnungszeilen den gleichen Vertrag enthalten.'");
	
	If SelectionTable.Count() > 1 Then
		
		CommonClientServer.AddUserError(Errors, , TextContractError, Undefined);
		
	EndIf;
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
	Return Cancel;
	
EndFunction

// Sets hyperlink label for debit note
//
Procedure SetTextAboutDebitNote(DocumentForm, BasisDocument) Export
	
	DebitNoteFound = GetSubordinateDebitNote(BasisDocument);
	
	If ValueIsFilled(DebitNoteFound) Then
		DocumentForm.DebitNoteText = EarlyPaymentDiscountsClientServer.DebitNotePresentation(DebitNoteFound.Date, DebitNoteFound.Number);
	Else
		DocumentForm.DebitNoteText = NStr("en = 'To record EPD, create a Debit note'; ru = 'Для записи скидки за досрочную оплату создайте дебетовое авизо';pl = 'Aby zapisać skonto, utwórz Notę debetową';es_ES = 'Para grabar un DPP, cree una Nota de débito';es_CO = 'Para grabar un DPP, cree una Nota de débito';tr = 'Erken ödeme indirimi kaydetmek için Borç dekontu oluşturun';it = 'Per registrare lo Sconto per Pagamento Anticipato, creare una Nota di debito';de = 'Um Skonto einzutragen, erstellen Sie eine Lastschrift'");
	EndIf;
	
EndProcedure

// Returns reference to the subordinate credit note
//
Function GetSubordinateDebitNote(BasisDocument) Export
	
	If NOT ValueIsFilled(BasisDocument) Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	DebitNote.Ref AS Ref
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.BasisDocument = &BasisDocument
	|	AND NOT DebitNote.DeletionMark";
	
	Query.SetParameter("BasisDocument", BasisDocument);
	
	Result = Undefined;
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Result = Selection.Ref;
	EndIf;
	
	Return Result;
	
EndFunction

// Gets errors when filling in a credit note
//
Function CheckBeforeDebitNoteFilling(Documents, FindDebitNote = True) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	DebitNote.BasisDocument AS Recorder,
	|	TRUE AS ThereAreDebitNote,
	|	FALSE AS IncorrectOperation
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.BasisDocument IN(&Documents)
	|	AND NOT DebitNote.DeletionMark
	|	AND &FindDebitNote
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	CashVoucher.Ref,
	|	FALSE,
	|	CASE
	|		WHEN CashVoucher.OperationKind <> VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|			THEN TRUE
	|		ELSE FALSE
	|	END
	|FROM
	|	Document.CashVoucher AS CashVoucher
	|WHERE
	|	CashVoucher.Ref IN(&Documents)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	PaymentExpense.Ref,
	|	FALSE,
	|	CASE
	|		WHEN PaymentExpense.OperationKind <> VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|			THEN TRUE
	|		ELSE FALSE
	|	END
	|FROM
	|	Document.PaymentExpense AS PaymentExpense
	|WHERE
	|	PaymentExpense.Ref IN(&Documents)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	CashVoucherPaymentDetails.Contract AS Contract
	|FROM
	|	Document.CashVoucher.PaymentDetails AS CashVoucherPaymentDetails
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON CashVoucherPaymentDetails.Document = SupplierInvoice.Ref
	|WHERE
	|	CashVoucherPaymentDetails.SettlementsEPDAmount > 0
	|	AND (SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|	AND CashVoucherPaymentDetails.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|	AND CashVoucherPaymentDetails.Ref IN(&Documents)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	PaymentExpensePaymentDetails.Contract
	|FROM
	|	Document.PaymentExpense.PaymentDetails AS PaymentExpensePaymentDetails
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON PaymentExpensePaymentDetails.Document = SupplierInvoice.Ref
	|WHERE
	|	PaymentExpensePaymentDetails.SettlementsEPDAmount > 0
	|	AND (SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|	AND PaymentExpensePaymentDetails.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|	AND PaymentExpensePaymentDetails.Ref IN(&Documents)";
	
	Query.SetParameter("Documents", Documents);
	Query.SetParameter("FindDebitNote", FindDebitNote);
	
	Cancel = False;
	Errors = Undefined;
	
	ResultArray = Query.ExecuteBatch();
	
	Selection = ResultArray[0].Select();
	
	TextDebitNoteError = NStr("en = 'There is already a debit note based on %1.'; ru = 'На основании %1 уже создано дебетовое авизо.';pl = 'Istnieje już nota debetowa na podstawie %1.';es_ES = 'Ya hay una nota del debe basada en %1.';es_CO = 'Ya hay una nota del debe basada en %1.';tr = '%1 bazlı bir borç dekontu zaten var.';it = 'Già esiste una Nota di Debito basata su %1.';de = 'Es gibt bereits eine Lastschrift basierend auf %1.'");
	
	IncorrectOperation = NStr("en = 'The Debit note is needed only to obtain an early payment discount from a supplier.'; ru = 'Дебетовое авизо используется только для получения скидки за досрочную оплату от поставщика.';pl = 'Nota debetowa jest potrzebna tylko do uzyskania skonto od dostawcy.';es_ES = 'La nota de debe es necesaria solo para obtener el descuento por pronto pago del proveedor.';es_CO = 'La nota de debe es necesaria solo para obtener el descuento por pronto pago del proveedor.';tr = 'Borç dekontu sadece tedarikçiden erken ödeme indirimi almak için gereklidir.';it = 'La nota di Debito è necessaria solo al fine di ottenere un pagamento anticipato da un fornitore.';de = 'Die Lastschrift wird nur benötigt, um von einem Lieferanten einen Skonto zu erhalten.'");
	
	While Selection.Next() Do
		
		If Selection.ThereAreDebitNote Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(TextDebitNoteError, Selection.Recorder);
			CommonClientServer.AddUserError(Errors, , ErrorText, Undefined);
		EndIf;
		
		If Selection.IncorrectOperation Then
			CommonClientServer.AddUserError(Errors, , IncorrectOperation, Undefined);
		EndIf;
		
	EndDo;
	
	SelectionTable = ResultArray[1].Unload();
	
	TextEPDError = NStr("en = 'There are no rows with early payment discount in the Payment allocation tab.'; ru = 'В расшифровке платежа отсутствуют строки со скидкой за досрочную оплату.';pl = 'Na karcie Alokacja płatności nie ma wierszy które zawierają skonto.';es_ES = 'No hay filas con el descuento por pronto pago en la pestaña de la Asignación de pagos.';es_CO = 'No hay filas con el descuento por pronto pago en la pestaña de la Asignación de pagos.';tr = 'Ödeme tahsisi sekmesinde erken ödeme indirimi olan herhangi bir satır yoktur.';it = 'Non ci sono righe con sconti per pagamento anticipato nella sezione assegnazione Pagamento.';de = 'Auf der Registerkarte Zahlungszuordnung sind keine Zeilen mit Skonto.'");
	
	If SelectionTable.Count() = 0 Then
		
		CommonClientServer.AddUserError(Errors, , TextEPDError, Undefined);
		
	EndIf;
	
	TextContractError = NStr("en = 'To generate Debit note, the payment allocation rows should contain the same contract.'; ru = 'Чтобы создать дебетовое авизо, необходимо, чтобы договор в строках расшифровки платежа совпадал.';pl = 'Aby wygenerować Notę debetową, wiersze Alokacji płatności powinny zawierać ten sam kontrakt.';es_ES = 'Para generar la Nota del debe, las filas de la Asignación del pago contienen el mismo contrato.';es_CO = 'Para generar la Nota del debe, las filas de la Asignación del pago contienen el mismo contrato.';tr = 'Borç dekontu oluşturmak için, ödeme tahsis satırları aynı sözleşmeyi içermelidir.';it = 'Per generare una Nota di Debito, le righe di allocazione pagamento devono contenere lo stesso contratto.';de = 'Um eine Lastschrift zu generieren, sollten die Zahlungszuordnungszeilen den gleichen Vertrag enthalten.'");
	
	If SelectionTable.Count() > 1 Then
		
		CommonClientServer.AddUserError(Errors, , TextContractError, Undefined);
		
	EndIf;
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
	Return Cancel;
	
EndFunction

// Checks the ability to enter Debit note on EPD
//
Function AvailableDebitNoteEPD(Documents) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	SupplierInvoice.Ref AS Ref
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	(SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|	AND SupplierInvoice.Ref IN(&Documents)";
	
	Query.SetParameter("Documents", Documents);
	
	QueryResult = Query.Execute();
	
	Return NOT QueryResult.IsEmpty();
	
EndFunction

// Checks the ability to enter Credit note on EPD
//
Function AvailableCreditNoteEPD(Documents) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	SalesInvoice.Ref AS Ref
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	(SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|	AND SalesInvoice.Ref IN(&Documents)";
	
	Query.SetParameter("Documents", Documents);
	
	QueryResult = Query.Execute();
	
	Return NOT QueryResult.IsEmpty();
	
EndFunction

Procedure FillEarlyPaymentDiscounts(Object, ContractType) Export
	
	Var Result;
	
	Object.EarlyPaymentDiscounts.Clear();
	
	Contract = Object.Contract;
	If Contract.ContractKind = ContractType Then
		
		If GetEarlyPaymentDiscounts(Object, Result) Then
			
			TotalAmount = Object.Inventory.Total("Total") 
				+ ?(ContractType = Enums.ContractType.WithCustomer, Object.SalesTax.Total("Amount"), 0)
				+ ?(ContractType = Enums.ContractType.WithVendor, Object.Expenses.Total("Total"), 0);
				
			ResultTable = Result.EPD.Unload();
			For each ResultRow In ResultTable Do
				
				NewRow = Object.EarlyPaymentDiscounts.Add();
				FillPropertyValues(NewRow, ResultRow);
				
				NewRow.DueDate			= ResultRow.BaselineDate + NewRow.Period * 86400;
				NewRow.DiscountAmount	= Round(TotalAmount * NewRow.Discount / 100, 2);
				
			EndDo;
			
		EndIf;
		
		ContractData = Result.ContractData.Unload();
		Object.ProvideEPD = ContractData[0].ProvideEPD;
		
	Else
		
		Object.ProvideEPD = Undefined;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function GetEarlyPaymentDiscounts(Object, Result)
	
	Query = New Query;
	Query.SetParameter("Contract", Object.Contract);
	Query.SetParameter("BaselineDate", ?(ValueIsFilled(Object.Date), Object.Date, CurrentSessionDate()));
	
	Query.Text =
	"SELECT ALLOWED
	|	Contracts.Ref AS Ref,
	|	&BaselineDate AS BaselineDate,
	|	Contracts.ProvideEPD AS ProvideEPD
	|INTO TT_Contracts
	|FROM
	|	Catalog.CounterpartyContracts AS Contracts
	|WHERE
	|	Contracts.Ref = &Contract
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Contracts.ProvideEPD AS ProvideEPD
	|FROM
	|	TT_Contracts AS TT_Contracts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_Contracts.BaselineDate AS BaselineDate,
	|	ContractsEarlyPaymentDiscounts.Period AS Period,
	|	ContractsEarlyPaymentDiscounts.Discount AS Discount
	|FROM
	|	TT_Contracts AS TT_Contracts
	|		INNER JOIN Catalog.CounterpartyContracts.EarlyPaymentDiscounts AS ContractsEarlyPaymentDiscounts
	|		ON TT_Contracts.Ref = ContractsEarlyPaymentDiscounts.Ref";
	
	QueryResult = Query.ExecuteBatch();
	Result = New Structure("ContractData, EPD", QueryResult[1], QueryResult[2]);

	Return Not Result.EPD.IsEmpty();
	
EndFunction

#EndRegion 
