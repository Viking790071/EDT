
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If GetFillingErrors(CommandParameter) Then
		Return;
	EndIf;
	
	OpenForm(
		"Document.TaxInvoiceReceived.Form.DocumentForm",
		New Structure(),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

&AtServer
Function GetFillingErrors(CommandParameter)
	
	Query = New Query(
	"SELECT ALLOWED DISTINCT
	|	VATIncurred.Recorder AS Recorder,
	|	TRUE AS ThereAreVATRecors,
	|	FALSE AS ThereAreInvoice,
	|	FALSE AS IncorrectOperation
	|FROM
	|	AccumulationRegister.VATIncurred AS VATIncurred
	|WHERE
	|	VATIncurred.ShipmentDocument IN(&Documents)
	|	AND VATIncurred.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND VALUETYPE(VATIncurred.Recorder) = TYPE(Document.SupplierInvoice)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	TaxInvoice.Ref,
	|	FALSE,
	|	TRUE,
	|	FALSE
	|FROM
	|	Document.TaxInvoiceReceived.BasisDocuments AS PaymentDocuments
	|		INNER JOIN Document.TaxInvoiceReceived AS TaxInvoice
	|		ON PaymentDocuments.Ref = TaxInvoice.Ref
	|WHERE
	|	PaymentDocuments.BasisDocument IN (&Documents)
	|	AND NOT TaxInvoice.DeletionMark
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	CashVoucher.Ref,
	|	FALSE,
	|	TRUE,
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
	|	TRUE,
	|	CASE
	|		WHEN PaymentExpense.OperationKind <> VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|			THEN TRUE
	|		ELSE FALSE
	|	END
	|FROM
	|	Document.PaymentExpense AS PaymentExpense
	|WHERE
	|	PaymentExpense.Ref IN(&Documents)");
	
	Query.SetParameter("Documents", CommandParameter);
	
	Cancel = False;
	Errors = Undefined;
	
	Selection = Query.Execute().Select();
	
	TextVATError = NStr("en = 'The advance amount posted by this payment document is already set off by the %1.
	                    |There is no need to recognize advance VAT. If you still want to input Advance payment invoice,
	                    |revert Supplier invoice in the saved state, input advance payment invoice, and then post supplier invoice again.'; 
	                    |ru = 'Аванс уже зачтен в %1. Нет необходимости в зачете НДС с авансов. Если Вы все же хотите
	                    |ввести инвойс на аванс, то необходимо отменить проведение инвойса поставщика,
	                    |ввести инвойс на аванс и провести инвойс поставщика заново.';
	                    |pl = 'Kwota zaliczki zatwierdzona według tego dokumentu płatności jest już potrącona przez %1.
	                    |Nie jest konieczne zaliczanie zaliczki VAT. Jeśli nadal chcesz wprowadzić fakturę płatności zaliczkowej,
	                    |wróć do zapisanego stanu faktury zakupu, wprowadź fakturę płatności zaliczkowej, a następnie ponownie zatwierdź fakturę zakupu.';
	                    |es_ES = 'El importe de anticipo enviado por este documento de pago ya está desactivado por %1.
	                    |No hay necesidad para reconocer el IVA del anticipo. Si usted aún quiere introducir la factura de Pago anticipado,
	                    |volver a la factura de Proveedor en el estado guardado, introducir la factura de pago anticipado, y entonces enviar de nuevo la factura de proveedor.';
	                    |es_CO = 'El importe de anticipo enviado por este documento de pago ya está desactivado por %1.
	                    |No hay necesidad para reconocer el IVA del anticipo. Si usted aún quiere introducir la factura de Pago anticipado,
	                    |volver a la factura de Proveedor en el estado guardado, introducir la factura de pago anticipado, y entonces enviar de nuevo la factura de proveedor.';
	                    |tr = 'Bu ödeme belgesiyle gönderilen avans tutarı %1 ile ayarlanır.
	                    |Avans KDV''sini tanımaya gerek yoktur. Avans ödeme faturasını yine de girmek istiyorsanız, 
	                    |kaydedilmiş durumdaki Satın alma faturasını değiştirin, avans ödeme faturasını girin ve ardından satın alma faturasını yeniden gönderin.';
	                    |it = 'Il pagamento anticipato pubblicato con questo documento di pagamento è già stato compensato da %1.
	                    |Non c''è motivo per risconoscere anticipo IVA. Se volete ancora inserire fattura di pagamento Anticipato,
	                    |storna la Fattura del fornitore (togli pubblicazione), inserisci fattura di pagamento anticipato, e pubblica nuovamente la Fattura del fornitore.';
	                    |de = 'Der durch diesen Zahlungsbeleg gebuchte Vorauszahlungsbetrag wird bereits durch das %1 verrechnet.
	                    |Eine Aufnahme der USt.-Vorauszahlung ist nicht erforderlich. Wenn Sie dennoch eine Vorauszahlungsrechnung eingeben möchten,
	                    |stornieren Sie die Lieferantenrechnung im gespeicherten Zustand, geben Sie eine Vorauszahlungsrechnung ein und buchen Sie die Lieferantenrechnung erneut.'");
	
	TextInvoiceError = NStr("en = 'The advance amount posted by this payment document is already set off by the %1.
	                        |There is no need to recognize advance VAT. If you still want to input Advance payment invoice,
	                        |revert Supplier invoice in the saved state, input advance payment invoice, and then post supplier invoice again.'; 
	                        |ru = 'Аванс уже зачтен в %1. Нет необходимости в зачете НДС с авансов. Если Вы все же хотите
	                        |ввести инвойс на аванс, то необходимо отменить проведение инвойса поставщика,
	                        |ввести инвойс на аванс и провести инвойс поставщика заново.';
	                        |pl = 'Kwota zaliczki zatwierdzona według tego dokumentu płatności jest już potrącona przez %1.
	                        |Nie jest konieczne zaliczanie zaliczki VAT. Jeśli nadal chcesz wprowadzić fakturę płatności zaliczkowej,
	                        |wróć do zapisanego stanu faktury zakupu, wprowadź fakturę płatności zaliczkowej, a następnie ponownie zatwierdź fakturę zakupu.';
	                        |es_ES = 'El importe de anticipo enviado por este documento de pago ya está desactivado por %1.
	                        |No hay necesidad para reconocer el IVA del anticipo. Si usted aún quiere introducir la factura de Pago anticipado,
	                        |volver a la factura de Proveedor en el estado guardado, introducir la factura de pago anticipado, y entonces enviar de nuevo la factura de proveedor.';
	                        |es_CO = 'El importe de anticipo enviado por este documento de pago ya está desactivado por %1.
	                        |No hay necesidad para reconocer el IVA del anticipo. Si usted aún quiere introducir la factura de Pago anticipado,
	                        |volver a la factura de Proveedor en el estado guardado, introducir la factura de pago anticipado, y entonces enviar de nuevo la factura de proveedor.';
	                        |tr = 'Bu ödeme belgesiyle gönderilen avans tutarı %1 ile ayarlanır.
	                        |Avans KDV''sini tanımaya gerek yoktur. Avans ödeme faturasını yine de girmek istiyorsanız, 
	                        |kaydedilmiş durumdaki Satın alma faturasını değiştirin, avans ödeme faturasını girin ve ardından satın alma faturasını yeniden gönderin.';
	                        |it = 'Il pagamento anticipato pubblicato con questo documento di pagamento è già stato compensato da %1.
	                        |Non c''è motivo per risconoscere anticipo IVA. Se volete ancora inserire fattura di pagamento Anticipato,
	                        |storna la Fattura del fornitore (togli pubblicazione), inserisci fattura di pagamento anticipato, e pubblica nuovamente la Fattura del fornitore.';
	                        |de = 'Der durch diesen Zahlungsbeleg gebuchte Vorauszahlungsbetrag wird bereits durch das %1 verrechnet.
	                        |Eine Aufnahme der USt.-Vorauszahlung ist nicht erforderlich. Wenn Sie dennoch eine Vorauszahlungsrechnung eingeben möchten,
	                        |stornieren Sie die Lieferantenrechnung im gespeicherten Zustand, geben Sie eine Vorauszahlungsrechnung ein und buchen Sie die Lieferantenrechnung erneut.'");
		
	IncorrectOperation = NStr("en = 'The Advance payment invoice is entered only on payment to the Supplier.'; ru = 'Инвойс на аванс вводится только для операций оплаты поставщику.';pl = 'Faktura płatności zaliczkowej jest wprowadzana tylko dla płatności dostawcy.';es_ES = 'La factura de Pago anticipado está introducida solo el pagar al Proveedor.';es_CO = 'La factura de Pago anticipado está introducida solo el pagar al Proveedor.';tr = 'Avans ödeme faturası yalnızca Tedarikçiye ödemede girilir.';it = 'La fattura di pagamento di anticipo è inserita solo sul pagamento al Fornitore.';de = 'Die Vorauszahlungsrechnung wird nur bei Zahlung an den Lieferanten erfasst.'");
	
	While Selection.Next() Do
		
		If Selection.ThereAreVATRecors Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(TextVATError, Selection.Recorder);
			CommonClientServer.AddUserError(Errors, , ErrorText, Undefined);
		EndIf;
		
		If Selection.ThereAreInvoice Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(TextInvoiceError, Selection.Recorder);
			CommonClientServer.AddUserError(Errors, , ErrorText, Undefined);
		EndIf;
		
		If Selection.IncorrectOperation Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(IncorrectOperation, Selection.Recorder);
			CommonClientServer.AddUserError(Errors, , ErrorText, Undefined);
		EndIf;
		
	EndDo;
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
	Return Cancel;
EndFunction
