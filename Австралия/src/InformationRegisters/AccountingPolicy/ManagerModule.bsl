#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function AccountingPolicyIsSet(Date, Company) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	TRUE AS IsSet
	|FROM
	|	InformationRegister.AccountingPolicy.SliceLast(&Date, Company = &Company) AS AccountingPolicySliceLast";
	
	Query.SetParameter("Date", Date);
	Query.SetParameter("Company", Company);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function GetAccountingPolicy(Val Date = Undefined, Val Company = Undefined, UseException = True) Export
	
	StructureToReturn = New Structure;
	StructureToReturn.Insert("RegisteredForVAT"							, False);
	StructureToReturn.Insert("DefaultVATRate"							, Undefined);
	StructureToReturn.Insert("CashMethodOfAccounting"					, Undefined);
	StructureToReturn.Insert("InventoryValuationMethod"					, Undefined);
	StructureToReturn.Insert("UseGoodsReturnFromCustomer"				, False);
	StructureToReturn.Insert("UseGoodsReturnToSupplier"					, False);
	StructureToReturn.Insert("PostVATEntriesBySourceDocuments"			, True);
	StructureToReturn.Insert("PostAdvancePaymentsBySourceDocuments"		, False);
	StructureToReturn.Insert("IssueAutomaticallyAgainstSales"			, False);
	StructureToReturn.Insert("StockTransactionsMethodology"				, Undefined);
	StructureToReturn.Insert("ContinentalMethod"						, False);
	StructureToReturn.Insert("ManufacturingOverheadsAllocationMethod"	, Undefined);
	StructureToReturn.Insert("VATRoundingRule"							, Undefined);
	StructureToReturn.Insert("PerInvoiceVATRoundingRule"				, False);
	StructureToReturn.Insert("RegisteredForSalesTax"					, False);
	StructureToReturn.Insert("PostExpensesByWorkOrder"					, False);
	StructureToReturn.Insert("UnderOverAllocatedOverheadsSetting"		, Undefined);
	StructureToReturn.Insert("RegisterDeliveryDateInInvoices"			, False);
	StructureToReturn.Insert("InventoryDispatchingStrategy"				, Undefined);
	StructureToReturn.Insert("AccountingPrice"							, Undefined);
	StructureToReturn.Insert("UseTemplates"								, False);
	
	If Not ValueIsFilled(Company) Then
		Company = DriveReUse.GetValueOfSetting("MainCompany");
	EndIf;
	
	If Not ValueIsFilled(Company) Then
		Company = DriveServer.GetPredefinedCompany();
	EndIf;
	
	If Not ValueIsFilled(Company) Then
		Return StructureToReturn;
	EndIf;
	
	If Not ValueIsFilled(Date) Then
		Date = CurrentSessionDate();
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AccountingPolicySliceLast.DefaultVATRate AS DefaultVATRate,
	|	AccountingPolicySliceLast.RegisteredForVAT AS RegisteredForVAT,
	|	AccountingPolicySliceLast.RegisteredForSalesTax AS RegisteredForSalesTax,
	|	AccountingPolicySliceLast.CashMethodOfAccounting AS CashMethodOfAccounting,
	|	AccountingPolicySliceLast.InventoryValuationMethod AS InventoryValuationMethod,
	|	AccountingPolicySliceLast.UseGoodsReturnFromCustomer AS UseGoodsReturnFromCustomer,
	|	AccountingPolicySliceLast.UseGoodsReturnToSupplier AS UseGoodsReturnToSupplier,
	|	AccountingPolicySliceLast.PostVATEntriesBySourceDocuments AS PostVATEntriesBySourceDocuments,
	|	AccountingPolicySliceLast.PostAdvancePaymentsBySourceDocuments AS PostAdvancePaymentsBySourceDocuments,
	|	AccountingPolicySliceLast.IssueAutomaticallyAgainstSales AS IssueAutomaticallyAgainstSales,
	|	AccountingPolicySliceLast.StockTransactionsMethodology AS StockTransactionsMethodology,
	|	AccountingPolicySliceLast.StockTransactionsMethodology = VALUE(Enum.StockTransactionsMethodology.Continental) AS ContinentalMethod,
	|	AccountingPolicySliceLast.ManufacturingOverheadsAllocationMethod AS ManufacturingOverheadsAllocationMethod,
	|	AccountingPolicySliceLast.VATRoundingRule AS VATRoundingRule,
	|	AccountingPolicySliceLast.VATRoundingRule = VALUE(Enum.VATRoundingRules.PerInvoiceTotal) AS PerInvoiceVATRoundingRule,
	|	AccountingPolicySliceLast.PostExpensesByWorkOrder AS PostExpensesByWorkOrder,
	|	AccountingPolicySliceLast.UnderOverAllocatedOverheadsSetting AS UnderOverAllocatedOverheadsSetting,
	|	AccountingPolicySliceLast.RegisterDeliveryDateInInvoices AS RegisterDeliveryDateInInvoices,
	|	AccountingPolicySliceLast.InventoryDispatchingStrategy AS InventoryDispatchingStrategy,
	|	CASE
	|		WHEN PriceTypes.DeletionMark
	|			THEN VALUE(CAtalog.PriceTypes.Emptyref)
	|		ELSE AccountingPolicySliceLast.AccountingPrice
	|	END AS AccountingPrice,
	|	&UseTemplates AS UseTemplates
	|FROM
	|	InformationRegister.AccountingPolicy.SliceLast(&Date, Company = &Company) AS AccountingPolicySliceLast
	|		LEFT JOIN Catalog.PriceTypes AS PriceTypes
	|		ON AccountingPolicySliceLast.AccountingPrice = PriceTypes.Ref";
	
	Query.SetParameter("Date"			, Date);
	Query.SetParameter("Company"		, Company);
	Query.SetParameter("UseTemplates"	, Constants.AccountingModuleSettings.UseTemplatesIsEnabled());
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The Accounting policy is required for %1.
				|Go to Company > Enterprise > Accounting policy and create the Accounting policy for this company.'; 
				|ru = 'Требуется учетная политика для %1. 
				|Перейдите в Организация > Предприятие > Учетная политика и создайте учетную политику для данной организации.';
				|pl = 'Polityka rachunkowości jest wymagana dla %1.  
				|Przejdź do Firma > Przedsiębiorstwo > Polityka rachunkowości i utwórz Politykę rachunkowości dla tej firmy.';
				|es_ES = 'Se requiere la Política de contabilidad para %1.
				|Vaya a Empresa > Empresa > Política de Contabilidad y cree la Política de Contabilidad para esta empresa.';
				|es_CO = 'Se requiere la Política de contabilidad para %1.
				|Vaya a Empresa > Empresa > Política de Contabilidad y cree la Política de Contabilidad para esta empresa.';
				|tr = '%1 için muhasebe politikası gerekli. 
				|İş yeri > Kurum > Muhasebe politikası bölümünde bu iş yeri için Muhasebe politikası oluşturun.';
				|it = 'La politica contabile è richiesta per %1. 
				|Vai in Azienda > Impresa > Politica contabile e creare la politica contabile per questa azienda.';
				|de = 'Die Bilanzierungsrichtlinien sind für %1 erforderlich.  
				|Gehen Sie zu Firma > Unternehmen > Adressen > Bilanzierungsrichtlinien und erstellen Sie für diese Firma Bilanzierungsrichtlinien.'"),
			Company);
			
		If UseException = True Then
			Raise MessageText;
		ElsIf UseException = False Then
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
	Else
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(StructureToReturn, Selection);
		
	EndIf;
	
	Return StructureToReturn;
	
EndFunction

Function GetDefaultVATRate(Val Date = Undefined, Val Company = Undefined) Export
	
	Policy = GetAccountingPolicy(Date, Company);
	Return DefaultVATRateFromAccountingPolicy(Policy);
	
EndFunction

Function DefaultVATRateFromAccountingPolicy(Policy) Export
	
	Return ?(Policy.DefaultVATRate = Catalogs.VATRates.EmptyRef(), 
		Catalogs.VATRates.Exempt, 
		Policy.DefaultVATRate);
	
EndFunction

Function InventoryValuationMethod(Val Date = Undefined, Val Company = Undefined) Export
	
	Policy = GetAccountingPolicy(Date, Company);
	
	Return Policy.InventoryValuationMethod;
	
EndFunction

Function ContinentalStockTransactionsMethodologyIsEnabled() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE
	|FROM
	|	InformationRegister.AccountingPolicy AS AccountingPolicy
	|WHERE
	|	AccountingPolicy.StockTransactionsMethodology = VALUE(Enum.StockTransactionsMethodology.Continental)";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Function returns the key of the register record.
//
Function GetRecordKey(ParametersStructure) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	AccountingPolicySliceLast.Period AS Period
	|FROM
	|	InformationRegister.AccountingPolicy.SliceLast(&ToDate, Company = &Company) AS AccountingPolicySliceLast";
	
	Query.SetParameter("ToDate", ParametersStructure.Period);
	Query.SetParameter("Company", ParametersStructure.Company);
	
	ReturnStructure = New Structure("RecordExists, Period, Company", False);
	FillPropertyValues(ReturnStructure, ParametersStructure);
	
	ResultTable = Query.Execute().Unload();
	If ResultTable.Count() > 0 Then
		
		ReturnStructure.Period = ResultTable[0].Period;
		ReturnStructure.RecordExists = True;
		
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

Function ModifyDeleteIsAllowed(ParametersData) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	CreditNote.Ref AS Ref
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.Posted
	|	AND CreditNote.Date >= &Period
	|	AND CreditNote.Company IN(&Companies)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	DebitNote.Ref
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.Posted
	|	AND DebitNote.Date >= &Period
	|	AND DebitNote.Company IN(&Companies)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	GoodsReceipt.Ref
	|FROM
	|	Document.GoodsReceipt AS GoodsReceipt
	|WHERE
	|	GoodsReceipt.Posted
	|	AND GoodsReceipt.Date >= &Period
	|	AND GoodsReceipt.Company IN(&Companies)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	GoodsIssue.Ref
	|FROM
	|	Document.GoodsIssue AS GoodsIssue
	|WHERE
	|	GoodsIssue.Posted
	|	AND GoodsIssue.Date >= &Period
	|	AND GoodsIssue.Company IN(&Companies)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	SupplierInvoice.Ref
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Posted
	|	AND SupplierInvoice.Date >= &Period
	|	AND SupplierInvoice.Company IN(&Companies)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	Inventory.Recorder
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Period >= &Period
	|	AND Inventory.Company IN(&Companies)";
	
	Query.SetParameter("Companies",	ParametersData.Companies);
	Query.SetParameter("Period",	ParametersData.Period);
	
	Return Query.Execute().IsEmpty();
	
EndFunction

Function CheckDocumentsAfterSettingPeriod(ParametersData) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	AccountingJournalEntries.Recorder AS Ref
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|WHERE
	|	AccountingJournalEntries.Period >= &Period
	|	AND AccountingJournalEntries.Company IN(&Companies)";
	
	Query.SetParameter("Companies",	ParametersData.Companies);
	Query.SetParameter("Period",	ParametersData.Period);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function AccountingPolicyTableQueryText() Export
	
	QueryText =
	"SELECT
	| *
	|INTO AccountingPolicy
	|FROM
	|	InformationRegister.AccountingPolicy.SliceLast(&Period, Company = &Company) AS AccountingPolicySliceLast";
	
	Return QueryText;
	
EndFunction

Function CheckPeriodOnClosingDates(Company, Date) Export
	
	Source = InformationRegisters.AccountingPolicy.CreateRecordSet();
	Source.Filter.Period.Set(Date);
	Source.Filter.Company.Set(Company);
	SourceRecord = Source.Add();
	SourceRecord.Period = Date;
	SourceRecord.Company = Company;
	
	Cancel = PeriodClosingDates.DataChangesDenied(Source);
	
	Return Cancel;
	
EndFunction

#EndRegion

#EndIf