
#Region ServiceProceduresAndFunctions

// Check usage the option "Post VAT entries by source documents".
//
// Parameters:
//	Date - Date - Date for check
//	Company - CatalogRef.Companies - Company for check
//
// Returned value:
//	Boolean - shows the option value
//
Function GetUseTaxInvoiceForPostingVAT(Date, Company) Export
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	
	Return NOT Policy.PostVATEntriesBySourceDocuments;
	
EndFunction

// Check usage the option "Post advance payments by source documents".
//
// Parameters:
//	Date - Date - Date for check
//	Company - CatalogRef.Companies - Company for check
//
// Returned value:
//	Boolean - shows the option value
//
Function GetPostAdvancePaymentsBySourceDocuments(Date, Company) Export
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	
	Return Policy.PostAdvancePaymentsBySourceDocuments;
	
EndFunction

// Check usage the option "Issue automatically against sales".
//
// Parameters:
//	Date - Date - Date for check
//	Company - CatalogRef.Companies - Company for check
//
// Returned value:
//	Boolean - shows the option value
//
Function GetIssueAutomaticallyAgainstSales(Date, Company) Export
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	
	Return Policy.IssueAutomaticallyAgainstSales;
	
EndFunction

Function GetVATPreparationQueryText() Export
	
	Return 
	"SELECT
	|	UnionTable.Document,
	|	UnionTable.VATRate,
	|	UnionTable.Period,
	|	UnionTable.Company,
	|	UnionTable.CompanyVATNumber,
	|	UnionTable.PresentationCurrency,
	|	UnionTable.ProductsType,
	|	UnionTable.Counterparty,
	|	UnionTable.VATInputGLAccount,
	|	UnionTable.VATOutputGLAccount,
	|	SUM(UnionTable.VATAmount) AS VATAmount,
	|	SUM(UnionTable.AmountExcludesVAT) AS AmountExcludesVAT
	|INTO TTVATPreparation
	|FROM
	|	(SELECT
	|		TemporaryTableInventory.VATRate AS VATRate,
	|		TemporaryTableInventory.VATAmount AS VATAmount,
	|		TemporaryTableInventory.Amount - TemporaryTableInventory.VATAmount AS AmountExcludesVAT,
	|		TemporaryTableInventory.Document AS Document,
	|		TemporaryTableInventory.Period AS Period,
	|		TemporaryTableInventory.Company AS Company,
	|		TemporaryTableInventory.CompanyVATNumber AS CompanyVATNumber,
	|		TemporaryTableInventory.PresentationCurrency AS PresentationCurrency,
	|		TemporaryTableInventory.ProductsType AS ProductsType,
	|		TemporaryTableInventory.Counterparty AS Counterparty,
	|		TemporaryTableInventory.VATInputGLAccount,
	|		TemporaryTableInventory.VATOutputGLAccount
	|	FROM
	|		TemporaryTableInventory AS TemporaryTableInventory
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TemporaryTableExpenses.VATRate,
	|		TemporaryTableExpenses.VATAmount,
	|		TemporaryTableExpenses.Amount - TemporaryTableExpenses.VATAmount,
	|		TemporaryTableExpenses.Document,
	|		TemporaryTableExpenses.Period,
	|		TemporaryTableExpenses.Company,
	|		TemporaryTableExpenses.CompanyVATNumber,
	|		TemporaryTableExpenses.PresentationCurrency,
	|		TemporaryTableExpenses.ProductsType AS ProductsType,
	|		TemporaryTableExpenses.Counterparty,
	|		TemporaryTableExpenses.VATInputGLAccount,
	|		TemporaryTableExpenses.VATOutputGLAccount
	|	FROM
	|		TemporaryTableExpenses AS TemporaryTableExpenses) AS UnionTable
	|
	|GROUP BY
	|	UnionTable.VATRate,
	|	UnionTable.Document,
	|	UnionTable.Period,
	|	UnionTable.Company,
	|	UnionTable.CompanyVATNumber,
	|	UnionTable.PresentationCurrency,
	|	UnionTable.ProductsType,
	|	UnionTable.Counterparty,
	|	UnionTable.VATInputGLAccount,
	|	UnionTable.VATOutputGLAccount" + DriveClientServer.GetQueryDelimeter();
	
EndFunction

Procedure ForbidReverseChargeTaxationTypeDocumentGeneration(DocumentObject) Export
	
	If DocumentObject.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Reverse charge is not applicable for ""%1"".'; ru = 'Реверсивный НДС не применяется для ""%1"".';pl = 'Odwrotne obciążenie nie ma zastosowania dla ""%1"".';es_ES = 'Inversión impositiva no se aplica para ""%1"".';es_CO = 'Inversión impositiva no se aplica para ""%1"".';tr = 'Karşı ödemeli ücret ""%1"" için geçerli değildir.';it = 'L''inversione di caricamento non è applicabile per ""%1"".';de = 'Für ""%1"" gilt keine Steuerschuldumkehr.'"),
			DocumentObject.Metadata().Presentation());
		
		Raise MessageText;
		
	EndIf;
	
EndProcedure

Function VATTaxationTypeIsValid(VATTaxationType, RegisteredForVAT, ReverseChargeNotApplicable) Export
	
	Return Not (VATTaxationType = Enums.VATTaxationTypes.SubjectToVAT And Not RegisteredForVAT
				Or VATTaxationType = Enums.VATTaxationTypes.ReverseChargeVAT And ReverseChargeNotApplicable);
	
EndFunction

