
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If GetFillingErrors(CommandParameter) Then
		Return;
	EndIf;
	
	OpenForm(
		"Document.TaxInvoiceIssued.ObjectForm",
		New Structure("Basis", CommandParameter),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

&AtServer
Function GetFillingErrors(CommandParameter)
	
	Query = New Query(
	"SELECT ALLOWED DISTINCT
	|	TaxInvoice.Ref AS Recorder,
	|	TRUE AS ThereAreInvoice,
	|	FALSE AS IncorrectOperation
	|FROM
	|	Document.TaxInvoiceIssued.BasisDocuments AS PaymentDocuments
	|		INNER JOIN Document.TaxInvoiceIssued AS TaxInvoice
	|		ON PaymentDocuments.Ref = TaxInvoice.Ref
	|WHERE
	|	PaymentDocuments.BasisDocument IN(&Documents)
	|	AND NOT TaxInvoice.DeletionMark
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
	|	OnlineReceipt.Ref IN(&Documents)");
	
	Query.SetParameter("Documents", CommandParameter);
	
	Cancel = False;
	Errors = Undefined;
	
	Selection = Query.Execute().Select();
	
	TextInvoiceError = NStr("en = 'This payment document is already posted by %1.
	                        |There is no need to create new the Advance payment invoice.'; 
	                        |ru = '???? ?????????????????? ?????? ?????????????? %1.
	                        |???????????????? ???????????? ?????????????? ???? ?????????? ???? ??????????????????.';
	                        |pl = 'Ten dokument p??atno??ci jest ju?? zaksi??gowany przez %1.
	                        |Nie ma konieczno??ci utworzenia nowej faktury p??atno??ci zaliczkowej.';
	                        |es_ES = 'Este documento de pago ya se ha enviado por %1.
	                        |No ha necesidad para crear una nueva factura de Pago anticipado.';
	                        |es_CO = 'Este documento de pago ya se ha enviado por %1.
	                        |No ha necesidad para crear una nueva factura de Pago anticipado.';
	                        |tr = 'Bu ??deme belgesi zaten %1 ile g??nderildi.
	                        | Yeni Avans ??deme faturas?? olu??turulmas?? gerekli de??ildir.';
	                        |it = 'Questo documento di pagamento ?? gi?? stato pubblicato da %1.
	                        |Non ?? necessario creare di nuovo la fattura di pagamento anticipato.';
	                        |de = 'Dieser Zahlungsbeleg ist bereits von %1 gebucht.
	                        |Es ist nicht erforderlich, die Vorauszahlungsrechnung neu zu erstellen.'");
	
	IncorrectOperation = NStr("en = 'The Advance payment invoice is entered only when paying from the Customer.'; ru = '???????????? ???? ?????????? ???????????????? ???????????? ?????? ???????????????? ???????????? ???? ????????????????????.';pl = 'Faktura p??atno??ci zaliczkowej jest wprowadzana tylko dla op??aty od nabywcy.';es_ES = 'La factura del Pago anticipado se ha introducido solo al pagar del Cliente.';es_CO = 'La factura del Pago anticipado se ha introducido solo al pagar del Cliente.';tr = 'Avans ??deme faturas?? sadece m????teriden ??deme al??nd??????nda girilir.';it = 'L''Anticipo del pagamento della fattura ?? inserito solo in caso di pagamento da parte del Cliente.';de = 'Die Vorauszahlungsrechnung wird nur bei Zahlung durch den Kunden erfasst.'");
	
	While Selection.Next() Do
		
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
