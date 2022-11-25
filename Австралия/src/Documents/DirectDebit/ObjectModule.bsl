#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// Procedure - event handler "Posting".
//
Procedure Posting(Cancel, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure ChangeMandateType(WriteMode)
	If Mandate.IsEmpty() Then
		Return;
	EndIf;
	
	// change mandate type 
	NewStatus = Mandate.MandateStatus;
	NewSequenceType = Mandate.DirectDebitSequenceType;
	
	If WriteMode = DocumentWriteMode.Posting Then
		If Mandate.DirectDebitSequenceType = Enums.DirectDebitSequenceTypes.OOFF Then
			NewStatus = Enums.CounterpartyContractStatuses.Closed;
		Else
			If SequenceType = Enums.DirectDebitSequenceTypes.RCUR Then
				// if this was final payment and now it is next - return mandate to next
				NewStatus = Enums.CounterpartyContractStatuses.Active;
				NewSequenceType = Enums.DirectDebitSequenceTypes.RCUR;
			ElsIf SequenceType = Enums.DirectDebitSequenceTypes.FNAL Then
				// if this was final payment -set mandate to FNAL
				NewStatus = Enums.CounterpartyContractStatuses.Closed;
				NewSequenceType = Enums.DirectDebitSequenceTypes.FNAL;
			EndIf
		EndIf;		
	ElsIf WriteMode = DocumentWriteMode.UndoPosting Then
		// if this was final payment - return mandate to next
		NewStatus = Enums.CounterpartyContractStatuses.Active;
		If Mandate.DirectDebitSequenceType <> Enums.DirectDebitSequenceTypes.OOFF Then
			NewSequenceType = Enums.DirectDebitSequenceTypes.RCUR;
		EndIf;
	EndIf;
	
	If NewStatus <> Mandate.MandateStatus Then
		Man = Mandate.GetObject();
		Man.DirectDebitSequenceType = NewSequenceType;
		Man.MandateStatus = NewStatus;
		Man.Write();
	EndIf;

EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	If DataExchange.Load Then
		Return;
	EndIf;

	ChangeMandateType(WriteMode);
EndProcedure

Procedure Filling(FillingData, StandardProcessing)
	If TypeOf(FillingData) = Type("DocumentRef.SalesInvoice") Then
		PaymentPurpose = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en='Invoice #%1 dated %2'; ru = 'Инвойс №%1 от %2';pl = 'Faktura nr %1 z dnia %2';es_ES = 'Factura #%1 fechada %2';es_CO = 'Factura #%1 fechada %2';tr = '%1 sayılı, %2 tarihli fatura';it = 'Fattura #%1 datata %2';de = 'Rechnung Nr. %1 vom %2'"),
			FillingData.Number,
			Format(FillingData.Date,NStr("en = 'dd.MM.yyyy'; ru = 'дд.ММ.гггг';pl = 'dd.MM.yyyy';es_ES = 'dd.MM.aaaa';es_CO = 'dd.MM.aaaa';tr = 'gg.AA.yyyy';it = 'dd/MM/yyyy';de = 'dd.MM.yyyy'")));
		PaymentDate = CurrentSessionDate();
		Author = SessionParameters.CurrentUser;
		BankAccount = FillingData.BankAccount;
		Comment = FillingData.Comment;
		Company = FillingData.Company;
		Counterparty = FillingData.Counterparty;
		CounterpartyAccount = FillingData.CounterpartyBankAcc;
		DocumentAmount = FillingData.DocumentAmount;
		DocumentCurrency = FillingData.DocumentCurrency;
		PaymentDate = CurrentSessionDate();
		Mandate = FillingData.DirectDebitMandate;
		SequenceType = Mandate.DirectDebitSequenceType;
		CounterpartyAccount = Mandate.BankAccount;
		If FillingData.PaymentCalendar.Count() > 0 Then
			PaymentDate = FillingData.PaymentCalendar[0].PaymentDate;
		EndIf;
		
		InvInfo = FillingData.Inventory.Unload();
		InvInfo.GroupBy("VATRate","VATAmount,Amount");
		For Each Det In InvInfo Do
			Ln = PaymentDetails.Add();
			Ln.Document = FillingData.Ref;
			Ln.Contract = Ln.Document.Contract;
			Ln.VATRate = Det.VATRate;
			Ln.VATAmount = Det.VATAmount;
			If Ln.Document.AmountIncludesVAT Then 
				Ln.PaymentAmount = Det.Amount;
			Else
				Ln.PaymentAmount = Det.Amount + Det.VATAmount;
			EndIf;
		EndDo;
	ElsIf TypeOf(FillingData) = Type("CatalogRef.CounterpartyContracts") Then
		If FillingData.PaymentMethod <> Catalogs.PaymentMethods.DirectDebit Then
			Return;
		EndIf;
			
		PaymentPurpose = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en='Contract #%1 dated %2'; ru = 'Договор №%1 от %2';pl = 'Kontrakt nr %1 z dnia %2';es_ES = 'Contrato #%1 fechado %2';es_CO = 'Contrato #%1 fechado %2';tr = '#%1 tarihli %2 sözleşme';it = 'Contratto #%1 datato %2';de = 'Vertrag Nr. #%1 vom %2'"),
			FillingData.ContractNo,
			Format(FillingData.ContractDate,NStr("en = 'dd.MM.yyyy'; ru = 'дд.ММ.гггг';pl = 'dd.MM.yyyy';es_ES = 'dd.MM.aaaa';es_CO = 'dd.MM.aaaa';tr = 'gg.AA.yyyy';it = 'dd/MM/yyyy';de = 'dd.MM.yyyy'")));
		PaymentDate = CurrentSessionDate();
		Author = SessionParameters.CurrentUser;
		Comment = FillingData.Comment;
		Company = FillingData.Company;
		Counterparty = FillingData.Owner;
		
		DocumentCurrency = FillingData.SettlementsCurrency;
		PaymentDate = CurrentSessionDate();
		Mandate = FillingData.DirectDebitMandate;
		SequenceType = Mandate.DirectDebitSequenceType;
		CounterpartyAccount = Mandate.BankAccount;
		
		Ln = PaymentDetails.Add();
		Ln.Contract = FillingData.Ref;
		Ln.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(CurrentSessionDate(), Company);

	EndIf;
EndProcedure

Procedure OnCopy(CopiedObject)
	Mandate = Undefined;
	SequenceType = Undefined;
EndProcedure

#EndRegion

#EndIf