Function CalculateVATPerInvoiceTotal(DocumentObject, Parameters = Undefined) Export
	
	If Parameters = Undefined Then
		Parameters = New Structure;
	EndIf;
	
	If Not (DocumentObject.AutomaticVATCalculation
		And (DocumentObject.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT
				Or DocumentObject.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT
					And Parameters.Property("ReverseChargeVATIsCalculated")
					And Parameters.ReverseChargeVATIsCalculated)) Then
		Return False;
	EndIf;
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(
		DocumentObject.Date, DocumentObject.Company);
	
	If Not AccountingPolicy.PerInvoiceVATRoundingRule Then
		DocumentObject.AutomaticVATCalculation = False;
		Return False;
	EndIf;
	
	If Not Parameters.Property("TabularSectionNames") Then
		TabularSectionNames = New Array;
		If Parameters.Property("TabularSectionName") Then
			TabularSectionNames.Add(Parameters.TabularSectionName);
		Else
			TabularSectionNames.Add("Inventory");
		EndIf;
		Parameters.Insert("TabularSectionNames", TabularSectionNames);
	EndIf;
	If Not Parameters.Property("Filter") Then
		Parameters.Insert("Filter", Undefined);
	EndIf;
	If Not Parameters.Property("AmountIncludesVAT") Then
		Parameters.Insert("AmountIncludesVAT", DocumentObject.AmountIncludesVAT);
	EndIf;
	If Not Parameters.Property("ShowMessages") Then
		Parameters.Insert("ShowMessages", True);
	EndIf;
	If Not Parameters.Property("VATRateName") Then
		Parameters.Insert("VATRateName", "VATRate");
	EndIf;
	If Not Parameters.Property("VATAmountName") Then
		Parameters.Insert("VATAmountName", "VATAmount");
	EndIf;
	If Not Parameters.Property("AdditionalAmountName") Then
		Parameters.Insert("AdditionalAmountName", "");
	EndIf;
	If Not Parameters.Property("RecalculateTotal") Then
		Parameters.Insert("RecalculateTotal", True);
	EndIf;
	
	ColumsString = StringFunctionsClientServer.SubstituteParametersToString(
		"LineNumber, Amount, Total, %1, %2",
		Parameters.VATRateName,
		Parameters.VATAmountName);
	TabularSection = DocumentObject[Parameters.TabularSectionNames[0]].UnloadColumns(ColumsString);
	TabularSection.Columns.Add("TabularSectionName");
	
	For Each TabularSectionName In Parameters.TabularSectionNames Do
		If Parameters.Filter = Undefined Then
			CurrentTabularSection = DocumentObject[TabularSectionName].Unload();
		Else
			CurrentTabularSection = DocumentObject[TabularSectionName].Unload(Parameters.Filter);
		EndIf;
		For Each CTSRow In CurrentTabularSection Do
			TSRow = TabularSection.Add();
			FillPropertyValues(TSRow, CTSRow);
			TSRow.TabularSectionName = TabularSectionName;
			If Not IsBlankString(Parameters.AdditionalAmountName)
				And Not CurrentTabularSection.Columns.Find(Parameters.AdditionalAmountName) = Undefined Then
				TSRow.Amount = TSRow.Amount + CTSRow[Parameters.AdditionalAmountName];
			EndIf;
		EndDo;
	EndDo;
	
	VATAmountBeforeApplying = TabularSection.Total(Parameters.VATAmountName);
	TotalBeforeApplying = TabularSection.Total("Total");
	
	ColumsString = StringFunctionsClientServer.SubstituteParametersToString(
		"Amount, %1, %2",
		Parameters.VATRateName,
		Parameters.VATAmountName);
	TotalsByRates = TabularSection.Copy( , ColumsString);
	ColumsString = StringFunctionsClientServer.SubstituteParametersToString(
		"Amount, %1",
		Parameters.VATAmountName);
	TotalsByRates.GroupBy(Parameters.VATRateName, ColumsString);
	
	For Each RatesRow In TotalsByRates Do
		
		NewTotalVATAmount = CalculateVATAmount(RatesRow, 2, Parameters);
		
		If RatesRow[Parameters.VATAmountName] = NewTotalVATAmount Then
			Continue;
		EndIf;
		
		ColumsString = StringFunctionsClientServer.SubstituteParametersToString(
			"TabularSectionName, LineNumber, Amount, Total, %1, %2",
			Parameters.VATRateName,
			Parameters.VATAmountName);
		CurrentRateRows = TabularSection.Copy(
			New Structure(Parameters.VATRateName, RatesRow[Parameters.VATRateName]),
			ColumsString);
		
		CurrentRateRows.Sort("Amount, TabularSectionName, LineNumber");
		
		RoundingError = 0;
		SourceRow = Undefined;
		
		For Each Row In CurrentRateRows Do
			
			VATAmountPrecise = CalculateVATAmount(Row, 27, Parameters);
			Row[Parameters.VATAmountName] = Round(VATAmountPrecise + RoundingError, 2);
			
			SourceRow = DocumentObject[Row.TabularSectionName][Row.LineNumber - 1];
			SourceRow[Parameters.VATAmountName] = Row[Parameters.VATAmountName];
			If Not Parameters.AmountIncludesVAT And Parameters.RecalculateTotal Then
				SourceRow.Total = SourceRow.Amount + SourceRow[Parameters.VATAmountName];
			EndIf;
			
			RoundingError = VATAmountPrecise + RoundingError - Row[Parameters.VATAmountName];
			
		EndDo;
		
		ActualNewTotalVATAmount = CurrentRateRows.Total(Parameters.VATAmountName);
		If ActualNewTotalVATAmount <> NewTotalVATAmount
			And SourceRow <> Undefined Then
			
			SourceRow[Parameters.VATAmountName] = SourceRow[Parameters.VATAmountName] + NewTotalVATAmount - ActualNewTotalVATAmount;
			If Not Parameters.AmountIncludesVAT Then
				SourceRow.Total = SourceRow.Amount + SourceRow[Parameters.VATAmountName];
			EndIf;
			
		EndIf;
		
	EndDo;
	
	TabularSection.Clear();
	For Each TabularSectionName In Parameters.TabularSectionNames Do
		If Parameters.Filter = Undefined Then
			CurrentTabularSection = DocumentObject[TabularSectionName].Unload();
		Else
			CurrentTabularSection = DocumentObject[TabularSectionName].Unload(Parameters.Filter);
		EndIf;
		CommonClientServer.SupplementTable(CurrentTabularSection, TabularSection);
	EndDo;
	
	VATAmountAfterApplying = TabularSection.Total(Parameters.VATAmountName);
	TotalAfterApplying = TabularSection.Total("Total");
	
	If Parameters.ShowMessages Then
		
		If VATAmountBeforeApplying <> VATAmountAfterApplying Then
			
			MessageText = NStr("en = 'The result of applying ""Per invoice total"" VAT rounding rule
								|for ""%1"" section(s):'; 
								|ru = 'Результат применения правила округления НДС ""В сумме инвойса""
								|для ""%1"" раздела(ов):';
								|pl = 'Wynik stosowania reguły zaokrąglenia VAT ""Faktura ogółem"" 
								|dla ""%1"" sekcji:';
								|es_ES = 'Resultado de aplicar la regla de redondeo del IVA ""Por total de factura""
								|para""%1"" sección(es):';
								|es_CO = 'Resultado de aplicar la regla de redondeo del IVA ""Por total de factura""
								|para""%1"" sección(es):';
								|tr = '""%1"" bölümleri için ""Fatura başına toplam"" KDV yuvarlama kuralı 
								| uygulamasının sonucu:';
								|it = 'Il risultato dell''applicazione regola arrotondamento IVA ""Per totale fattura""
								|per la sezione/i ""%1%:';
								|de = 'Das Ergebnis der Anwendung der USt-Rundungsregel
								|""Pro Rechnungsbetrag"" für den/die Abschnitt(e) ""%1"":'");
			DocMetadata = DocumentObject.Metadata();
			TabularSectionPresentationArray = New Array;
			For Each TabularSectionName In Parameters.TabularSectionNames Do
				TabularSectionMetadata = DocMetadata.TabularSections[TabularSectionName];
				TabularSectionPresentationArray.Add(TabularSectionMetadata.Presentation());
			EndDo;
			TabularSectionPresentation = StringFunctionsClientServer.StringFromSubstringArray(
				TabularSectionPresentationArray, ", ");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageText,
				TabularSectionPresentation);
			CommonClientServer.MessageToUser(MessageText, DocumentObject);
			
			MessageText = NStr("en = 'VAT before %1 %3, after %2 %3'; ru = 'НДС перед %1 %3, после %2 %3';pl = 'VAT przed %1 %3, po %2 %3';es_ES = 'IVA antes de%1 %3, después de%2 %3';es_CO = 'IVA antes de%1 %3, después de%2 %3';tr = '%1 %3 öncesi, %2 %3 sonrası KDV';it = 'IVA prima %1 %3, dopo %2 %3 ';de = 'USt. vor %1 %3, nach %2 %3'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageText,
				VATAmountBeforeApplying,
				VATAmountAfterApplying,
				DocumentObject.DocumentCurrency);
			CommonClientServer.MessageToUser(MessageText, DocumentObject);
			
			If TotalBeforeApplying <> TotalAfterApplying Then
				
				MessageText = NStr("en = 'Total before %1 %3, after %2 %3'; ru = 'Итого перед %1 %3, после %2 %3';pl = 'Łącznie przed %1 %3, po%2 %3';es_ES = 'Total antes de %1 %3, después de %2 %3';es_CO = 'Total antes de %1 %3, después de %2 %3';tr = '%1 %3 öncesi, %2 %3 sonrası Toplam';it = 'Totale prima %1 %3, dopo %2 %3';de = 'Summe vor %1 %3, nach %2 %3'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					MessageText,
					TotalBeforeApplying,
					TotalAfterApplying,
					DocumentObject.DocumentCurrency);
				CommonClientServer.MessageToUser(MessageText, DocumentObject);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return (VATAmountBeforeApplying <> VATAmountAfterApplying
			Or TotalBeforeApplying <> TotalAfterApplying);
	
EndFunction

Function CalculateVATAmount(Row, DigitCapacity, Parameters)
	
	VATRate = DriveReUse.GetVATRateValue(Row[Parameters.VATRateName]);
	If Parameters.AmountIncludesVAT Then
		Return Round(Row.Amount * VATRate / (VATRate + 100), DigitCapacity);
	Else
		Return Round(Row.Amount * VATRate / 100, DigitCapacity);
	EndIf;
	
EndFunction

// Collects VAT IDs of the selected company, generates VAT choice list and fills the VAT attribute if necessary
//
Procedure ProcessingCompanyVATNumbers(Object, Item, FillOnlyEmpty = True) Export
	
	If TypeOf(Item) = Type("FormField") Then
		IsFormField = True;
	ElsIf TypeOf(Item) = Type("String") Then
		IsFormField = False;
	Else	
		Return;
	EndIf;
	
	AttributeName = ?(IsFormField, StrReplace(Item.DataPath, "Object.", ""), Item);
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Object.Company, Object.Date) Then
		
		If Not IsBlankString(Object[AttributeName]) Then
			Object[AttributeName] = "";
		EndIf;
		
		SetCompanyVATNumberItemVisible(Item, False);
		Return;
		
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	CompaniesVATNumbers.VATNumber AS VATNumber,
	|	CompaniesVATNumbers.RegistrationCountry AS RegistrationCountry,
	|	CompaniesVATNumbers.VATNumber = Companies.VATNumber AS DefaultVATNumber
	|FROM
	|	Catalog.Companies.VATNumbers AS CompaniesVATNumbers
	|		INNER JOIN Catalog.Companies AS Companies
	|		ON CompaniesVATNumbers.Ref = Companies.Ref
	|WHERE
	|	CompaniesVATNumbers.Ref = &Company
	|	AND (CompaniesVATNumbers.RegistrationDate <= &ObjectDate
	|			OR CompaniesVATNumbers.RegistrationDate = &BlankDate)
	|	AND (CompaniesVATNumbers.RegistrationValidTill >= &ObjectDate
	|			OR CompaniesVATNumbers.RegistrationValidTill = &BlankDate)
	|
	|ORDER BY
	|	DefaultVATNumber DESC";
	
	Query.SetParameter("ObjectDate", ?(ValueIsFilled(Object.Date), Object.Date, CurrentSessionDate()));
	Query.SetParameter("BlankDate", Date(1,1,1));
	Query.SetParameter("Company", Object.Company);
	
	CompaniesVATNumbers = Query.Execute().Unload();
	VATNumbersCount = CompaniesVATNumbers.Count();
	
	If Not ValueIsFilled(Object[AttributeName]) 
		Or CompaniesVATNumbers.Find(Object[AttributeName]) = Undefined
		Or FillOnlyEmpty = False Then
		
		Object[AttributeName] = ?(VATNumbersCount = 0, "", CompaniesVATNumbers[0].VATNumber);
		
	EndIf;
	
	If Not IsFormField Then
		Return;
	EndIf;
		
	If VATNumbersCount < 2 Then
		SetCompanyVATNumberItemVisible(Item, False);
		Return;
	EndIf;
	
	If WorkWithVATServerCall.MultipleVATNumbersAreUsed() = False Then
		SetCompanyVATNumberItemVisible(Item, False);
		Return;
	EndIf;
	
	Item.ChoiceList.Clear();
	
	For Index = 0 To VATNumbersCount - 1 Do
		
		CurrentVATNumber = CompaniesVATNumbers[Index];
		
		NewListItem = Item.ChoiceList.Add();
		NewListItem.Presentation = CurrentVATNumber.VATNumber + ", " + CurrentVATNumber.RegistrationCountry;
		NewListItem.Value = CurrentVATNumber.VATNumber;
		
	EndDo;
		
	SetCompanyVATNumberItemVisible(Item, True);

EndProcedure

