#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes additional properties to post a document.
//
Procedure InitializeAdditionalPropertiesForPosting(DocumentRef, StructureAdditionalProperties) Export
	
	// IN the "AdditionalProperties" structure, properties are created with the "TablesForMovements" "ForPosting"
	// "AccountingPolicy" keys.
	
	// "TablesForMovements" - structure that will contain values table with data for movings execution.
	StructureAdditionalProperties.Insert("TableForRegisterRecords", New Structure);
	
	// "ForPosting" - structure that contains the document properties and attributes required for posting.
	StructureAdditionalProperties.Insert("ForPosting", New Structure);
	
	// Structure containing the key with the "TemporaryTablesManager" name in which value temporary tables manager is stored.
	// Contains key for each temporary table (temporary table name) and value (shows that there are records in the
	// temporary table).
	StructureAdditionalProperties.ForPosting.Insert("StructureTemporaryTables", New Structure("TempTablesManager", New TempTablesManager));
	StructureAdditionalProperties.ForPosting.Insert("DocumentMetadata", DocumentRef.Metadata());
	
	// "AccountingPolicy" - structure that contains all values of the
	// accounting policy parameters for the document time and by the organization selected in the document or by a company
	// (if accounts are kept by a company).
	StructureAdditionalProperties.Insert("AccountingPolicy", New Structure);
	
	// Query that receives document data.
	Query = New Query(
	"SELECT ALLOWED
	|	_Document_.Ref AS Ref,
	|	_Document_.Number AS Number,
	|	_Document_.Date AS Date,
	|	" + ?(StructureAdditionalProperties.ForPosting.DocumentMetadata.Attributes.Find("Company") <> Undefined, "_Document_.Company" , "VALUE(Catalog.Companies.EmptyRef)") + " AS Company,
	|	_Document_.PointInTime AS PointInTime,
	|	_Document_.Presentation AS Presentation
	|FROM
	|	Document." + StructureAdditionalProperties.ForPosting.DocumentMetadata.Name + " AS
	|_Document_
	|	WHERE _Document_.Ref = &DocumentRef");
	
	Query.SetParameter("DocumentRef", DocumentRef);
	
	QueryResult = Query.Execute();
	
	// Generate keys containing document data.
	For Each Column In QueryResult.Columns Do
		
		StructureAdditionalProperties.ForPosting.Insert(Column.Name);
		
	EndDo;
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// Fill in values for keys containing document data.
	FillPropertyValues(StructureAdditionalProperties.ForPosting, QueryResultSelection);
	
	// Define and set point value for which document control should be executed.
	StructureAdditionalProperties.ForPosting.Insert("ControlTime", Date('00010101'));
	StructureAdditionalProperties.ForPosting.Insert("ControlPeriod", Date("39991231"));
		
	// Company setting in case of entering accounting by the company.
	StructureAdditionalProperties.ForPosting.Company = DriveServer.GetCompany(StructureAdditionalProperties.ForPosting.Company);
	
	StructureAdditionalProperties.ForPosting.Insert("PresentationCurrency",
													?(StructureAdditionalProperties.ForPosting.Company = Catalogs.Companies.EmptyRef(),
													Catalogs.Currencies.EmptyRef(),
													DriveServer.GetPresentationCurrency(StructureAdditionalProperties.ForPosting.Company)));
	
	StructureAdditionalProperties.ForPosting.Insert("ExchangeRateMethod", DriveServer.GetExchangeMethod(StructureAdditionalProperties.ForPosting.Company));
	
	// Setting allow empty records in dimensions of accumulation registers
	StructureAdditionalProperties.ForPosting.Insert("AllowEmptyRecords", GetAllowEmptyRecords(StructureAdditionalProperties.ForPosting.DocumentMetadata, DocumentRef));
	
	// Query receiving accounting policy data.
	Query = New Query(
	"SELECT ALLOWED
	|	Constants.UseProjects AS UseProjects,
	|	Constants.UseStorageBins AS UseStorageBins,
	|	Constants.UseBatches AS UseBatches,
	|	Constants.UseCharacteristics AS UseCharacteristics,
	|	Constants.UseOperationsManagement AS UseOperationsManagement,
	|	Constants.UseSerialNumbers AS UseSerialNumbers,
	|	Constants.UseSerialNumbersAsInventoryRecordDetails AS SerialNumbersBalance,
	|	Constants.UseFIFO AS UseFIFO,
	|	Constants.AccountingModuleSettings AS AccountingModuleSettings,
	|	Constants.UseDefaultTypeOfAccounting AS UseDefaultTypeOfAccounting,
	|	Constants.AccountingModuleSettings = VALUE(Enum.AccountingModuleSettingsTypes.UseTemplateBasedTypesOfAccounting) AS UseTemplateBasedTypesOfAccounting,
	|	ISNULL(AccountingPolicySliceLast.RegisteredForVAT, FALSE) AS RegisteredForVAT,
	|	ISNULL(AccountingPolicySliceLast.RegisteredForSalesTax, FALSE) AS RegisteredForSalesTax,
	|	ISNULL(AccountingPolicySliceLast.CashMethodOfAccounting, FALSE) AS IncomeAndExpensesAccountingCashMethod,
	|	ISNULL(AccountingPolicySliceLast.PostAdvancePaymentsBySourceDocuments, FALSE) AS PostAdvancePaymentsBySourceDocuments,
	|	ISNULL(AccountingPolicySliceLast.PostVATEntriesBySourceDocuments, TRUE) AS PostVATEntriesBySourceDocuments,
	|	ISNULL(AccountingPolicySliceLast.IssueAutomaticallyAgainstSales, FALSE) AS IssueAutomaticallyAgainstSales,
	|	ISNULL(AccountingPolicySliceLast.UseGoodsReturnFromCustomer, 0) AS UseGoodsReturnFromCustomer,
	|	ISNULL(AccountingPolicySliceLast.UseGoodsReturnToSupplier, 0) AS UseGoodsReturnToSupplier,
	|	ISNULL(AccountingPolicySliceLast.InventoryValuationMethod, 0) AS InventoryValuationMethod,
	|	ISNULL(AccountingPolicySliceLast.PostExpensesByWorkOrder, FALSE) AS PostExpensesByWorkOrder,
	|	AccountingPolicySliceLast.StockTransactionsMethodology = VALUE(Enum.StockTransactionsMethodology.Continental) AS ContinentalMethod,
	|	AccountingPolicySliceLast.UnderOverAllocatedOverheadsSetting AS UnderOverAllocatedOverheadsSetting
	|FROM
	|	Constants AS Constants
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, Company = &Company) AS AccountingPolicySliceLast
	|		ON (TRUE)");
	Query.SetParameter("Company",	StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Date",		StructureAdditionalProperties.ForPosting.Date);
	
	QueryResult = Query.Execute();
	
	// Generate keys containing accounting policy data.
	For Each Column In QueryResult.Columns Do
		StructureAdditionalProperties.AccountingPolicy.Insert(Column.Name);
	EndDo;
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// Fill out values of the keys that contain the accounting policy data.
	FillPropertyValues(StructureAdditionalProperties.AccountingPolicy, QueryResultSelection);
	
EndProcedure

Function GetAllowEmptyRecords(DocumentMetadata, DocumentRef)
	
	Result = False;
	
	If DocumentMetadata = Metadata.Documents.SupplierInvoice 
		And Common.ObjectAttributeValue(DocumentRef, "OperationKind") = Enums.OperationTypesSupplierInvoice.ZeroInvoice Then
		
		Result = True;
		
	ElsIf DocumentMetadata = Metadata.Documents.SalesInvoice
		And Common.ObjectAttributeValue(DocumentRef, "OperationKind") = Enums.OperationTypesSalesInvoice.ZeroInvoice Then
		
		Result = True;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndIf