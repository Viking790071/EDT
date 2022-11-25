#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.CounterpartyContracts);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	User = Users.CurrentUser();
	
	If TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
		If FormType = "ChoiceForm" Then
			StandardProcessing = False;
			SelectedForm = "ChoiceFormForExternalUsers";
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
 	
#Region Private

// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	Result.Add("Owner");
	Result.Add("SettlementsCurrency");
	
	Return Result;
	
EndFunction

// Receives the counterparty contract by default according to the filter conditions. Default or the only contract
// returns or an empty reference.
//
// Parameters
//  Counterparty - <CatalogRef.Counterparties> counterparty, contract of which is needed to get.
//  Company - <CatalogRef.Companies> Company, contract of which is needed to get.
//  ContractKindsList - <Array> or <ValuesList> consisting values
//                      of the type <EnumRef.ContractType>. Desired contract kinds.
//  Currency - <CatalogRef.Currencies> contract currency.
//
// Returns:
//  <CatalogRef.CounterpartyContracts> - found contract or empty ref
//
Function GetDefaultContractByCompanyContractKind(Counterparty,
	Company,
	ContractKindsList = Undefined,
	Currency = Undefined) Export
	
	If NOT ValueIsFilled(Counterparty) Then
		Return Catalogs.CounterpartyContracts.EmptyRef();
	EndIf;
	
	SetPrivilegedMode(True);
	
	CounterpartyAttributes = Common.ObjectAttributesValues(Counterparty, "ContractByDefault, DoOperationsByContracts");
	
	If ValueIsFilled(CounterpartyAttributes.ContractByDefault) Then
		
		ContractAttributes = Common.ObjectAttributesValues(CounterpartyAttributes.ContractByDefault,
			"ContractKind, Company, SettlementsCurrency");
		
		If (NOT ValueIsFilled(ContractKindsList)
			OR ContractKindsList.FindByValue(ContractAttributes.ContractKind) <> Undefined)
			AND (NOT ValueIsFilled(Currency)
			OR ContractAttributes.SettlementsCurrency = Currency)
			AND ContractAttributes.Company = Company Then
			
			Return CounterpartyAttributes.ContractByDefault;
			
		EndIf;
		
	EndIf;
	
	SetPrivilegedMode(False);
	
	Query = New Query;
	QueryText = 
	"SELECT ALLOWED
	|	CounterpartyContracts.Ref
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|WHERE
	|	CounterpartyContracts.Owner = &Counterparty
	|	AND CounterpartyContracts.Company = &Company
	|	AND NOT CounterpartyContracts.DeletionMark
	|	AND &ContractKindsListCondition
	|	AND &CurrencyCondition";
	
	If ValueIsFilled(ContractKindsList) Then
		QueryText = StrReplace(QueryText, "&ContractKindsListCondition", "CounterpartyContracts.ContractKind IN (&ContractKindsList)");
		Query.SetParameter("ContractKindsList", ContractKindsList);
	Else
		QueryText = StrReplace(QueryText, "&ContractKindsListCondition", "TRUE");
	EndIf;
	
	If ValueIsFilled(Currency) Then
		QueryText = StrReplace(QueryText, "&CurrencyCondition", "CounterpartyContracts.SettlementsCurrency = &Currency");
		Query.SetParameter("Currency", Currency);
	Else
		QueryText = StrReplace(QueryText, "&CurrencyCondition", "TRUE");
	EndIf;
	
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Company", Company);
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		
		WithoutContracts = (NOT Constants.UseContractsWithCounterparties.Get()
			OR NOT CounterpartyAttributes.DoOperationsByContracts);
		
		If WithoutContracts Then
			
			Return CreateContractFromCounterparty(Counterparty, Company, WithoutContracts, ContractKindsList, Currency);
			
		Else
			
			Return Catalogs.CounterpartyContracts.EmptyRef();
			
		EndIf;
		
	EndIf;
	
	Selection = Result.Select();
	
	Selection.Next();
	Return Selection.Ref;

EndFunction