Function GetVATAmountFromBasisDocument(Object) Export
	
	VATAmount = 0;
	
	If Not ValueIsFilled(Object.BasisDocument)
		Or Not Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT 
		Or TypeOf(Object.BasisDocument) = Type("DocumentRef.LoanContract") Then
		
		Return VATAmount;
	EndIf;
	
	TableSectionsData = New Structure;
	TableSectionsData.Insert("Inventory", "Amount, VATAmount");
	TableSectionsData.Insert("FixedAssets", "Amount, VATAmount");
	TableSectionsData.Insert("Works", "Amount, VATAmount");
	TableSectionsData.Insert("SalesTax", ", Amount");
	
	If TypeOf(Object.BasisDocument) = Type("DocumentRef.SubcontractorOrderIssued")
		Or TypeOf(Object.BasisDocument) = Type("DocumentRef.SubcontractorInvoiceReceived") 
		// begin Drive.FullVersion
		Or TypeOf(Object.BasisDocument) = Type("DocumentRef.SubcontractorOrderReceived") 
		Or TypeOf(Object.BasisDocument) = Type("DocumentRef.SubcontractorInvoiceIssued")
		// end Drive.FullVersion 
		Then
		
		TableSectionsData.Insert("Products", "Amount, VATAmount");
		TableSectionsData.Delete("Inventory");
	EndIf;
	
	QueryText = "";
	BasisDocMetadata = Object.BasisDocument.Metadata();
	For Each Data In TableSectionsData Do
		
		If BasisDocMetadata.TabularSections.Find(Data.Key) = Undefined Then
			Continue;
		EndIf;
		
		If IsBlankString(QueryText) Then
			Union = "";
			TempleTable = Chars.CR + "INTO TT_Totals";
		Else
			Union = DriveClientServer.GetQueryUnion();
			TempleTable = "";
		EndIf;
		
		FieldsArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(Data.Value, , False, True);
		
		If FieldsArray.Count() = 0 Then
			Continue;
		EndIf;
		
		Fields = "";
		For Each Field In FieldsArray Do
			
			If IsBlankString(Field) Then
				Fields = Fields + ",
					|	0";
			Else
				Fields = Fields + ",
					|	TableSection." + Field;
			EndIf;
			
		EndDo;
		
		Fields = "SELECT
		|	Header.AmountIncludesVAT," + Mid(Fields, 2);
		
		QueryText = QueryText + Union + Fields + TempleTable + "
			|FROM
			|	Document." + BasisDocMetadata.Name + "." + Data.Key + " AS TableSection
			|		INNER JOIN Document." + BasisDocMetadata.Name + " AS Header
			|			ON TableSection.Ref = Header.Ref
			|WHERE
			|	TableSection.Ref = &Ref";
		
	EndDo;
	
	If IsBlankString(QueryText) Then
		Return VATAmount;
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Totals.AmountIncludesVAT,
	|	SUM(TT_Totals.Amount) AS Amount,
	|	SUM(TT_Totals.VATAmount) AS VATAmount
	|FROM
	|	TT_Totals AS TT_Totals
	|GROUP BY
	|	TT_Totals.AmountIncludesVAT";
	
	Query.SetParameter("Date", ?(ValueIsFilled(Object.Date), Object.Date, CurrentSessionDate()));
	Query.SetParameter("Ref", Object.BasisDocument);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Total = Selection.Amount + ?(Selection.AmountIncludesVAT, 0, Selection.VATAmount);
		VATAmount = ?(Selection.Amount = 0, 0,
			Round(Selection.VATAmount * Object.DocumentAmount / Total, 2));
	EndIf;
	
	Return VATAmount;
	
EndFunction

Function BeginOfMonthAfterLastVATRecord(DefaultDate) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	VATIncurred.Period AS Period
	|INTO TT_LastRecords
	|FROM
	|	AccumulationRegister.VATIncurred AS VATIncurred
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	VATInput.Period
	|FROM
	|	AccumulationRegister.VATInput AS VATInput
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	VATOutput.Period
	|FROM
	|	AccumulationRegister.VATOutput AS VATOutput
	|
	|ORDER BY
	|	Period DESC
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(MAX(TT_LastRecords.Period), DATETIME(1, 1, 1)) AS Period
	|FROM
	|	TT_LastRecords AS TT_LastRecords";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return Max(DefaultDate, EndOfMonth(Selection.Period) + 1);
	EndIf;
	
	Return DefaultDate;
	
EndFunction

Function IsTaxInvoiceAccessRightEdit(Received = False) Export
	
	If Received Then
		Return AccessRight("Edit", Metadata.Documents.TaxInvoiceReceived);
	Else
		Return AccessRight("Edit", Metadata.Documents.TaxInvoiceIssued);
	EndIf;
	
EndFunction

#Region TaxInvoiceMethods

// Posting cancellation procedure of the subordinate sales invoice note
//
Procedure SubordinatedTaxInvoiceControl(WriteMode, Ref, DeletionMark) Export
	
	Received = (TypeOf(Ref) = Type("DocumentRef.DebitNote")
		Or TypeOf(Ref) = Type("DocumentRef.SupplierInvoice")
		Or TypeOf(Ref) = Type("DocumentRef.AdditionalExpenses")
		Or TypeOf(Ref) = Type("DocumentRef.SubcontractorInvoiceReceived"));
	
	If TypeOf(Ref) = Type("DocumentRef.ExpenseReport") Then
		TaxInvoiceArray = GetSubordinateTaxInvoiceReceivedMultiple(Ref);
	Else
		TaxInvoiceArray = New Array;
		TaxInvoiceArray.Add(GetSubordinateTaxInvoice(Ref, Received));
	EndIf;
	
	If TaxInvoiceArray <> Undefined Then
		For Each TaxInvoiceStructure In TaxInvoiceArray Do
			
			If Not TaxInvoiceStructure = Undefined Then
				MessageText = "";
				TaxInvoice = TaxInvoiceStructure.Ref;
				TaxInvoiceObject = TaxInvoice.GetObject();
				
				NeedToWrite = (WriteMode = DocumentWriteMode.Posting) And (TaxInvoice.BasisDocuments.Count() = 1);
				
				If WriteMode = DocumentWriteMode.Posting Then
					FoundRow = TaxInvoiceObject.BasisDocuments.Find(Ref, "BasisDocument");
					If FoundRow <> Undefined Then
						TaxInvoiceObject.FillDocumentAmounts(FoundRow); 
					EndIf;
				EndIf;
				
				Parameters = New Structure;
				Parameters.Insert("Ref", 				Ref);
				Parameters.Insert("TaxInvoiceObject",	TaxInvoiceObject);
				Parameters.Insert("WriteMode",			WriteMode);
				
				If WriteMode = DocumentWriteMode.UndoPosting And TaxInvoice.Posted Then
					MessageText = MessageText + StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = '%1 posting has been cancelled.'; ru = 'Проведение %1 отменено.';pl = 'księgowanie %1 anulowano.';es_ES = '%1 envío se ha cancelado.';es_CO = '%1 envío se ha cancelado.';tr = '%1 gönderimi iptal edildi.';it = '%1 la pubblicazione è stata cancellata.';de = '%1 Buchung wurde storniert.'"),
						WorkWithVATClientServer.TaxInvoicePresentation(TaxInvoiceStructure.Date, TaxInvoiceStructure.Number));
					NeedToWrite = True;
				EndIf;
				
				If WriteMode = DocumentWriteMode.Posting And Not TaxInvoice.Posted And TaxInvoice.BasisDocuments.Count() = 1 Then
					MessageText = MessageText + StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = '%1 has been posted.'; ru = '%1 проведен.';pl = '%1 zaksięgowano.';es_ES = '%1 se ha enviado.';es_CO = '%1 se ha enviado.';tr = '%1 gönderildi.';it = '%1 è stato pubblicato.';de = '%1 wurde gebucht.'"),
						WorkWithVATClientServer.TaxInvoicePresentation(TaxInvoiceStructure.Date, TaxInvoiceStructure.Number));
				EndIf;
				
				If DeletionMark <> TaxInvoice.DeletionMark And TaxInvoice.BasisDocuments.Count() = 1 Then 
					MessageText = MessageText + StringFunctionsClientServer.SubstituteParametersToString(
						?(DeletionMark, NStr("en = '%1 was marked for deletion.'; ru = '%1 помечен на удаление.';pl = '%1 zaznaczono do usunięcia.';es_ES = '%1 fue marcado para borrar.';es_CO = '%1 fue marcado para borrar.';tr = '%1 silinmek üzere işaretlendi.';it = '%1 è stato contrassegnato per l''eliminazione.';de = '%1 war zum Löschen markiert.'"), NStr("en = '%1 was unmarked for deletion.'; ru = 'С %1 снята пометка на удаление.';pl = 'Z %1 zaznaczenie do usunięcie zostało usunięte.';es_ES = '%1 fue desmarcado para borrar.';es_CO = '%1 fue desmarcado para borrar.';tr = '%1 öğesinin silme işareti kaldırıldı.';it = '%1 è stato deselezionato per l''eliminazione.';de = '%1 war zum Löschen unmarkiert.'")),
						WorkWithVATClientServer.TaxInvoicePresentation(TaxInvoiceStructure.Date, TaxInvoiceStructure.Number));
					Parameters.Insert("DeletionMark", 	DeletionMark);
					NeedToWrite = True;
				EndIf;
				
				Parameters.Insert("MessageText", MessageText);
				
				If NeedToWrite Then
					WriteTaxInvoiceAndMessageToUser(Parameters);
				EndIf;
			EndIf;
			
		EndDo;
	EndIf;
	
EndProcedure

// Create and posting the Tax invoice
//
Procedure CreateTaxInvoice(WriteMode, Ref) Export
	
	TaxInvoiceStructure = GetSubordinateTaxInvoice(Ref);
	
	If TaxInvoiceStructure = Undefined Then
		
		TaxInvoiceIssued = Documents.TaxInvoiceIssued.CreateDocument();
		TaxInvoiceIssued.FillBySalesInvoice(Ref);
		TaxInvoiceIssued.Write(WriteMode);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The document %1 have been created automatically.'; ru = 'Документ налоговый инвойс %1 был создан автоматически.';pl = 'Dokument %1 został utworzony automatycznie.';es_ES = 'El documento %1 se ha creado automáticamente.';es_CO = 'El documento %1 se ha creado automáticamente.';tr = 'Belge %1 otomatik olarak oluşturuldu.';it = 'Il documento %1 è stato creato automaticamente.';de = 'Das Dokument %1 wurde automatisch erstellt.'"),
			WorkWithVATClientServer.TaxInvoicePresentation(TaxInvoiceIssued.Date, TaxInvoiceIssued.Number));
			
		CommonClientServer.MessageToUser(MessageText)
	EndIf;
	
EndProcedure

Procedure WriteTaxInvoiceAndMessageToUser(Parameters)
	
	If ValueIsFilled(Parameters.MessageText) Then
		CommonClientServer.MessageToUser(Parameters.MessageText);
	EndIf;
	
	If Parameters.Property("DeletionMark") Then
		Parameters.TaxInvoiceObject.SetDeletionMark(Parameters.DeletionMark);
	Else
		Parameters.TaxInvoiceObject.Write(Parameters.WriteMode);
	EndIf;
	
EndProcedure

// Function returns reference to the subordinate tax invoice
//
Function GetSubordinateTaxInvoice(BasisDocument, Received = False, Advance = False) Export
	
	If NOT ValueIsFilled(BasisDocument) Then
		Return Undefined;
	ElsIf NOT Advance AND NOT GetUseTaxInvoiceForPostingVAT(BasisDocument.Date, BasisDocument.Company) Then
		Return Undefined;
	ElsIf Advance AND GetPostAdvancePaymentsBySourceDocuments(BasisDocument.Date, BasisDocument.Company) Then
		Return Undefined;
	EndIf;
	
	If Received Then
		
		QueryText = 
		"SELECT ALLOWED
		|	TaxInvoiceBasisDocuments.Ref AS Ref
		|INTO TaxInvoiceBasisDocuments
		|FROM
		|	Document.TaxInvoiceReceived.BasisDocuments AS TaxInvoiceBasisDocuments
		|WHERE
		|	TaxInvoiceBasisDocuments.BasisDocument = &BasisDocument
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	Header.Ref AS Ref,
		|	Header.Number AS Number,
		|	Header.Date AS Date
		|FROM
		|	TaxInvoiceBasisDocuments AS TaxInvoiceBasisDocuments
		|		INNER JOIN Document.TaxInvoiceReceived AS Header
		|		ON TaxInvoiceBasisDocuments.Ref = Header.Ref"
		
	Else
		
		QueryText = 
		"SELECT ALLOWED
		|	TaxInvoiceBasisDocuments.Ref AS Ref
		|INTO TaxInvoiceBasisDocuments
		|FROM
		|	Document.TaxInvoiceIssued.BasisDocuments AS TaxInvoiceBasisDocuments
		|WHERE
		|	TaxInvoiceBasisDocuments.BasisDocument = &BasisDocument
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	Header.Ref AS Ref,
		|	Header.Number AS Number,
		|	Header.Date AS Date
		|FROM
		|	TaxInvoiceBasisDocuments AS TaxInvoiceBasisDocuments
		|		INNER JOIN Document.TaxInvoiceIssued AS Header
		|		ON TaxInvoiceBasisDocuments.Ref = Header.Ref"
		
	EndIf;
	
	Query = New Query(QueryText);
	Query.SetParameter("BasisDocument", BasisDocument);
	
	Result = Undefined;
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result = New Structure("Ref, Number, Date");
		FillPropertyValues(Result, Selection);
	EndIf;
	
	Return Result;
