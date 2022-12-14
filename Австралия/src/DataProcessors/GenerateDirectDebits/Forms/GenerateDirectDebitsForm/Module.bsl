#Region FormEventHandlers

&AtClient
Procedure FillTable(Command)
	FillTableAtServer();
EndProcedure

&AtClient
Procedure CreateDirectDebits(Command)
	CreateDirectDebitsAtServer();
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	For Each Line In Object.Invoices Do
		Line.Checked = false;
	EndDo;
EndProcedure

&AtClient
Procedure CheckAll(Command)
	For Each Line In Object.Invoices Do
		Line.Checked = True;
	EndDo;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtServer
Procedure FillTableAtServer()
	Object.Invoices.Clear();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccountsReceivableBalance.Document AS Document,
	|	SUM(AccountsReceivableBalance.AmountForPaymentBalance) AS AmountForPaymentBalance
	|INTO TT_Saldo
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(&CurDate, Document.PaymentMethod = VALUE(catalog.PaymentMethods.DirectDebit)) AS AccountsReceivableBalance
	|
	|GROUP BY
	|	AccountsReceivableBalance.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	NestedSelect.SaleInvoiceRef AS Invoice,
	|	NestedSelect.Attention AS Attention,
	|	NestedSelect.DirectDebitRef AS DirectDebit,
	|	NestedSelect.Balance AS Balance
	|FROM
	|	(SELECT
	|		SalesInvoice.Ref AS SaleInvoiceRef,
	|		DirectDebitPaymentDetails.Ref AS DirectDebitRef,
	|		PaymentReceiptPaymentDetails.Ref AS PaymentReceiptRef,
	|		CASE
	|			WHEN SalesInvoice.DirectDebitMandate.MandatePeriodFrom > &CurDate
	|						AND SalesInvoice.DirectDebitMandate.MandatePeriodFrom <> DATETIME(1, 1, 1, 0, 0, 0)
	|					OR SalesInvoice.DirectDebitMandate.MandatePeriodTo < &CurDate
	|						AND SalesInvoice.DirectDebitMandate.MandatePeriodTo <> DATETIME(1, 1, 1, 0, 0, 0)
	|				THEN &MandateIsOutOfPeriodString
	|			WHEN SalesInvoice.DirectDebitMandate.MandateStatus = VALUE(enum.CounterpartyContractStatuses.Closed)
	|				THEN &MandateStatusIsFinishedString
	|			WHEN SalesInvoice.DirectDebitMandate.MandateStatus = VALUE(enum.CounterpartyContractStatuses.NotAgreed)
	|				THEN &MandateStatusIsNotActivedString
	|			ELSE """"
	|		END AS Attention,
	|		TT_Saldo.AmountForPaymentBalance AS Balance
	|	FROM
	|		Document.SalesInvoice AS SalesInvoice
	|			LEFT JOIN Document.DirectDebit.PaymentDetails AS DirectDebitPaymentDetails
	|			ON SalesInvoice.Ref = DirectDebitPaymentDetails.Document
	|				AND (NOT DirectDebitPaymentDetails.Ref.DeletionMark)
	|			LEFT JOIN Document.PaymentReceipt.PaymentDetails AS PaymentReceiptPaymentDetails
	|			ON SalesInvoice.Ref = PaymentReceiptPaymentDetails.Document
	|			LEFT JOIN TT_Saldo AS TT_Saldo
	|			ON SalesInvoice.Ref = TT_Saldo.Document
	|	WHERE
	|		SalesInvoice.PaymentMethod = VALUE(catalog.PaymentMethods.DirectDebit)
	|		AND SalesInvoice.Posted
	|		AND NOT SalesInvoice.DeletionMark) AS NestedSelect
	|WHERE
	|	(NestedSelect.DirectDebitRef IS NULL
	|			OR NOT NestedSelect.DirectDebitRef.Posted)
	|	AND NestedSelect.PaymentReceiptRef IS NULL
	|
	|ORDER BY
	|	NestedSelect.SaleInvoiceRef.Date";
	
	Query.SetParameter("CurDate",CurrentSessionDate());
	Query.SetParameter("MandateStatusIsFinishedString", NStr("en='Mandate status is Finished'; ru = '???????????? ?????????? ???????????? ""????????????????""';pl = 'Status zlecenia jest Zako??czony';es_ES = 'Estado del mandato es Finalizado';es_CO = 'Estado del mandato es Finalizado';tr = 'Talimat durumu ""Tamamlanm????""';it = 'Lo stato del Mandato ?? Terminato';de = 'Lastschriftmandat-Status ist abgeschlossen'"));
	Query.SetParameter("MandateIsOutOfPeriodString", NStr("en='Mandate period is out of direct debit date'; ru = '???????????? ???????????????? ?????????????? ?????? ???????????? ???????? ?????????????? ??????????????????????';pl = 'Data zezwolenia jest poza okresem polecenia zap??aty';es_ES = 'El per??odo del mandato no est?? fuera de la fecha de d??bito directo';es_CO = 'El per??odo del mandato no est?? fuera de la fecha de d??bito directo';tr = 'Talimat d??nemi d??zenli ??deme tarihi d??????nda';it = 'Il periodo di mandato non ?? incluso nella data di addebito diretto';de = 'Lastschriftmandat-Dauer ist unser Datum der direkten Lastschrift'"));
	Query.SetParameter("MandateStatusIsNotActivedString", NStr("en='Mandate status is Pending'; ru = '???????????? ?????????? ???????????? ""?? ????????????????????????""';pl = 'Status zlecenia jest w toku';es_ES = 'Estado del mandato es Pendiente';es_CO = 'Estado del mandato es Pendiente';tr = 'Talimat durumu ""Beklemede""';it = 'Lo stato del Mandato ?? Pendente';de = 'Lastschriftmandat-Status ist Ausstehend'"));
	
	
	Sel = Query.Execute().Select();
	While Sel.Next() Do
		Ln = Object.Invoices.Add();
		FillPropertyValues(Ln, Sel);
	EndDo;
	
EndProcedure

&AtServer
Procedure CreateDirectDebitsAtServer()
	For Each Ln In Object.Invoices Do
		If Ln.Checked Then
			// check mandate status
			If (Ln.Invoice.DirectDebitMandate.MandateStatus = Enums.CounterpartyContractStatuses.Closed) Then
				MessageText = NStr("en = 'Mandate status can not be Finished'; ru = '???????????? ???? ?????????? ?????????? ???????????? ""????????????????""';pl = 'Status zlecenia nie mo??e by?? Zako??czony';es_ES = 'Estado del mandato no puede ser Finalizado';es_CO = 'Estado del mandato no puede ser Finalizado';tr = 'Talimat durumu ""Tamamlanm????"" olamaz';it = 'Lo stato del Mandato non pu?? essere Terminato';de = 'Lastschriftmandat-Status kann nicht abegschlossen werden'");
				CommonClientServer.MessageToUser(MessageText,,,,False);
				Continue;
			EndIf;
			
			
			If Ln.DirectDebit.IsEmpty() Then
				DirectDebit = Documents.DirectDebit.CreateDocument();
				DirectDebit.Date = CurrentSessionDate();
			Else
				DirectDebit = Ln.DirectDebit.GetObject();
				DirectDebit.PaymentDetails.Clear();
			EndIf;
			
			DirectDebit.Fill(Ln.Invoice);
			
			DirectDebit.Write(DocumentWriteMode.Write);
			Try 
				DirectDebit.Write(DocumentWriteMode.Posting);
			Except
				CommonClientServer.MessageToUser(ErrorDescription(),,,,False);
			EndTry;
			
			Ln.DirectDebit = DirectDebit.Ref;
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure InvoicesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	Invoices = Items.Invoices;
	If Invoices.CurrentItem.Name = "InvoicesInvoice" Then
		StandardProcessing = False;
		OpenForm(
			"Document.SalesInvoice.ObjectForm",
			New Structure("Key", Invoices.CurrentData.Invoice));
	ElsIf Invoices.CurrentItem.Name = "InvoicesDirectDebit" Then
		StandardProcessing = False;
		OpenForm(
			"Document.DirectDebit.ObjectForm",
		New Structure("Key", Invoices.CurrentData.DirectDebit));
	EndIf;
	
EndProcedure

#EndRegion