// Fills the counterparty contract.
//
// Parameters:
//  Counterparty - <CatalogRef.Counterparty> Counterparty for which is necessary to create a contract
//  Company - <CatalogRef.Companies> Company for which is necessary to create a contract
//  NewContractObject - <CatalogObject.CounterpartyContracts> - contract, which should been filled
//  ContractKindsList - <ValuesList> Consisting values of the type <EnumRef.ContractType>
//  WithoutContracts - <boolean> Work without contracts or not
//  Currency - <CatalogRef.Currencies> contract currency
//
Procedure FillContractFromCounterparty(Counterparty,
	Company,
	NewContractObject,
	WithoutContracts,
	ContractKindsList = Undefined,
	Currency = Undefined) Export
	
	If TypeOf(NewContractObject) <> Type("CatalogObject.CounterpartyContracts") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Counterparties.Ref AS Ref,
	|	Counterparties.BankAccountByDefault AS BankAccountByDefault,
	|	&Company AS Company,
	|	VALUE(Enum.CounterpartyContractStatuses.Active) AS Status,
	|	&Description AS Description,
	|	Counterparties.Customer AS Customer,
	|	Counterparties.Supplier AS Supplier,
	|	Counterparties.OtherRelationship AS OtherRelationship,
	|	Counterparties.CounterpartyBankAccount AS CounterpartyBankAccount,
	|	Counterparties.CashFlowItem AS CashFlowItem,
	|	Counterparties.PriceKind AS PriceKind,
	|	Counterparties.SupplierPriceTypes AS SupplierPriceTypes,
	|	Counterparties.DiscountMarkupKind AS DiscountMarkupKind,
	|	Counterparties.CashAssetType AS CashAssetType,
	|	Counterparties.ProvideEPD AS ProvideEPD,
	|	Counterparties.SettlementsCurrency AS SettlementsCurrency,
	|	Counterparties.PaymentMethod AS PaymentMethod,
	|	Counterparties.CreditLimit AS CreditLimit,
	|	Counterparties.OverdueLimit AS OverdueLimit,
	|	Counterparties.TransactionLimit AS TransactionLimit
	|INTO TempCounterparties
	|FROM
	|	Catalog.Counterparties AS Counterparties
	|WHERE
	|	Counterparties.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempCounterparties.Ref AS Owner,
	|	TempCounterparties.BankAccountByDefault AS BankAccountByDefault,
	|	TempCounterparties.Company AS Company,
	|	TempCounterparties.Status AS Status,
	|	TempCounterparties.Description AS Description,
	|	TempCounterparties.Customer AS Customer,
	|	TempCounterparties.Supplier AS Supplier,
	|	TempCounterparties.OtherRelationship AS OtherRelationship,
	|	TempCounterparties.CounterpartyBankAccount AS CounterpartyBankAccount,
	|	TempCounterparties.CashFlowItem AS CashFlowItem,
	|	TempCounterparties.PriceKind AS PriceKind,
	|	TempCounterparties.SupplierPriceTypes AS SupplierPriceTypes,
	|	TempCounterparties.DiscountMarkupKind AS DiscountMarkupKind,
	|	TempCounterparties.CashAssetType AS CashAssetType,
	|	TempCounterparties.ProvideEPD AS ProvideEPD,
	|	TempCounterparties.SettlementsCurrency AS SettlementsCurrency,
	|	TempCounterparties.PaymentMethod AS PaymentMethod,
	|	TempCounterparties.CreditLimit AS CreditLimit,
	|	TempCounterparties.OverdueLimit AS OverdueLimit,
	|	TempCounterparties.TransactionLimit AS TransactionLimit
	|FROM
	|	TempCounterparties AS TempCounterparties
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CounterpartiesStagesOfPayment.LineNumber AS LineNumber,
	|	CounterpartiesStagesOfPayment.Term AS Term,
	|	CounterpartiesStagesOfPayment.BaselineDate AS BaselineDate,
	|	CounterpartiesStagesOfPayment.DuePeriod AS DuePeriod,
	|	CounterpartiesStagesOfPayment.PaymentPercentage AS PaymentPercentage
	|FROM
	|	Catalog.Counterparties.StagesOfPayment AS CounterpartiesStagesOfPayment
	|		INNER JOIN TempCounterparties AS TempCounterparties
	|		ON CounterpartiesStagesOfPayment.Ref = TempCounterparties.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CounterpartiesEarlyPaymentDiscounts.LineNumber AS LineNumber,
	|	CounterpartiesEarlyPaymentDiscounts.Period AS Period,
	|	CounterpartiesEarlyPaymentDiscounts.Discount AS Discount
	|FROM
	|	Catalog.Counterparties.EarlyPaymentDiscounts AS CounterpartiesEarlyPaymentDiscounts
	|		INNER JOIN TempCounterparties AS TempCounterparties
	|		ON CounterpartiesEarlyPaymentDiscounts.Ref = TempCounterparties.Ref";
	
	Description = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Default contract, %1'; ru = 'Основной договор, %1';pl = 'Kontrakt domyślny, %1';es_ES = 'Contrato por defecto, %1';es_CO = 'Contrato por defecto, %1';tr = 'Varsayılan sözleşme, %1';it = 'Contratto predefinito, %1';de = 'Standardvertrag, %1'"),
		Company);
	
	Query.SetParameter("Ref", Counterparty);
	Query.SetParameter("Description", Description);
	Query.SetParameter("Company", Company);
	
	QueryResult = Query.ExecuteBatch();
	
	CounterpartySelection = QueryResult[1].Select();
	CounterpartySelection.Next();
	
	Attributes = "Owner,Company,Status,Description";
	
	If WithoutContracts Then
		Attributes = Attributes +
			",CounterpartyBankAccount,
			|CashFlowItem,
			|SettlementsCurrency,
			|PriceKind,
			|SupplierPriceTypes,
			|DiscountMarkupKind,
			|CashAssetType,
			|ProvideEPD,
			|PaymentMethod";
	EndIf;
	
	FillPropertyValues(NewContractObject, CounterpartySelection, Attributes);
	
	If CounterpartySelection.Supplier AND NOT CounterpartySelection.Customer Then
		
		NewContractObject.ContractKind = Enums.ContractType.WithVendor;
		
	ElsIf CounterpartySelection.OtherRelationship
		AND NOT CounterpartySelection.Customer
		AND NOT CounterpartySelection.Supplier Then
		
		NewContractObject.ContractKind = Enums.ContractType.Other;
		
	Else
		
		NewContractObject.ContractKind = Enums.ContractType.WithCustomer;
		
	EndIf;
	
	If ContractKindsList <> Undefined Then
		
		If ContractKindsList.Count() > 0 Then
			
			SearchedContractKind = ContractKindsList.FindByValue(NewContractObject.ContractKind);
			If SearchedContractKind = Undefined Then
				NewContractObject.ContractKind = ContractKindsList[0].Value;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(Currency) Then
		NewContractObject.SettlementsCurrency = Currency;
	EndIf;
	
	If NOT ValueIsFilled(NewContractObject.SettlementsCurrency) Then
		NewContractObject.SettlementsCurrency = DriveReUse.GetFunctionalCurrency();
	EndIf;
	
	If NOT ValueIsFilled(NewContractObject.CashFlowItem) Then
		
		If NewContractObject.ContractKind = Enums.ContractType.WithCustomer Then
			NewContractObject.CashFlowItem = Catalogs.CashFlowItems.PaymentFromCustomers;
		ElsIf NewContractObject.ContractKind = Enums.ContractType.WithVendor Then
			NewContractObject.CashFlowItem = Catalogs.CashFlowItems.PaymentToVendor;
		Else
			NewContractObject.CashFlowItem = Catalogs.CashFlowItems.Other;
		EndIf;
		
	EndIf;
	
	If NOT ValueIsFilled(NewContractObject.PriceKind) Then
		NewContractObject.PriceKind = Catalogs.PriceTypes.GetMainKindOfSalePrices();
	EndIf;
	
	If NOT ValueIsFilled(NewContractObject.CounterpartyBankAccount) Then
		NewContractObject.CounterpartyBankAccount = CounterpartySelection.BankAccountByDefault;
	EndIf;
	
	If NOT ValueIsFilled(NewContractObject.Department) Then
		NewContractObject.Department = Catalogs.BusinessUnits.MainDepartment;
	EndIf;
	
	If NOT ValueIsFilled(NewContractObject.BusinessLine) Then
		NewContractObject.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
	EndIf;
	
	If WithoutContracts Then
		
		If NOT ValueIsFilled(NewContractObject.CreditLimit) Then
			NewContractObject.CreditLimit = CounterpartySelection.CreditLimit;
		EndIf;
		
		If NOT ValueIsFilled(NewContractObject.OverdueLimit) Then
			NewContractObject.OverdueLimit = CounterpartySelection.OverdueLimit;
		EndIf;
		
		If NOT ValueIsFilled(NewContractObject.TransactionLimit) Then
			NewContractObject.TransactionLimit = CounterpartySelection.TransactionLimit;
		EndIf;
		
		StagesOfPaymentTable = QueryResult[2].Unload();
		If StagesOfPaymentTable.Count() > 0 Then
			NewContractObject.StagesOfPayment.Load(StagesOfPaymentTable);
		EndIf;
		
		EarlyPaymentDiscountsTable = QueryResult[3].Unload();
		If EarlyPaymentDiscountsTable.Count() > 0 Then
			NewContractObject.EarlyPaymentDiscounts.Load(EarlyPaymentDiscountsTable);
		EndIf;
		
	EndIf;
	
EndProcedure

// Creates the counterparty contract.
//
// Parameters:
//  Counterparty - <CatalogRef.Counterparties> Counterparty for which is necessary to create a contract
//  Company - <CatalogRef.Companies> Company for which is necessary to create a contract
//  WithoutContracts - <boolean> Work without contracts or not
//  ContractKindsList - <ValuesList> Consisting values of the type <EnumRef.ContractType>
//  Currency - <CatalogRef.Currencies> contract currency
//
// Returns:
//  CatalogRef.CounterpartyContracts - created contract
//
Function CreateContractFromCounterparty(Counterparty,
	Company,
	WithoutContracts,
	ContractKindsList,
	Currency)
	
	SetPrivilegedMode(True);
	
	NewContractObject = Catalogs.CounterpartyContracts.CreateItem();
	
	FillContractFromCounterparty(Counterparty, Company, NewContractObject, WithoutContracts, ContractKindsList, Currency);
	
	NewContractObject.Write();
	
	Return NewContractObject.Ref;
	
EndFunction

// Updates the counterparty contracts by billing details from counterparty-owner.
//
// Parameters:
//  Counterparty - CatalogRef.Counterparty Counterparty - owner of the contracts
//
Procedure UpdateContractsFromCounterparty(Counterparty) Export
	
	If NOT ValueIsFilled(Counterparty) Then
		Return;
	EndIf;
	
	DoOperationsByContracts = Common.ObjectAttributeValue(Counterparty, "DoOperationsByContracts");
	
	If NOT Constants.UseContractsWithCounterparties.Get() OR NOT DoOperationsByContracts Then
		
		SetPrivilegedMode(True);
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED
		|	Counterparties.Ref AS Ref,
		|	Counterparties.CounterpartyBankAccount AS CounterpartyBankAccount,
		|	Counterparties.CashFlowItem AS CashFlowItem,
		|	Counterparties.PriceKind AS PriceKind,
		|	Counterparties.SupplierPriceTypes AS SupplierPriceTypes,
		|	Counterparties.DiscountMarkupKind AS DiscountMarkupKind,
		|	Counterparties.CashAssetType AS CashAssetType,
		|	Counterparties.ProvideEPD AS ProvideEPD,
		|	Counterparties.SettlementsCurrency AS SettlementsCurrency,
		|	Counterparties.PaymentMethod AS PaymentMethod,
		|	Counterparties.PaymentTermsTemplate AS PaymentTermsTemplate,
		|	Counterparties.CreditLimit AS CreditLimit,
		|	Counterparties.OverdueLimit AS OverdueLimit,
		|	Counterparties.TransactionLimit AS TransactionLimit,
		|	Counterparties.ApprovePurchaseOrders AS ApprovePurchaseOrders,
		|	Counterparties.LimitWithoutApproval AS LimitWithoutApproval
		|INTO TempCounterparties
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TempCounterparties.Ref AS Owner,
		|	TempCounterparties.CounterpartyBankAccount AS CounterpartyBankAccount,
		|	TempCounterparties.CashFlowItem AS CashFlowItem,
		|	TempCounterparties.PriceKind AS PriceKind,
		|	TempCounterparties.SupplierPriceTypes AS SupplierPriceTypes,
		|	TempCounterparties.DiscountMarkupKind AS DiscountMarkupKind,
		|	TempCounterparties.CashAssetType AS CashAssetType,
		|	TempCounterparties.ProvideEPD AS ProvideEPD,
		|	TempCounterparties.SettlementsCurrency AS SettlementsCurrency,
		|	TempCounterparties.PaymentMethod AS PaymentMethod,
		|	TempCounterparties.PaymentTermsTemplate AS PaymentTermsTemplate,
		|	TempCounterparties.CreditLimit AS CreditLimit,
		|	TempCounterparties.OverdueLimit AS OverdueLimit,
		|	TempCounterparties.TransactionLimit AS TransactionLimit,
		|	TempCounterparties.ApprovePurchaseOrders AS ApprovePurchaseOrders,
		|	TempCounterparties.LimitWithoutApproval AS LimitWithoutApproval
		|FROM
		|	TempCounterparties AS TempCounterparties
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	CounterpartiesStagesOfPayment.LineNumber AS LineNumber,
		|	CounterpartiesStagesOfPayment.Term AS Term,
		|	CounterpartiesStagesOfPayment.BaselineDate AS BaselineDate,
		|	CounterpartiesStagesOfPayment.DuePeriod AS DuePeriod,
		|	CounterpartiesStagesOfPayment.PaymentPercentage AS PaymentPercentage
		|FROM
		|	Catalog.Counterparties.StagesOfPayment AS CounterpartiesStagesOfPayment
		|		INNER JOIN TempCounterparties AS TempCounterparties
		|		ON CounterpartiesStagesOfPayment.Ref = TempCounterparties.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	CounterpartiesEarlyPaymentDiscounts.LineNumber AS LineNumber,
		|	CounterpartiesEarlyPaymentDiscounts.Period AS Period,
		|	CounterpartiesEarlyPaymentDiscounts.Discount AS Discount
		|FROM
		|	Catalog.Counterparties.EarlyPaymentDiscounts AS CounterpartiesEarlyPaymentDiscounts
		|		INNER JOIN TempCounterparties AS TempCounterparties
		|		ON CounterpartiesEarlyPaymentDiscounts.Ref = TempCounterparties.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CounterpartyContracts.Ref AS Ref
		|FROM
		|	Catalog.CounterpartyContracts AS CounterpartyContracts
		|		INNER JOIN TempCounterparties AS TempCounterparties
		|		ON CounterpartyContracts.Owner = TempCounterparties.Ref";
		
		Query.SetParameter("Ref", Counterparty);
		
		QueryResult = Query.ExecuteBatch();
		
		Attributes =
			"CounterpartyBankAccount,
			|CashFlowItem,
			|SettlementsCurrency,
			|PriceKind,
			|SupplierPriceTypes,
			|DiscountMarkupKind,
			|CashAssetType,
			|PaymentMethod,
			|PaymentTermsTemplate,
			|ProvideEPD,
			|ProvideEPD,
			|CreditLimit,
			|OverdueLimit,
			|TransactionLimit,
			|ApprovePurchaseOrders,
			|LimitWithoutApproval";
		
		CounterpartySelection = QueryResult[1].Select();
		If CounterpartySelection.Next() Then
			
			StagesOfPaymentTable		= QueryResult[2].Unload();
			EarlyPaymentDiscountsTable	= QueryResult[3].Unload();
			
			ContractSelection = QueryResult[4].Select();
			While ContractSelection.Next() Do
				
				ContractObject = ContractSelection.Ref.GetObject();
				
				FillPropertyValues(ContractObject, CounterpartySelection, Attributes);
				
				ContractObject.StagesOfPayment.Load(StagesOfPaymentTable);
				ContractObject.EarlyPaymentDiscounts.Load(EarlyPaymentDiscountsTable);
				
				ContractObject.AdditionalProperties.Insert("SkipDefaultContractDeletionMarkCheck", True);
				
				ContractObject.Write();
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Checks the counterparty contract on the map to passed parameters.
//
// Parameters
// MessageText - <String> - error message
// about	errors	Contract - <CatalogRef.CounterpartyContracts> - checked
// contract	Company	- <CatalogRef.Company> - company
// document	Counterparty	- <CatalogRef.Counterparty> - document
// counterparty	ContractKindsList	- <ValuesList> consisting values of the type <EnumRef.ContractType>. 
// 						Desired contract kinds.
//
// Returns:
// <Boolean> -True if checking is completed successfully.
//
Function ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList) Export
	
	MessageText = "";
	
	If Not Counterparty.DoOperationsByContracts Then
		Return True;
	EndIf;
	
	DoesNotMatchCompany = False;
	DoesNotMatchContractKind = False;
	
	If Contract.Company <> Company Then
		DoesNotMatchCompany = True;
	EndIf;
	
	If TypeOf(Contract) = Type("DocumentRef.LoanContract") Then
		ContractKind = Common.ObjectAttributeValue(Contract, "LoanKind");
	Else
		ContractKind = Common.ObjectAttributeValue(Contract, "ContractKind");
	EndIf;
	
	If ContractKindsList.FindByValue(ContractKind) = Undefined Then
		DoesNotMatchContractKind = True;
	EndIf;
	
	If (DoesNotMatchCompany OR DoesNotMatchContractKind) = False Then
		Return True;
	EndIf;
	
	MessageText = NStr("en = 'The following contract fields do not match the document fields:'; ru = 'Реквизиты договора не соответствуют условиям документа:';pl = 'Poniższe pola umowy są niezgodne z polami dokumentu:';es_ES = 'Los siguientes campos de contrato no coinciden con los campos del documento:';es_CO = 'Los siguientes campos de contrato no coinciden con los campos del documento:';tr = 'Aşağıdaki sözleşme alanları belge alanlarıyla eşleşmiyor:';it = 'I seguenti campi del contratto non corrispondono ai campi del documento:';de = 'Die folgenden Vertragsfelder stimmen nicht mit den Dokumentfeldern überein:'");
	
	If DoesNotMatchCompany Then
		MessageText = MessageText + "
									|- " + NStr("en = 'Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'");
	EndIf;
	
	If DoesNotMatchContractKind Then
		MessageText = MessageText + "
									|- " + NStr("en = 'Counterparty role'; ru = 'Тип взаимоотношений';pl = 'Typ kontrahenta';es_ES = 'Rol de la contraparte';es_CO = 'Rol de la contraparte';tr = 'Cari hesap rolü';it = 'Ruolo controparte';de = 'Rolle des Geschäftspartners'");
	EndIf;
	
	Return False;
	