EndFunction

// Returns array of reference to the subordinate tax invoices received
//
Function GetSubordinateTaxInvoiceReceivedMultiple(BasisDocument, Advance = False)
	
	If Not ValueIsFilled(BasisDocument) Then
		Return Undefined;
	ElsIf Not Advance And Not GetUseTaxInvoiceForPostingVAT(BasisDocument.Date, BasisDocument.Company) Then
		Return Undefined;
	ElsIf Advance And GetPostAdvancePaymentsBySourceDocuments(BasisDocument.Date, BasisDocument.Company) Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	TaxInvoiceBasisDocuments.Ref AS Ref
	|INTO TaxInvoiceBasisDocuments
	|FROM
	|	Document.TaxInvoiceReceived.BasisDocuments AS TaxInvoiceBasisDocuments
	|WHERE
	|	TaxInvoiceBasisDocuments.BasisDocument = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Header.Ref AS Ref,
	|	Header.Number AS Number,
	|	Header.Date AS Date
	|FROM
	|	TaxInvoiceBasisDocuments AS TaxInvoiceBasisDocuments
	|		INNER JOIN Document.TaxInvoiceReceived AS Header
	|		ON TaxInvoiceBasisDocuments.Ref = Header.Ref
	|WHERE
	|	NOT Header.DeletionMark";
	
	Query.SetParameter("BasisDocument", BasisDocument);
	
	Result = New Array;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ResultStructure = New Structure("Ref, Number, Date");
		FillPropertyValues(ResultStructure, Selection);
		Result.Add(ResultStructure);
	EndDo;
	
	Return Result;
	
EndFunction

// While changing the base document correct
// the subordinate Sales invoice note Parameters:
// BasisDocument - base document for which you should search and correct sales invoice note
Procedure ChangeSubordinateTaxInvoice(BasisDocument, Received = False) Export
	
	TaxInvoiceIssued = GetSubordinateTaxInvoice(BasisDocument, Received);
	TaxInvoiceObject = TaxInvoiceIssued.Ref.GetObject();
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]						= "FillByStructure";
	FillingStrategy[Type("DocumentRef.SalesInvoice")]	= "FillBySalesInvoice";
	
	ObjectFillingDrive.FillDocument(TaxInvoiceObject, BasisDocument, FillingStrategy);
	
	TaxInvoiceObject.Write();
	
EndProcedure

// Sets hyperlink label "Tax invoice"
//
Procedure SetTextAboutTaxInvoiceReceived(DocumentForm) Export
	SetTextAboutTaxInvoice(DocumentForm, True)
EndProcedure

// Sets hyperlink label "Tax invoice"
//
Procedure SetTextAboutTaxInvoiceIssued(DocumentForm) Export
	SetTextAboutTaxInvoice(DocumentForm)
EndProcedure

// Sets hyperlink label "Advance Payment Invoice"
//
Procedure SetTextAboutAdvancePaymentInvoiceIssued(DocumentForm) Export
	SetTextAboutAdvancePaymentInvoice(DocumentForm)
EndProcedure

// Sets hyperlink label "Advance Payment Invoice"
//
Procedure SetTextAboutAdvancePaymentInvoiceReceived(DocumentForm) Export
	SetTextAboutAdvancePaymentInvoice(DocumentForm, True)
EndProcedure

// Sets hyperlink label for Advance Payment Invoice note
//
Procedure SetTextAboutAdvancePaymentInvoice(DocumentForm, Received = False)

	AdvancePaymentInvoiceFound = GetSubordinateTaxInvoice(DocumentForm.Object.Ref, Received, True);
	
	If ValueIsFilled(AdvancePaymentInvoiceFound) Then
		DocumentForm.TaxInvoiceText = WorkWithVATClientServer.AdvancePaymentInvoicePresentation(AdvancePaymentInvoiceFound.Date, AdvancePaymentInvoiceFound.Number);
	Else
		DocumentForm.TaxInvoiceText = NStr("en = 'Create Advance payment invoice'; ru = 'Создать инвойс на аванс';pl = 'Utwórz fakturę zaliczkową';es_ES = 'Crear la Factura de pago adelantado';es_CO = 'Crear la Factura de pago anticipado';tr = 'Avans ödeme faturası oluştur';it = 'Creare una fattura di pagamento anticipato';de = 'Vorauszahlungsrechnung erstellen'");
	EndIf;

EndProcedure

// Sets hyperlink label for Sales invoice note
//
Procedure SetTextAboutTaxInvoice(DocumentForm, Received = False)

	TaxInvoiceFound = GetSubordinateTaxInvoice(DocumentForm.Object.Ref, Received);
	
	If ValueIsFilled(TaxInvoiceFound) Then
		DocumentForm.TaxInvoiceText = WorkWithVATClientServer.TaxInvoicePresentation(TaxInvoiceFound.Date, TaxInvoiceFound.Number);	
	Else
		DocumentForm.TaxInvoiceText = NStr("en = 'Create tax invoice'; ru = 'Создать налоговый инвойс';pl = 'Utwórz fakturę VAT';es_ES = 'Crear la Factura de impuestos';es_CO = 'Crear la Factura fiscal';tr = 'Vergi faturası oluştur';it = 'Creare fattura fiscale';de = 'Steuerrechnung erstellen'");
	EndIf;

EndProcedure

