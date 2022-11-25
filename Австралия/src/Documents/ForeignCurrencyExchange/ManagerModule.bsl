#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure InitializeDocumentData(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	PresentationCurrency = StructureAdditionalProperties.ForPosting.PresentationCurrency;
	
	Query.SetParameter("Ref",			DocumentRefForeignCurrencyExchange);
	Query.SetParameter("PointInTime",	New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company",		StructureAdditionalProperties.ForPosting.Company);
	
	Query.SetParameter("PresentationCurrency",		PresentationCurrency);
	Query.SetParameter("FromAccountCashCurrency",	DocumentRefForeignCurrencyExchange.FromAccountCurrency);
	Query.SetParameter("ToAccountCashCurrency",		DocumentRefForeignCurrencyExchange.ToAccountCurrency);
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	MainOperationContent = NStr("en = 'Foreign currency exchange'; ru = 'Обмен валюты';pl = 'Wymiana waluty obcej';es_ES = 'Cambio de la moneda extranjera';es_CO = 'Cambio de la moneda extranjera';tr = 'Yabancı para birimi değişimi';it = 'Tasso di cambio della valuta estera';de = 'Fremdwährungsumtausch'", MainLanguageCode);
	
	If DocumentRefForeignCurrencyExchange.ToAccountCurrency <> PresentationCurrency
		AND DocumentRefForeignCurrencyExchange.FromAccountCurrency <> PresentationCurrency Then 
		MainOperationContent = NStr("en = 'Foreign currency exchange'; ru = 'Обмен валюты';pl = 'Wymiana waluty obcej';es_ES = 'Cambio de la moneda extranjera';es_CO = 'Cambio de la moneda extranjera';tr = 'Yabancı para birimi değişimi';it = 'Tasso di cambio della valuta estera';de = 'Fremdwährungsumtausch'", MainLanguageCode);
	ElsIf DocumentRefForeignCurrencyExchange.ToAccountCurrency <> PresentationCurrency Then 
		MainOperationContent = NStr("en = 'Foreign currency acquisition'; ru = 'Покупка валюты';pl = 'Zakup waluty obcej';es_ES = 'Adquisición de la divisa extranjera';es_CO = 'Adquisición de la divisa extranjera';tr = 'Döviz alımı';it = 'Acquisizione di valuta estera';de = 'Fremdwährungserwerb'", MainLanguageCode);
	ElsIf DocumentRefForeignCurrencyExchange.FromAccountCurrency <> PresentationCurrency Then 
		MainOperationContent = NStr("en = 'Foreign currency sale'; ru = 'Продажа валюты';pl = 'Sprzedaż waluty obcej';es_ES = 'Compra de la moneda extranjera';es_CO = 'Compra de la moneda extranjera';tr = 'Döviz satışı';it = 'Vendita di valuta estera';de = 'Fremdwährungsverkauf'", MainLanguageCode);
	EndIf;
	
	If GetFunctionalOption("UseSeveralDepartments") Then 
		StructureAdditionalProperties.ForPosting.Insert("StructuralUnit", DocumentRefForeignCurrencyExchange.StructuralUnit);
	Else 
		StructureAdditionalProperties.ForPosting.Insert("StructuralUnit", Catalogs.BusinessUnits.MainDepartment);
	EndIf;
	
	If Not StructureAdditionalProperties.Property("CalculatedData") Then
		StructureAdditionalProperties.Insert("CalculatedData", GetCalculatedData(DocumentRefForeignCurrencyExchange));
	EndIf;
	
	Query.SetParameter("MainOperationContent", MainOperationContent);
	Query.SetParameter("ContentBankCommission", NStr("en = 'Bank fee'; ru = 'Банковская комиссия';pl = 'Prowizja bankowa';es_ES = 'Comisión del banco';es_CO = 'Comisión del banco';tr = 'Banka masrafı';it = 'Commissioni bancarie';de = 'Bankgebühr'", MainLanguageCode));
	
	Query.SetParameter("TotalSending",				StructureAdditionalProperties.CalculatedData.TotalSending);
	Query.SetParameter("TotalSendingCurrency",		StructureAdditionalProperties.CalculatedData.TotalSendingCurrency);
	Query.SetParameter("SendingBankFee",			StructureAdditionalProperties.CalculatedData.SendingBankFee);
	Query.SetParameter("SendingBankFeeCurrency",	StructureAdditionalProperties.CalculatedData.SendingBankFeeCurrency);
	Query.SetParameter("ReceivingAmountCurrency",	StructureAdditionalProperties.CalculatedData.ReceivingAmountCurrency);
	Query.SetParameter("ReceivingBankFee",			StructureAdditionalProperties.CalculatedData.ReceivingBankFee);
	Query.SetParameter("ReceivingBankFeeCurrency",	StructureAdditionalProperties.CalculatedData.ReceivingBankFeeCurrency);
	
	Query.Text =
	"SELECT
	|	ExchangeRateSliceLast.Currency AS Currency,
	|	ExchangeRateSliceLast.Rate AS ExchangeRate,
	|	ExchangeRateSliceLast.Repetition AS Multiplicity
	|INTO TemporaryTableExchangeRateSliceLatest
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(
	|			&PointInTime,
	|			Currency IN (&PresentationCurrency, &FromAccountCashCurrency, &ToAccountCashCurrency)
	|				AND Company = &Company) AS ExchangeRateSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ForeignCurrencyExchange.Ref AS ForeignCurrencyExchangeRef,
	|	1 AS LineNumber,
	|	ForeignCurrencyExchange.Date AS Date,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	ForeignCurrencyExchange.Item AS Item,
	|	ForeignCurrencyExchange.DocumentAmount AS DocumentAmount,
	|	ForeignCurrencyExchange.FromAccount AS FromAccount,
	|	ForeignCurrencyExchange.ToAccount AS ToAccount,
	|	ForeignCurrencyExchange.CashExchange AS CashExchange,
	|	ForeignCurrencyExchange.ExpenseItem AS ExpenseItem,
	|	CASE
	|		WHEN ForeignCurrencyExchange.CashExchange
	|			THEN CashAccountsFrom.GLAccount
	|		ELSE BankAccountsFrom.GLAccount
	|	END AS FromAccountGLAccount,
	|	CASE
	|		WHEN ForeignCurrencyExchange.CashExchange
	|			THEN CashAccountsTo.GLAccount
	|		ELSE BankAccountsTo.GLAccount
	|	END AS ToAccountGLAccount,
	|	ForeignCurrencyExchange.FromAccountCurrency AS FromAccountCashCurrency,
	|	ForeignCurrencyExchange.ToAccountCurrency AS ToAccountCashCurrency,
	|	BankCharges.GLAccount AS BankChargeGLAccount,
	|	BankCharges.GLExpenseAccount AS BankChargeGLExpenseAccount,
	|	&TotalSending AS TotalSending,
	|	&TotalSendingCurrency AS TotalSendingCurrency,
	|	&SendingBankFee AS SendingBankFee,
	|	&SendingBankFeeCurrency AS SendingBankFeeCurrency,
	|	&ReceivingAmountCurrency AS ReceivingAmountCurrency,
	|	&ReceivingBankFee AS ReceivingBankFee,
	|	&ReceivingBankFeeCurrency AS ReceivingBankFeeCurrency,
	|	FromAccountCentralBankExchangeRateSliceLast.ExchangeRate / FromAccountCentralBankExchangeRateSliceLast.Multiplicity AS FromAccountExchangeRate,
	|	ToAccountCentralBankExchangeRateSliceLast.ExchangeRate / ToAccountCentralBankExchangeRateSliceLast.Multiplicity AS ToAccountExchangeRate,
	|	ForeignCurrencyExchange.BankCharge AS BankCharge,
	|	ForeignCurrencyExchange.BankChargeItem AS BankChargeItem,
	|	&MainOperationContent AS MainOperationContent,
	|	&ContentBankCommission AS ContentBankCommission
	|INTO TemporaryTableHeader
	|FROM
	|	Document.ForeignCurrencyExchange AS ForeignCurrencyExchange
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS AccountingExchangeRate
	|		ON (AccountingExchangeRate.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS FromAccountCentralBankExchangeRateSliceLast
	|		ON (FromAccountCentralBankExchangeRateSliceLast.Currency = &FromAccountCashCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS ToAccountCentralBankExchangeRateSliceLast
	|		ON (ToAccountCentralBankExchangeRateSliceLast.Currency = &ToAccountCashCurrency)
	|		LEFT JOIN Catalog.BankAccounts AS BankAccountsFrom
	|		ON ForeignCurrencyExchange.FromAccount = BankAccountsFrom.Ref
	|		LEFT JOIN Catalog.BankAccounts AS BankAccountsTo
	|		ON ForeignCurrencyExchange.ToAccount = BankAccountsTo.Ref
	|		LEFT JOIN Catalog.BankCharges AS BankCharges
	|		ON ForeignCurrencyExchange.BankCharge = BankCharges.Ref
	|		LEFT JOIN Catalog.CashAccounts AS CashAccountsFrom
	|		ON ForeignCurrencyExchange.FromAccount = CashAccountsFrom.Ref
	|		LEFT JOIN Catalog.CashAccounts AS CashAccountsTo
	|		ON ForeignCurrencyExchange.ToAccount = CashAccountsTo.Ref
	|WHERE
	|	ForeignCurrencyExchange.Ref = &Ref";
	
	Query.Execute();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);

	GenerateTableBankCharges(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);
	GenerateTableCashAssets(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);
	GenerateTableBankReconciliation(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

Function GetCalculatedData(DocumentObject) Export 
	
	CalculateTotalReceivingCurrency = Not DocumentObject.ManualTotalReceivingCurrency;
	
	PresentationCurrency = DriveServer.GetPresentationCurrency(DocumentObject.Company);
	ExchangeRateMethod   = DriveServer.GetExchangeMethod(DocumentObject.Company);
	
	DocumentAmount = DocumentObject.DocumentAmount;
	BankCharge = DocumentObject.BankCharge;
	
	FromAccountCurrency = DocumentObject.FromAccountCurrency;
	FromAccountCurrencyExchangeRate = DriveServer.GetExchangeRate(DocumentObject.Company, PresentationCurrency, FromAccountCurrency, DocumentObject.Date);
	CentralBankERSending = FromAccountCurrencyExchangeRate.Rate;
	CentralBankMulSending = FromAccountCurrencyExchangeRate.Repetition;
	CentralBankCoefSending = FromAccountCurrencyExchangeRate.Rate / FromAccountCurrencyExchangeRate.Repetition;
	
	ToAccountCurrency = DocumentObject.ToAccountCurrency;
	ToAccountCurrencyExchangeRate = DriveServer.GetExchangeRate(DocumentObject.Company, PresentationCurrency, ToAccountCurrency, DocumentObject.Date);
	CentralBankERReceiving = ToAccountCurrencyExchangeRate.Rate;
	CentralBankMulreceiving = ToAccountCurrencyExchangeRate.Repetition;
	CentralBankCoefReceiving = ToAccountCurrencyExchangeRate.Rate / ToAccountCurrencyExchangeRate.Repetition;
	
	If DocumentObject.FromAccountMultiplicity <> 0 Then
		FromAccountExchangeRateIncludingMultiplicity = DocumentObject.FromAccountExchangeRate / DocumentObject.FromAccountMultiplicity;
	Else
		FromAccountExchangeRateIncludingMultiplicity = DocumentObject.FromAccountExchangeRate;
	EndIf;
	
	If DocumentObject.ToAccountMultiplicity <> 0 Then
		ToAccountExchangeRateIncludingMultiplicity = DocumentObject.ToAccountExchangeRate / DocumentObject.ToAccountMultiplicity;
	Else
		ToAccountExchangeRateIncludingMultiplicity = DocumentObject.ToAccountExchangeRate;
	EndIf;
	
	TotalSending = 0;
	TotalSendingCurrency = 0;
	
	SendingAmount = 0;
	SendingBankFee = 0;
	SendingBankFeeCurrency = 0;
	
	TotalReceiving = 0;
	If CalculateTotalReceivingCurrency Then
		TotalReceivingCurrency = 0;
	Else
		TotalReceivingCurrency = DocumentObject.TotalReceivingCurrency;
	EndIf;
	ReceivingBankFee = 0;
	ReceivingBankFeeCurrency = 0;
	
	DoSendingOperations		= DocumentObject.ToAccountCurrency <> PresentationCurrency;
	DoReceivingOperations	= DocumentObject.FromAccountCurrency <> PresentationCurrency;
	DoBothOperations		= DoSendingOperations AND DoReceivingOperations;
	
	If BankCharge.ChargeType = Enums.ChargeMethod.SpecialExchangeRate Then 
		
		If DoBothOperations Then 
			
			If ExchangeRateMethod = Enums.ExchangeRateMethods.Multiplier Then
				
				SendingBankFee         = DocumentAmount * (CentralBankCoefSending - FromAccountExchangeRateIncludingMultiplicity);
				SendingBankFeeCurrency = SendingBankFee / CentralBankCoefSending;
				
			Else
				
				SendingBankFee         = DocumentAmount / (CentralBankCoefSending - FromAccountExchangeRateIncludingMultiplicity);
				SendingBankFeeCurrency = SendingBankFee * CentralBankCoefSending;				
				
			EndIf;
			
			TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
			If CalculateTotalReceivingCurrency Then
				If ExchangeRateMethod = Enums.ExchangeRateMethods.Multiplier Then
					
					TotalReceivingCurrency = Round(DocumentAmount * FromAccountExchangeRateIncludingMultiplicity
						/ ToAccountExchangeRateIncludingMultiplicity, 2);
						
				Else
					
					TotalReceivingCurrency = Round(DocumentAmount / FromAccountExchangeRateIncludingMultiplicity
						* ToAccountExchangeRateIncludingMultiplicity, 2);
					
				EndIf;
			EndIf;
			
			If ExchangeRateMethod = Enums.ExchangeRateMethods.Multiplier Then
				
				TotalSending   = TotalSendingCurrency * CentralBankCoefSending;
				TotalReceiving = TotalReceivingCurrency * CentralBankCoefReceiving;
			
				ReceivingBankFee         = TotalSending - TotalReceiving;
				ReceivingBankFeeCurrency = ReceivingBankFee / CentralBankCoefReceiving;
				
			Else
				
				TotalSending   = TotalSendingCurrency / CentralBankCoefSending;
				TotalReceiving = TotalReceivingCurrency / CentralBankCoefReceiving;
			
				ReceivingBankFee         = TotalSending - TotalReceiving;
				ReceivingBankFeeCurrency = ReceivingBankFee * CentralBankCoefReceiving;

			EndIf;
			
		ElsIf DoSendingOperations Then 
			
			If ExchangeRateMethod = Enums.ExchangeRateMethods.Multiplier Then
				
				If CalculateTotalReceivingCurrency Then
					TotalSending = DocumentAmount / ToAccountExchangeRateIncludingMultiplicity * CentralBankCoefReceiving;
				Else
					TotalSending = TotalReceivingCurrency * CentralBankCoefReceiving;
				EndIf;
				
			Else
				
				If CalculateTotalReceivingCurrency Then
					TotalSending = DocumentAmount * ToAccountExchangeRateIncludingMultiplicity / CentralBankCoefReceiving;
				Else
					TotalSending = TotalReceivingCurrency / CentralBankCoefReceiving;
				EndIf;
				
			EndIf;
			
			SendingBankFee         = DocumentAmount - TotalSending;
			SendingBankFeeCurrency = SendingBankFee;
			
			TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
			If CalculateTotalReceivingCurrency Then
				If ExchangeRateMethod = Enums.ExchangeRateMethods.Multiplier Then
					TotalReceivingCurrency = DocumentAmount / ToAccountExchangeRateIncludingMultiplicity;
				Else
					TotalReceivingCurrency = DocumentAmount * ToAccountExchangeRateIncludingMultiplicity;
				EndIf;
			EndIf;
			
		ElsIf DoReceivingOperations Then 
			If ExchangeRateMethod = Enums.ExchangeRateMethods.Multiplier Then
				
				TotalSending = DocumentAmount * FromAccountExchangeRateIncludingMultiplicity;
				TotalSendingCurrency = TotalSending / CentralBankCoefSending;
				
				SendingAmount = DocumentAmount * CentralBankCoefSending;
				
			Else
				
				TotalSending = DocumentAmount / FromAccountExchangeRateIncludingMultiplicity;
				TotalSendingCurrency = TotalSending * CentralBankCoefSending;
				
				SendingAmount = DocumentAmount / CentralBankCoefSending;
				
			EndIf;
			
			SendingBankFee = SendingAmount - TotalSending;
			SendingBankFeeCurrency = DocumentAmount - TotalSendingCurrency;
			
			If CalculateTotalReceivingCurrency Then
				TotalReceivingCurrency = TotalSending;
			EndIf;
			
		EndIf;
		
	ElsIf BankCharge.ChargeType = Enums.ChargeMethod.Percent Then 
		
		If DoBothOperations Then
			
			SendingBankFeeCurrency = DocumentAmount * DocumentObject.BankFeeValue / 100;
			
			If ExchangeRateMethod = Enums.ExchangeRateMethods.Multiplier Then
				
				SendingBankFee = SendingBankFeeCurrency * CentralBankCoefSending;
			
				TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
				TotalSending = TotalSendingCurrency * CentralBankCoefSending;
				If CalculateTotalReceivingCurrency Then
					TotalReceivingCurrency = TotalSending / CentralBankCoefReceiving;
				EndIf;
				
			Else
				
				SendingBankFee = SendingBankFeeCurrency / CentralBankCoefSending;
			
				TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
				TotalSending = TotalSendingCurrency / CentralBankCoefSending;
				If CalculateTotalReceivingCurrency Then
					TotalReceivingCurrency = TotalSending * CentralBankCoefReceiving;
				EndIf;
				
			EndIf;
			
		ElsIf DoSendingOperations Then
			
			
			SendingBankFee = DocumentAmount * DocumentObject.BankFeeValue / 100;
			SendingBankFeeCurrency = SendingBankFee;
			
			TotalSending = DocumentAmount - SendingBankFee;
			
			TotalSendingCurrency = TotalSending;
			If CalculateTotalReceivingCurrency Then
				
				If ExchangeRateMethod = Enums.ExchangeRateMethods.Divisor Then
					
					TotalReceivingCurrency = TotalSending / CentralBankCoefReceiving;
					
				Else
					
					TotalReceivingCurrency = TotalSending * CentralBankCoefReceiving;
					
				EndIf;
				
			EndIf;
			
		ElsIf DoReceivingOperations Then
			
			SendingBankFeeCurrency = DocumentAmount * DocumentObject.BankFeeValue / 100;
			
			If ExchangeRateMethod = Enums.ExchangeRateMethods.Multiplier Then
				
				SendingBankFee = SendingBankFeeCurrency * CentralBankCoefSending;
				
				TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
				TotalSending = TotalSendingCurrency * CentralBankCoefSending;
				
			Else
				
				SendingBankFee = SendingBankFeeCurrency / CentralBankCoefSending;
				
				TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
				TotalSending = TotalSendingCurrency / CentralBankCoefSending;
				
			EndIf;
			
			If CalculateTotalReceivingCurrency Then
				TotalReceivingCurrency = TotalSending;
			EndIf;
			
		EndIf;
		
	ElsIf BankCharge.ChargeType = Enums.ChargeMethod.Amount Then 
		
		If DoBothOperations Then 
			
			SendingBankFeeCurrency = DocumentObject.BankFeeValue;
			
			If ExchangeRateMethod = Enums.ExchangeRateMethods.Multiplier Then
				
				SendingBankFee = SendingBankFeeCurrency * CentralBankCoefSending;
			
				TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
				TotalSending = TotalSendingCurrency * CentralBankCoefSending;
				If CalculateTotalReceivingCurrency Then
					TotalReceivingCurrency = TotalSending / CentralBankCoefReceiving;
				EndIf;
				
			Else
				
				SendingBankFee = SendingBankFeeCurrency / CentralBankCoefSending;
			
				TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
				TotalSending = TotalSendingCurrency / CentralBankCoefSending;
				If CalculateTotalReceivingCurrency Then
					
					If ExchangeRateMethod = Enums.ExchangeRateMethods.Multiplier Then
						TotalReceivingCurrency = TotalSending * CentralBankCoefReceiving;
					Else
						TotalReceivingCurrency = TotalSending / CentralBankCoefReceiving;
					EndIf;
					
				EndIf;
				
			EndIf;
		ElsIf DoSendingOperations Then
			
			SendingBankFee = DocumentObject.BankFeeValue;
			SendingBankFeeCurrency = SendingBankFee;
			
			TotalSending = DocumentAmount - SendingBankFee;
			
			TotalSendingCurrency = TotalSending;
			If CalculateTotalReceivingCurrency Then
				
				If ExchangeRateMethod = Enums.ExchangeRateMethods.Multiplier Then
					TotalReceivingCurrency = TotalSending / CentralBankCoefReceiving;
				Else 
					TotalReceivingCurrency = TotalSending * CentralBankCoefReceiving;
				EndIf;
			EndIf;
			
		ElsIf DoReceivingOperations Then 
			
			SendingBankFeeCurrency = DocumentObject.BankFeeValue;
			
			If ExchangeRateMethod = Enums.ExchangeRateMethods.Multiplier Then
				
				SendingBankFee = SendingBankFeeCurrency * CentralBankCoefSending;
				
				TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
				TotalSending = TotalSendingCurrency * CentralBankCoefSending;
				
			Else
				
				SendingBankFee = SendingBankFeeCurrency / CentralBankCoefSending;
				
				TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
				TotalSending = TotalSendingCurrency / CentralBankCoefSending;
			
			EndIf;
			If CalculateTotalReceivingCurrency Then
				TotalReceivingCurrency = TotalSending;
			EndIf;
		
		EndIf;
		
	EndIf;
	
	SendingAmount = TotalSending + SendingBankFee;
	TotalReceiving = TotalSending - ReceivingBankFee;
	ReceivingAmountCurrency = TotalReceivingCurrency + ReceivingBankFeeCurrency;
	
	AmountFee = SendingBankFee + ReceivingBankFee;
	
	CalculatedData = New Structure();
	CalculatedData.Insert("TotalSending",				TotalSending);
	CalculatedData.Insert("SendingAmount",				SendingAmount);
	CalculatedData.Insert("TotalReceiving",				TotalReceiving);
	CalculatedData.Insert("ReceivingAmount",			TotalSending);
	CalculatedData.Insert("ReceivingAmountCurrency",	ReceivingAmountCurrency);
	CalculatedData.Insert("TotalSendingCurrency",		TotalSendingCurrency);
	CalculatedData.Insert("SendingBankFee",				SendingBankFee);
	CalculatedData.Insert("SendingBankFeeCurrency",		SendingBankFeeCurrency);
	CalculatedData.Insert("TotalReceivingCurrency",		TotalReceivingCurrency);
	CalculatedData.Insert("ReceivingBankFee",			ReceivingBankFee);
	CalculatedData.Insert("ReceivingBankFeeCurrency",	ReceivingBankFeeCurrency);
	CalculatedData.Insert("CentralBankERSending",		CentralBankERSending);
	CalculatedData.Insert("CentralBankMulSending",		CentralBankMulSending);
	CalculatedData.Insert("CentralBankERReceiving",		CentralBankERReceiving);
	CalculatedData.Insert("CentralBankMulreceiving",	CentralBankMulreceiving);
	CalculatedData.Insert("AmountFee",					AmountFee);
	
	Return CalculatedData;
	                                         
EndFunction

Procedure RunControl(DocumentRef, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		AccumulationRegisters.CashAssets.IndependentCashAssetsRunControl(
			DocumentRef,
			AdditionalProperties,
			Cancel,
			PostingDelete);
			
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsCashAssetsChange
		Or StructureTemporaryTables.RegisterRecordsBankReconciliationChange Then
		
		Query = New Query;
		Query.Text = AccumulationRegisters.CashAssets.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.BankReconciliation.BalancesControlQueryText();
		
		AccumulationRegisters.CashAssets.GenerateTableCashAssetsBalances(StructureTemporaryTables, AdditionalProperties);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		Query.SetParameter("Date", AdditionalProperties.ForPosting.Date);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty() Then
			DocumentObject = DocumentRef.GetObject();
		EndIf;
		
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToCashAssetsRegisterErrors(DocumentObject, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToBankReconciliationRegisterErrors(DocumentObject, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Header" Then
		IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Return New Structure;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#EndRegion

#Region Internal

#Region AccountingTemplates

Function EntryTypes() Export 
	
	EntryTypes = New Array;
	
	Return EntryTypes;
	
EndFunction

Function AccountingFields() Export 
	
	AccountingFields = New Map;
	
	Return AccountingFields;
	
EndFunction

#EndRegion 

#EndRegion 

#Region Private

#Region TableGeneration

Procedure GenerateTableBankCharges(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TemporaryTableBankCharges.Period AS Period,
	|	TemporaryTableBankCharges.Company AS Company,
	|	TemporaryTableBankCharges.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableBankCharges.BankAccount AS BankAccount,
	|	TemporaryTableBankCharges.CashExchange AS CashExchange,
	|	TemporaryTableBankCharges.Currency AS Currency,
	|	TemporaryTableBankCharges.BankCharge AS BankCharge,
	|	TemporaryTableBankCharges.Item AS Item,
	|	TemporaryTableBankCharges.PostingContent AS PostingContent,
	|	TemporaryTableBankCharges.Amount AS Amount,
	|	TemporaryTableBankCharges.AmountCur AS AmountCur,
	|	TemporaryTableBankCharges.ExpenseItem AS ExpenseItem,
	|	TemporaryTableBankCharges.GLAccount AS GLAccount,
	|	TemporaryTableBankCharges.GLExpenseAccount AS GLExpenseAccount
	|INTO TemporaryTableBankCharges
	|FROM
	|	(SELECT
	|		DocumentTable.Date AS Period,
	|		DocumentTable.Company AS Company,
	|		DocumentTable.PresentationCurrency AS PresentationCurrency,
	|		DocumentTable.ToAccount AS BankAccount,
	|		DocumentTable.CashExchange AS CashExchange,
	|		DocumentTable.ToAccountCashCurrency AS Currency,
	|		DocumentTable.BankCharge AS BankCharge,
	|		DocumentTable.ContentBankCommission AS PostingContent,
	|		DocumentTable.BankChargeItem AS Item,
	|		DocumentTable.ExpenseItem AS ExpenseItem,
	|		DocumentTable.BankChargeGLAccount AS GLAccount,
	|		DocumentTable.ReceivingBankFeeCurrency AS AmountCur,
	|		DocumentTable.BankChargeGLExpenseAccount AS GLExpenseAccount,
	|		DocumentTable.ReceivingBankFee AS Amount
	|	FROM
	|		TemporaryTableHeader AS DocumentTable
	|	WHERE
	|		(DocumentTable.ReceivingBankFee <> 0
	|				OR DocumentTable.ReceivingBankFeeCurrency <> 0)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentTable.Date,
	|		DocumentTable.Company,
	|		DocumentTable.PresentationCurrency,
	|		DocumentTable.FromAccount,
	|		DocumentTable.CashExchange,
	|		DocumentTable.FromAccountCashCurrency,
	|		DocumentTable.BankCharge,
	|		DocumentTable.ContentBankCommission,
	|		DocumentTable.BankChargeItem,
	|		DocumentTable.ExpenseItem,
	|		DocumentTable.BankChargeGLAccount,
	|		DocumentTable.SendingBankFeeCurrency,
	|		DocumentTable.BankChargeGLExpenseAccount,
	|		DocumentTable.SendingBankFee
	|	FROM
	|		TemporaryTableHeader AS DocumentTable
	|	WHERE
	|		(DocumentTable.SendingBankFee <> 0
	|				OR DocumentTable.SendingBankFeeCurrency <> 0)) AS TemporaryTableBankCharges
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableBankCharges.Period AS Period,
	|	TemporaryTableBankCharges.Company AS Company,
	|	TemporaryTableBankCharges.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableBankCharges.BankAccount AS BankAccount,
	|	TemporaryTableBankCharges.Currency AS Currency,
	|	TemporaryTableBankCharges.BankCharge AS BankCharge,
	|	TemporaryTableBankCharges.Item AS Item,
	|	TemporaryTableBankCharges.PostingContent AS PostingContent,
	|	TemporaryTableBankCharges.Amount AS Amount,
	|	TemporaryTableBankCharges.AmountCur AS AmountCur
	|FROM
	|	TemporaryTableBankCharges AS TemporaryTableBankCharges";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBankCharges", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableCashAssets(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",					DocumentRefForeignCurrencyExchange);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("CashExpense",			NStr("en = 'Bank payment'; ru = 'Списание со счета';pl = 'Płatność bankowa';es_ES = 'Pago bancario';es_CO = 'Pago bancario';tr = 'Banka ödemesi';it = 'Bonifico bancario';de = 'Überweisung'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	DocumentTable.MainOperationContent AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	CASE
	|		WHEN DocumentTable.CashExchange
	|			THEN VALUE(Catalog.PaymentMethods.Cash)
	|		ELSE VALUE(Catalog.PaymentMethods.Electronic)
	|	END AS PaymentMethod,
	|	CASE
	|		WHEN DocumentTable.CashExchange
	|			THEN VALUE(Enum.CashAssetTypes.Cash)
	|		ELSE VALUE(Enum.CashAssetTypes.Noncash)
	|	END AS CashAssetType,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.ToAccount AS BankAccountPettyCash,
	|	DocumentTable.ToAccountGLAccount AS GLAccount,
	|	DocumentTable.ToAccountCashCurrency AS Currency,
	|	DocumentTable.TotalSending AS Amount,
	|	DocumentTable.ReceivingAmountCurrency AS AmountCur,
	|	DocumentTable.TotalSending AS AmountForBalance,
	|	DocumentTable.ReceivingAmountCurrency AS AmountCurForBalance
	|INTO TemporaryTableCashAssets
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.MainOperationContent,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	CASE
	|		WHEN DocumentTable.CashExchange
	|			THEN VALUE(Catalog.PaymentMethods.Cash)
	|		ELSE VALUE(Catalog.PaymentMethods.Electronic)
	|	END,
	|	CASE
	|		WHEN DocumentTable.CashExchange
	|			THEN VALUE(Enum.CashAssetTypes.Cash)
	|		ELSE VALUE(Enum.CashAssetTypes.Noncash)
	|	END,
	|	DocumentTable.Item,
	|	DocumentTable.FromAccount,
	|	DocumentTable.FromAccountGLAccount,
	|	DocumentTable.FromAccountCashCurrency,
	|	DocumentTable.TotalSending,
	|	DocumentTable.TotalSendingCurrency,
	|	DocumentTable.TotalSending,
	|	DocumentTable.TotalSendingCurrency
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	TableBankCharges.PostingContent,
	|	VALUE(AccumulationRecordType.Expense),
	|	TableBankCharges.Period,
	|	TableBankCharges.Company,
	|	TableBankCharges.PresentationCurrency,
	|	CASE
	|		WHEN TableBankCharges.CashExchange
	|			THEN VALUE(Catalog.PaymentMethods.Cash)
	|		ELSE VALUE(Catalog.PaymentMethods.Electronic)
	|	END,
	|	CASE
	|		WHEN TableBankCharges.CashExchange
	|			THEN VALUE(Enum.CashAssetTypes.Cash)
	|		ELSE VALUE(Enum.CashAssetTypes.Noncash)
	|	END,
	|	TableBankCharges.Item,
	|	TableBankCharges.BankAccount,
	|	TableBankCharges.GLAccount,
	|	TableBankCharges.Currency,
	|	SUM(TableBankCharges.Amount),
	|	SUM(TableBankCharges.AmountCur),
	|	SUM(TableBankCharges.Amount),
	|	SUM(TableBankCharges.AmountCur)
	|FROM
	|	TemporaryTableBankCharges AS TableBankCharges
	|
	|GROUP BY
	|	TableBankCharges.PostingContent,
	|	TableBankCharges.Company,
	|	TableBankCharges.PresentationCurrency,
	|	TableBankCharges.Period,
	|	TableBankCharges.Item,
	|	TableBankCharges.BankAccount,
	|	TableBankCharges.GLAccount,
	|	TableBankCharges.Currency,
	|	CASE
	|		WHEN TableBankCharges.CashExchange
	|			THEN VALUE(Catalog.PaymentMethods.Cash)
	|		ELSE VALUE(Catalog.PaymentMethods.Electronic)
	|	END,
	|	CASE
	|		WHEN TableBankCharges.CashExchange
	|			THEN VALUE(Enum.CashAssetTypes.Cash)
	|		ELSE VALUE(Enum.CashAssetTypes.Noncash)
	|	END
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	PaymentMethod,
	|	CashAssetType,
	|	BankAccountPettyCash,
	|	Currency,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTableCashAssets.Company AS Company,
	|	TemporaryTableCashAssets.PresentationCurrency AS PresentationCurrency, 
	|	TemporaryTableCashAssets.PaymentMethod AS PaymentMethod,
	|	TemporaryTableCashAssets.CashAssetType AS CashAssetType,
	|	TemporaryTableCashAssets.BankAccountPettyCash AS BankAccountPettyCash,
	|	TemporaryTableCashAssets.Currency AS Currency
	|FROM
	|	TemporaryTableCashAssets AS TemporaryTableCashAssets";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.CashAssets");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesCashAssets(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashAssets", ResultsArray[QueryNumber].Unload());
	
EndProcedure

Procedure GenerateTableBankReconciliation(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseBankReconciliation") Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBankReconciliation", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref", DocumentRefForeignCurrencyExchange);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Date AS Period,
	|	&Ref AS Transaction,
	|	DocumentTable.ToAccount AS BankAccount,
	|	VALUE(Enum.BankReconciliationTransactionTypes.Payment) AS TransactionType,
	|	DocumentTable.ReceivingAmountCurrency AS Amount
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	NOT DocumentTable.CashExchange
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Date,
	|	&Ref,
	|	DocumentTable.FromAccount,
	|	VALUE(Enum.BankReconciliationTransactionTypes.Payment),
	|	-DocumentTable.TotalSendingCurrency
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	NOT DocumentTable.CashExchange
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableBankCharges.Period,
	|	&Ref,
	|	TableBankCharges.BankAccount,
	|	VALUE(Enum.BankReconciliationTransactionTypes.Fee),
	|	-SUM(TableBankCharges.AmountCur)
	|FROM
	|	TemporaryTableBankCharges AS TableBankCharges
	|WHERE
	|	NOT TableBankCharges.CashExchange
	|
	|GROUP BY
	|	TableBankCharges.Period,
	|	TableBankCharges.BankAccount";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBankReconciliation", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableIncomeAndExpenses(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	Query.SetParameter("StructuralUnit", StructureAdditionalProperties.ForPosting.StructuralUnit);
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("FXIncomeItem",									Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem",									Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	TableBankCharges.Period AS Period,
	|	TableBankCharges.Company AS Company,
	|	TableBankCharges.PresentationCurrency AS PresentationCurrency,
	|	&StructuralUnit AS StructuralUnit,
	|	UNDEFINED AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	TableBankCharges.ExpenseItem AS IncomeAndExpenseItem,
	|	TableBankCharges.GLExpenseAccount AS GLAccount,
	|	TableBankCharges.PostingContent AS ContentOfAccountingRecord,
	|	0 AS AmountIncome,
	|	TableBankCharges.Amount AS AmountExpense,
	|	TableBankCharges.Amount AS Amount
	|FROM
	|	TemporaryTableBankCharges AS TableBankCharges
	|WHERE
	|	TableBankCharges.Amount <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTableExchangeRateLossesBanking.Date,
	|	TemporaryTableExchangeRateLossesBanking.Company,
	|	TemporaryTableExchangeRateLossesBanking.PresentationCurrency,
	|	&StructuralUnit,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN TemporaryTableExchangeRateLossesBanking.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END,
	|	CASE
	|		WHEN TemporaryTableExchangeRateLossesBanking.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN TemporaryTableExchangeRateLossesBanking.AmountOfExchangeDifferences > 0
	|			THEN TemporaryTableExchangeRateLossesBanking.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN TemporaryTableExchangeRateLossesBanking.AmountOfExchangeDifferences < 0
	|			THEN -TemporaryTableExchangeRateLossesBanking.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	0
	|FROM
	|	TemporaryTableExchangeRateLossesBanking AS TemporaryTableExchangeRateLossesBanking";
		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.ToAccountGLAccount AS AccountDr,
	|	DocumentTable.FromAccountGLAccount AS AccountCr,
	|	CASE
	|		WHEN ToAccountTable.Currency
	|			THEN DocumentTable.ToAccountCashCurrency
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN FromAccountTable.Currency
	|			THEN DocumentTable.FromAccountCashCurrency
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN ToAccountTable.Currency
	|			THEN DocumentTable.ReceivingAmountCurrency
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN FromAccountTable.Currency
	|			THEN DocumentTable.TotalSendingCurrency
	|	END AS AmountCurCr,
	|	DocumentTable.TotalSending AS Amount,
	|	DocumentTable.MainOperationContent AS Content
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS FromAccountTable
	|		ON DocumentTable.FromAccountGLAccount = FromAccountTable.Ref
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS ToAccountTable
	|		ON DocumentTable.ToAccountGLAccount = ToAccountTable.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.BankChargeGLExpenseAccount,
	|	DocumentTable.FromAccountGLAccount,
	|	UNDEFINED,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.Currency
	|			THEN DocumentTable.FromAccountCashCurrency
	|	END,
	|	0,
	|	CASE
	|		WHEN PrimaryChartOfAccounts.Currency
	|			THEN DocumentTable.SendingBankFeeCurrency
	|	END,
	|	DocumentTable.SendingBankFee,
	|	DocumentTable.ContentBankCommission
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON DocumentTable.FromAccountGLAccount = PrimaryChartOfAccounts.Ref
	|WHERE
	|	(DocumentTable.SendingBankFee <> 0
	|			OR DocumentTable.SendingBankFeeCurrency <> 0)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.BankChargeGLExpenseAccount,
	|	DocumentTable.ToAccountGLAccount,
	|	UNDEFINED,
	|	DocumentTable.ToAccountCashCurrency,
	|	0,
	|	DocumentTable.ReceivingBankFeeCurrency,
	|	DocumentTable.ReceivingBankFee,
	|	DocumentTable.ContentBankCommission
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.ReceivingBankFee <> 0
	|			OR DocumentTable.ReceivingBankFeeCurrency <> 0)
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN NOT FromAccountTable.Currency
	|				OR DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN UNDEFINED
	|		ELSE DocumentTable.Currency
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|			THEN -DocumentTable.AmountOfExchangeDifferences
	|		ELSE DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference
	|FROM
	|	TemporaryTableExchangeRateLossesBanking AS DocumentTable
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS FromAccountTable
	|		ON DocumentTable.GLAccount = FromAccountTable.Ref
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	Table.Item AS Item,
	|	0 AS AmountIncome,
	|	Table.Amount AS AmountExpense
	|FROM
	|	TemporaryTableBankCharges AS Table
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND Table.Amount <> 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