EndFunction

// Returns a list of available contract kinds for the document.
//
// Parameters
// Document  - any document providing counterparty
// contract OperationKind  - document operation kind.
//
// Returns:
// <ValuesList>   - list of contract kinds which are available for the document.
//
Function GetContractTypesListForDocument(Document, OperationKind = Undefined, TabularSectionName = "") Export
	
	ContractKindsList = New ValueList;
	
	If TypeOf(Document) = Type("DocumentRef.OpeningBalanceEntry") Then
		
		If TabularSectionName = "AccountsPayable" Then
			
			ContractKindsList.Add(Enums.ContractType.WithVendor);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
			
		ElsIf TabularSectionName = "AccountsReceivable" Then
			
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
			
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.ArApAdjustments") Then
		
		If TabularSectionName = "Debitor" Then
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
		ElsIf TabularSectionName = "Creditor" Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		Else
			If OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAssignment Then
				ContractKindsList.Add(Enums.ContractType.WithCustomer);
				ContractKindsList.Add(Enums.ContractType.WithAgent);
			Else
				ContractKindsList.Add(Enums.ContractType.WithVendor);
				ContractKindsList.Add(Enums.ContractType.FromPrincipal);
			EndIf;
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.LetterOfAuthority") Then
		
		ContractKindsList.Add(Enums.ContractType.WithVendor);
		ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.AdditionalExpenses") Then
		
		ContractKindsList.Add(Enums.ContractType.WithVendor);
		ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.SalesOrder") Then
		
		If OperationKind = Enums.OperationTypesSalesOrder.OrderForSale Then
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
		Else
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.WorkOrder") Then
		
		ContractKindsList.Add(Enums.ContractType.WithCustomer);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.PurchaseOrder") Then
		
		If OperationKind = Enums.OperationTypesPurchaseOrder.OrderForPurchase Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		Else
			ContractKindsList.Add(Enums.ContractType.WithVendor);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.AccountSalesFromConsignee") Then
		
		ContractKindsList.Add(Enums.ContractType.WithAgent);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.AccountSalesToConsignor") Then
		
		ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.CashReceipt") 
		Or TypeOf(Document) = Type("DocumentRef.PaymentReceipt")
		Or TypeOf(Document) = Type("DocumentRef.OnlineReceipt") Then
		
		If OperationKind = Enums.OperationTypesCashReceipt.FromVendor
			Or OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
			ContractKindsList.Add(Enums.ContractType.SubcontractingServicesReceived);
		ElsIf OperationKind = Enums.OperationTypesCashReceipt.FromCustomer
			Or OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
			ContractKindsList.Add(Enums.ContractType.Other);
			ContractKindsList.Add(Enums.ContractType.SubcontractingServicesProvided);
		Else
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
			ContractKindsList.Add(Enums.ContractType.Other);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.SupplierInvoice") Then
		
		ContractKindsList.Add(Enums.ContractType.WithVendor);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.GoodsReceipt") Then
		
		If OperationKind = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
		ElsIf OperationKind = Enums.OperationTypesGoodsReceipt.SalesReturn Then
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
		ElsIf OperationKind = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty Then
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		ElsIf OperationKind = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty Then
			ContractKindsList.Add(Enums.ContractType.WithAgent);
		ElsIf OperationKind = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractor
			Or OperationKind = Enums.OperationTypesGoodsReceipt.ReturnFromSubcontractor Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
			ContractKindsList.Add(Enums.ContractType.Other);
		ElsIf OperationKind = Enums.OperationTypesGoodsReceipt.ReceiptFromSubcontractingCustomer Then
			ContractKindsList.Add(Enums.ContractType.SubcontractingServicesProvided);
		Else
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.CashVoucher")
		Or TypeOf(Document) = Type("DocumentRef.PaymentExpense")
		Or TypeOf(Document) = Type("DocumentRef.OnlinePayment") Then
		
		If OperationKind = Enums.OperationTypesCashVoucher.Vendor 
			Or OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
			ContractKindsList.Add(Enums.ContractType.SubcontractingServicesReceived);
		ElsIf OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
			Or OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer Then
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
			ContractKindsList.Add(Enums.ContractType.SubcontractingServicesProvided);
		Else
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.SalesInvoice")
		Or TypeOf(Document) = Type("DocumentRef.ActualSalesVolume") Then
		
		ContractKindsList.Add(Enums.ContractType.WithCustomer);
		ContractKindsList.Add(Enums.ContractType.Other);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.GoodsIssue") Then
		
		If OperationKind = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty Then
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		ElsIf OperationKind = Enums.OperationTypesGoodsIssue.TransferToAThirdParty Then
			ContractKindsList.Add(Enums.ContractType.WithAgent);
		ElsIf OperationKind = Enums.OperationTypesGoodsIssue.PurchaseReturn Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
		ElsIf OperationKind = Enums.OperationTypesGoodsIssue.TransferToSubcontractor Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
			ContractKindsList.Add(Enums.ContractType.Other);
		ElsIf OperationKind = Enums.OperationTypesGoodsIssue.ReturnToSubcontractingCustomer
			Or OperationKind = Enums.OperationTypesGoodsIssue.TransferToSubcontractingCustomer Then
			ContractKindsList.Add(Enums.ContractType.SubcontractingServicesProvided);
		Else
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.Quote") Then
		
		ContractKindsList.Add(Enums.ContractType.WithCustomer);
		ContractKindsList.Add(Enums.ContractType.WithAgent);
		ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.SupplierQuote") Then
		
		ContractKindsList.Add(Enums.ContractType.WithVendor);
		ContractKindsList.Add(Enums.ContractType.WithAgent);
		ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.CreditNote") Then
		ContractKindsList.Add(Enums.ContractType.WithCustomer);
	ElsIf TypeOf(Document) = Type("DocumentRef.DebitNote") Then
		ContractKindsList.Add(Enums.ContractType.WithVendor);
	ElsIf TypeOf(Document) = Type("DocumentRef.CustomsDeclaration") Then
		
		If OperationKind = Enums.OperationTypesCustomsDeclaration.Broker Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
		Else
			ContractKindsList.Add(Enums.ContractType.Other);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.RMARequest") Then
		
		ContractKindsList.Add(Enums.ContractType.WithCustomer);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.ReconciliationStatement") Then
		
		ContractKindsList.Add(Enums.ContractType.WithCustomer);
		ContractKindsList.Add(Enums.ContractType.WithVendor);
		ContractKindsList.Add(Enums.ContractType.WithAgent);
		ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		ContractKindsList.Add(Enums.ContractType.Other);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.SubcontractorOrderIssued")
		Or TypeOf(Document) = Type("DocumentRef.SubcontractorInvoiceReceived") Then
		
		ContractKindsList.Add(Enums.ContractType.SubcontractingServicesReceived);
		
	// begin Drive.FullVersion
	
	ElsIf TypeOf(Document) = Type("DocumentRef.SubcontractorOrderReceived")
		Or TypeOf(Document) = Type("DocumentRef.SubcontractorInvoiceIssued") Then
		
		ContractKindsList.Add(Enums.ContractType.SubcontractingServicesProvided);
		
	// end Drive.FullVersion
	
	EndIf;
	
	Return ContractKindsList;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Fills in Sales order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	// Contract
	PrintCommand = PrintCommands.Add();
	PrintCommand.Handler		= "DriveClient.PrintCounterpartyContract";
	PrintCommand.ID				= "ContractForm";
	PrintCommand.Presentation	= NStr("en = 'Contract form'; ru = 'Бланк договора';pl = 'Formularz umowy';es_ES = 'Formulario de contrato';es_CO = 'Formulario de contrato';tr = 'Sözleşme formu';it = 'Modulo contratto';de = 'Vertragsformular'");
	PrintCommand.FormsList		= "ItemForm,ListForm,ChoiceForm,ChoiceFormWithCounterparty";
	PrintCommand.Order			= 1;
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#Region ObjectAttributesLock

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("ContractKind");
	AttributesToLock.Add("ContractType");
	AttributesToLock.Add("Company");
	AttributesToLock.Add("Department");
	AttributesToLock.Add("Responsible");
	AttributesToLock.Add("Owner");
	AttributesToLock.Add("CounterpartyBankAccount");
	AttributesToLock.Add("SettlementsCurrency");
	AttributesToLock.Add("PriceKind");
	AttributesToLock.Add("DiscountMarkupKind");
	AttributesToLock.Add("SupplierPriceTypes");
	AttributesToLock.Add("CashFlowItemByDefault");
	AttributesToLock.Add("BusinessLine");
	AttributesToLock.Add("ShippingAddress");
	AttributesToLock.Add("ApprovePurchaseOrders");
	AttributesToLock.Add("LimitWithoutApproval");
	
	Return AttributesToLock;
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#EndIf