// Method fills the Prepayment VAT table in object.
//
// Parameters:
//	Object - DocumentObject - Document which have a table "Prepayment VAT"
//
Procedure FillPrepaymentVATFromVATInput(Object) Export
	
	TextQuery = 
	"SELECT ALLOWED DISTINCT
	|	TaxInvoice.Ref AS Ref
	|INTO TaxInvoice
	|FROM
	|	Document.TaxInvoiceReceived.BasisDocuments AS TaxInvoice
	|WHERE
	|	TaxInvoice.BasisDocument = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VATInput.Company AS Company,
	|	VATInput.Supplier AS Customer,
	|	VATInput.ShipmentDocument AS ShipmentDocument,
	|	VATInput.VATRate AS VATRate,
	|	SUM(VATInput.AmountExcludesVATTurnover) AS AmountExcludesVAT,
	|	SUM(VATInput.VATAmountTurnover) AS VATAmount
	|INTO VATInputBalanceNoGroup
	|FROM
	|	AccumulationRegister.VATInput.Turnovers(
	|			,
	|			&DocumentDate,
	|			Recorder,
	|			ShipmentDocument IN (&PrepaymentDocument)
	|				AND Company = &Company
	|				AND Supplier = &Customer) AS VATInput
	|
	|GROUP BY
	|	VATInput.Company,
	|	VATInput.Supplier,
	|	VATInput.ShipmentDocument,
	|	VATInput.VATRate
	|
	|UNION ALL
	|
	|SELECT
	|	VATInput.Company,
	|	VATInput.Supplier,
	|	VATInput.ShipmentDocument,
	|	VATInput.VATRate,
	|	-SUM(VATInput.AmountExcludesVAT),
	|	-SUM(VATInput.VATAmount)
	|FROM
	|	TaxInvoice AS TaxInvoice
	|		INNER JOIN AccumulationRegister.VATInput AS VATInput
	|		ON TaxInvoice.Ref = VATInput.Recorder
	|WHERE
	|	VATInput.ShipmentDocument IN(&PrepaymentDocument)
	|	AND VATInput.Company = &Company
	|	AND VATInput.Supplier = &Customer
	|
	|GROUP BY
	|	VATInput.Company,
	|	VATInput.Supplier,
	|	VATInput.ShipmentDocument,
	|	VATInput.VATRate
	|
	|UNION ALL
	|
	|SELECT
	|	VATInput.Company,
	|	VATInput.Supplier,
	|	VATInput.ShipmentDocument,
	|	VATInput.VATRate,
	|	-SUM(VATInput.AmountExcludesVAT),
	|	-SUM(VATInput.VATAmount)
	|FROM
	|	AccumulationRegister.VATInput AS VATInput
	|WHERE
	|	VATInput.Recorder = &Ref
	|	AND VATInput.ShipmentDocument IN(&PrepaymentDocument)
	|	AND VATInput.Company = &Company
	|	AND VATInput.Supplier = &Customer
	|
	|GROUP BY
	|	VATInput.Company,
	|	VATInput.Supplier,
	|	VATInput.ShipmentDocument,
	|	VATInput.VATRate
	|
	|UNION ALL
	|
	|SELECT
	|	VATIncurred.Company,
	|	VATIncurred.Supplier,
	|	VATIncurred.ShipmentDocument,
	|	VATIncurred.VATRate,
	|	VATIncurred.AmountExcludesVATBalance,
	|	VATIncurred.VATAmountBalance
	|FROM
	|	AccumulationRegister.VATIncurred.Balance(
	|			&PointInTime,
	|			ShipmentDocument IN (&PrepaymentDocument)
	|				AND Company = &Company
	|				AND Supplier = &Customer) AS VATIncurred
	|
	|UNION ALL
	|
	|SELECT
	|	VATIncurred.Company,
	|	VATIncurred.Supplier,
	|	VATIncurred.ShipmentDocument,
	|	VATIncurred.VATRate,
	|	VATIncurred.AmountExcludesVAT,
	|	VATIncurred.VATAmount
	|FROM
	|	TaxInvoice AS TaxInvoice
	|		INNER JOIN AccumulationRegister.VATIncurred AS VATIncurred
	|		ON TaxInvoice.Ref = VATIncurred.Recorder
	|WHERE
	|	VATIncurred.ShipmentDocument IN(&PrepaymentDocument)
	|	AND VATIncurred.Company = &Company
	|	AND VATIncurred.Supplier = &Customer
	|
	|UNION ALL
	|
	|SELECT
	|	VATIncurred.Company,
	|	VATIncurred.Supplier,
	|	VATIncurred.ShipmentDocument,
	|	VATIncurred.VATRate,
	|	VATIncurred.AmountExcludesVAT,
	|	VATIncurred.VATAmount
	|FROM
	|	AccumulationRegister.VATIncurred AS VATIncurred
	|WHERE
	|	VATIncurred.Recorder = &Ref
	|	AND VATIncurred.ShipmentDocument IN(&PrepaymentDocument)
	|	AND VATIncurred.Company = &Company
	|	AND VATIncurred.Supplier = &Customer
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VATInput.Company AS Company,
	|	VATInput.Customer AS Customer,
	|	VATInput.ShipmentDocument AS ShipmentDocument,
	|	VATInput.VATRate AS VATRate,
	|	SUM(VATInput.AmountExcludesVAT) AS AmountExcludesVAT,
	|	SUM(VATInput.VATAmount) AS VATAmount
	|INTO VATInputBalance
	|FROM
	|	VATInputBalanceNoGroup AS VATInput
	|WHERE
	|	VATInput.AmountExcludesVAT > 0
	|
	|GROUP BY
	|	VATInput.Company,
	|	VATInput.Customer,
	|	VATInput.ShipmentDocument,
	|	VATInput.VATRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Prepayment.Document AS ShipmentDocument,
	|	Prepayment.PaymentAmount AS PaymentAmount
	|INTO Prepayment
	|FROM
	|	&PrepaymentTab AS Prepayment
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VATInput.Company AS Company,
	|	VATInput.Customer AS Customer,
	|	VATInput.ShipmentDocument AS Document,
	|	VATInput.VATRate AS VATRate,
	|	VATInput.AmountExcludesVAT AS AmountExcludesVAT,
	|	VATInput.VATAmount AS VATAmount,
	|	VATInput.AmountExcludesVAT + VATInput.VATAmount AS PaymentAmount,
	|	Prepayment.PaymentAmount AS DocumentPaymentAmount
	|FROM
	|	VATInputBalance AS VATInput
	|		INNER JOIN Prepayment AS Prepayment
	|		ON VATInput.ShipmentDocument = Prepayment.ShipmentDocument
	|WHERE
	|	VATInput.AmountExcludesVAT > 0";
	
	FillPrepaymentVAT(Object, TextQuery);
	
EndProcedure

