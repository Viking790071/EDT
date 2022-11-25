#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	User = SessionParameters.CurrentExternalUser;
	
	If ValueIsFilled(User) Then
		
		AuthorizationObject = Common.ObjectAttributeValue(User, "AuthorizationObject");
		
		If TypeOf(AuthorizationObject) = Type("CatalogRef.Counterparties") Then
			Counterparty = AuthorizationObject;
		ElsIf TypeOf(AuthorizationObject) = Type("CatalogRef.ContactPersons") Then
			Counterparty = Common.ObjectAttributeValue(AuthorizationObject, "Owner");
		EndIf;
		
	EndIf;
	
	FillBalances();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Refresh(Command)

	FillBalances();

EndProcedure

&AtClient
Procedure PrepaymentsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	GenerateReportCustomerBalance();
	
EndProcedure

&AtClient
Procedure DebtClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	GenerateReportCustomerBalance();
	
EndProcedure

&AtClient
Procedure CurrentBalanceClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	GenerateReportCustomerBalance();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure GenerateReportCustomerBalance()
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey"						, "Balance");
	FormParameters.Insert("PurposeUseKey"					, "BalanceByCounterparty");
	FormParameters.Insert("Filter"							, New Structure("Counterparty", Counterparty));
	FormParameters.Insert("GenerateOnOpen"					, True);
	FormParameters.Insert("ReportOptionsCommandsVisibility"	, True);
	
	OpenForm("Report.CustomerStatement.Form",
		FormParameters,
		ThisForm,
		UUID);
		
EndProcedure

&AtServer
Procedure FillBalances()
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.PresentationCurrency AS PresentationCurrency,
	|	SUM(CASE
	|			WHEN AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|				THEN AccountsReceivableBalances.AmountBalance
	|			ELSE 0
	|		END) AS AmountBalanceDebt,
	|	SUM(CASE
	|			WHEN AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|				THEN -AccountsReceivableBalances.AmountBalance
	|			ELSE 0
	|		END) AS AmountBalanceAdvance,
	|	SUM(CASE
	|			WHEN AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|				THEN CASE
	|						WHEN AccountsReceivableBalances.AmountBalance > AccountsReceivableBalances.AmountForPaymentBalance
	|							THEN AccountsReceivableBalances.AmountBalance
	|						ELSE AccountsReceivableBalances.AmountForPaymentBalance
	|					END
	|			ELSE 0
	|		END - CASE
	|			WHEN AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|				THEN -AccountsReceivableBalances.AmountBalance
	|			ELSE 0
	|		END) AS AmountBalanceSettlements
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(, Counterparty = &Counterparty) AS AccountsReceivableBalances
	|		LEFT JOIN InformationRegister.UsingPaymentTermsInDocuments AS UsingPaymentTermsInDocuments
	|		ON AccountsReceivableBalances.Document = UsingPaymentTermsInDocuments.Document
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsReceivableBalances.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON AccountsReceivableBalances.Counterparty = Counterparties.Ref
	|WHERE
	|	CASE
	|			WHEN &UseContractRestrictionsTurnOff
	|				THEN TRUE
	|			WHEN Counterparties.DoOperationsByContracts
	|					AND CounterpartyContracts.VisibleToExternalUsers
	|				THEN TRUE
	|			WHEN NOT Counterparties.DoOperationsByContracts
	|				THEN TRUE
	|			ELSE FALSE
	|		END
	|
	|GROUP BY
	|	AccountsReceivableBalances.Counterparty,
	|	AccountsReceivableBalances.PresentationCurrency";
	
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("UseContractRestrictionsTurnOff", Not GetFunctionalOption("UseContractRestrictionsForExternalUsers"));
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		CurrentBalance	= Selection.AmountBalanceSettlements;
		Debt			= Selection.AmountBalanceDebt;
		Prepayments		= Selection.AmountBalanceAdvance;
		
		BalanceCurrency		= Selection.PresentationCurrency;
		DebtCurrency		= Selection.PresentationCurrency;
		PrepaymentCurrency	= Selection.PresentationCurrency;
		
	Else
		
		CurrentBalance	= 0;
		Debt			= 0;
		Prepayments		= 0;
		
		BalanceCurrency		= Undefined;
		DebtCurrency		= Undefined;
		PrepaymentCurrency	= Undefined;
		
	EndIf;
	
EndProcedure

#EndRegion