// Method fills the Prepayment VAT table in object.
//
// Parameters:
//	Object - DocumentObject - Document which have a table "Prepayment VAT"
//
Procedure FillPrepaymentVATFromVATOutput(Object) Export
	
	TextQuery = 
	"SELECT ALLOWED DISTINCT
	|	TaxInvoice.Ref AS Ref
	|INTO TaxInvoice
	|FROM
	|	Document.TaxInvoiceIssued.BasisDocuments AS TaxInvoice
	|WHERE
	|	TaxInvoice.BasisDocument = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VATOutput.Company AS Company,
	|	VATOutput.Customer AS Customer,
	|	VATOutput.ShipmentDocument AS ShipmentDocument,
	|	VATOutput.VATRate AS VATRate,
	|	SUM(VATOutput.AmountExcludesVATTurnover) AS AmountExcludesVAT,
	|	SUM(VATOutput.VATAmountTurnover) AS VATAmount
	|INTO VATOutputBalanceNoGroup
	|FROM
	|	AccumulationRegister.VATOutput.Turnovers(
	|			,
	|			&DocumentDate,
	|			Recorder,
	|			ShipmentDocument IN (&PrepaymentDocument)
	|				AND Company = &Company
	|				AND Customer = &Customer) AS VATOutput
	|
	|GROUP BY
	|	VATOutput.Company,
	|	VATOutput.Customer,
	|	VATOutput.ShipmentDocument,
	|	VATOutput.VATRate
	|
	|UNION ALL
	|
	|SELECT
	|	VATOutput.Company,
	|	VATOutput.Customer,
	|	VATOutput.ShipmentDocument,
	|	VATOutput.VATRate,
	|	-SUM(VATOutput.AmountExcludesVAT),
	|	-SUM(VATOutput.VATAmount)
	|FROM
	|	TaxInvoice AS TaxInvoice
	|		INNER JOIN AccumulationRegister.VATOutput AS VATOutput
	|		ON TaxInvoice.Ref = VATOutput.Recorder
	|WHERE
	|	VATOutput.ShipmentDocument IN(&PrepaymentDocument)
	|	AND VATOutput.Company = &Company
	|	AND VATOutput.Customer = &Customer
	|
	|GROUP BY
	|	VATOutput.Company,
	|	VATOutput.Customer,
	|	VATOutput.ShipmentDocument,
	|	VATOutput.VATRate
	|
	|UNION ALL
	|
	|SELECT
	|	VATOutput.Company,
	|	VATOutput.Customer,
	|	VATOutput.ShipmentDocument,
	|	VATOutput.VATRate,
	|	-SUM(VATOutput.AmountExcludesVAT),
	|	-SUM(VATOutput.VATAmount)
	|FROM
	|	AccumulationRegister.VATOutput AS VATOutput
	|WHERE
	|	VATOutput.Recorder = &Ref
	|	AND VATOutput.ShipmentDocument IN(&PrepaymentDocument)
	|	AND VATOutput.Company = &Company
	|	AND VATOutput.Customer = &Customer
	|
	|GROUP BY
	|	VATOutput.Company,
	|	VATOutput.Customer,
	|	VATOutput.ShipmentDocument,
	|	VATOutput.VATRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VATOutput.Company AS Company,
	|	VATOutput.Customer AS Customer,
	|	VATOutput.ShipmentDocument AS ShipmentDocument,
	|	VATOutput.VATRate AS VATRate,
	|	SUM(VATOutput.AmountExcludesVAT) AS AmountExcludesVAT,
	|	SUM(VATOutput.VATAmount) AS VATAmount
	|INTO VATOutputBalance
	|FROM
	|	VATOutputBalanceNoGroup AS VATOutput
	|WHERE
	|	VATOutput.AmountExcludesVAT > 0
	|
	|GROUP BY
	|	VATOutput.Company,
	|	VATOutput.Customer,
	|	VATOutput.ShipmentDocument,
	|	VATOutput.VATRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Prepayment.Document AS ShipmentDocument,
	|	Prepayment.PaymentAmount AS PaymentAmount
	|INTO Prepayment
	|FROM
	|	&PrepaymentTab AS Prepayment
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VATOutput.Company AS Company,
	|	VATOutput.Customer AS Customer,
	|	VATOutput.ShipmentDocument AS Document,
	|	VATOutput.VATRate AS VATRate,
	|	VATOutput.AmountExcludesVAT AS AmountExcludesVAT,
	|	VATOutput.VATAmount AS VATAmount,
	|	VATOutput.AmountExcludesVAT + VATOutput.VATAmount AS PaymentAmount,
	|	Prepayment.PaymentAmount AS DocumentPaymentAmount
	|FROM
	|	VATOutputBalance AS VATOutput
	|		INNER JOIN Prepayment AS Prepayment
	|		ON VATOutput.ShipmentDocument = Prepayment.ShipmentDocument
	|WHERE
	|	VATOutput.AmountExcludesVAT > 0";
	
	FillPrepaymentVAT(Object, TextQuery);
	
EndProcedure

// Method fills the Prepayment VAT table in object.
//
// Parameters:
//	Object - DocumentObject - Document which have a table "Prepayment VAT"
//	TextQuery - String - Text query
//
Procedure FillPrepaymentVAT(Object, TextQuery)
	
	Object.PrepaymentVAT.Clear();
	
	PrepaymentTab = Object.Prepayment.Unload(,"Document,PaymentAmount");
	
	Query = New Query(TextQuery);
	Query.SetParameter("PrepaymentDocument", PrepaymentTab.UnloadColumn("Document"));
	Query.SetParameter("PrepaymentTab", PrepaymentTab);
	Query.SetParameter("Company", Object.Company);
	Query.SetParameter("Customer", Object.Counterparty);
	Query.SetParameter("DocumentDate", EndOfDay(Object.Date) + 1);
	Query.SetParameter("PointInTime", New PointInTime(Object.Date, Object.Ref));
	Query.SetParameter("Ref", Object.Ref);
	
	VATOutput = Query.Execute().Select();
	While VATOutput.Next() Do
		
		NewLine = Object.PrepaymentVAT.Add();
		
		PaymentAmountForFill = VATOutput.DocumentPaymentAmount;
		
		If PaymentAmountForFill >= VATOutput.PaymentAmount Then
			
			FillPropertyValues(NewLine, VATOutput);
			
		Else
			
			NewLine.Document = VATOutput.Document;
			NewLine.VATRate = VATOutput.VATRate;
			
			NewLine.AmountExcludesVAT = Round(PaymentAmountForFill * VATOutput.AmountExcludesVAT / VATOutput.PaymentAmount, 2);
			NewLine.VATAmount = Round(PaymentAmountForFill * VATOutput.VATAmount / VATOutput.PaymentAmount, 2);
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

Procedure SetCompanyVATNumberItemVisible(Item, Visible)
	
	If TypeOf(Item) = Type("FormField") Then
		Item.Visible = Visible;
	EndIf;
	
EndProcedure

#EndRegion