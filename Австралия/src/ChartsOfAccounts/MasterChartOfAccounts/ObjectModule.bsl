#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	EndDateToCheck = ?(ValueIsFilled(EndDate), EndDate, '39991130235959');
	
	If StartDate > EndDateToCheck Then
		DriveServer.ShowMessageAboutError(ThisObject, 
				MessagesToUserClientServer.GetMasterChartOfAccountsActiveToErrorText(), , , "EndDate", Cancel);
	Else
		For Each CompanyRow In Companies Do
			
			CompanyEndDateToCheck = ?(ValueIsFilled(CompanyRow.EndDate), CompanyRow.EndDate, '39991130235959');
		
			If StartDate > CompanyRow.StartDate Then
				DriveServer.ShowMessageAboutError(ThisObject, 
					MessagesToUserClientServer.GetMasterChartOfAccountsActiveFromErrorText(), , , "StartDate", Cancel);
			EndIf;
			
			If EndDateToCheck < CompanyEndDateToCheck Then
				DriveServer.ShowMessageAboutError(ThisObject, 
					MessagesToUserClientServer.GetMasterChartOfAccountsActiveToComapniesErrorText(), , , "EndDate", Cancel);
			EndIf;

			If CompanyRow.StartDate > CompanyEndDateToCheck Then
				FieldName = StringFunctionsClientServer.SubstituteParametersToString("Companies[%1].EndDate", CompanyRow.LineNumber - 1);
				DriveServer.ShowMessageAboutError(ThisObject, 
					MessagesToUserClientServer.GetMasterChartOfAccountsActiveToErrorText(), , , FieldName, Cancel);
			EndIf;

		EndDo;
	EndIf;

	Query = New Query;
	Query.Text = 
	"SELECT
	|	CompanyTable.Company AS Company,
	|	CompanyTable.LineNumber AS LineNumber
	|INTO CompaniesTable
	|FROM
	|	&CompanyTable AS CompanyTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompaniesTable.Company.Presentation AS Company,
	|	CompaniesTable.LineNumber AS LineNumber
	|FROM
	|	CompaniesTable AS CompaniesTable
	|TOTALS
	|	COUNT(DISTINCT LineNumber)
	|BY
	|	Company";
	
	Query.SetParameter("CompanyTable", Companies.Unload( , "Company, LineNumber"));
	
	QueryResult = Query.Execute();
	
	SelectionCompany = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While SelectionCompany.Next() Do

		If SelectionCompany.LineNumber <= 1 Then
			Continue;
		EndIf;
		
		SelectionDetailRecords = SelectionCompany.Select();
		
		RowsNumbers = "";
		FirstRowNumber = 0;
		While SelectionDetailRecords.Next() Do
			
			If FirstRowNumber = 0 Then
				FirstRowNumber = SelectionDetailRecords.LineNumber;
				RowsNumbers = "" + SelectionDetailRecords.LineNumber;
			Else
				RowsNumbers = RowsNumbers + ", " + SelectionDetailRecords.LineNumber;
			EndIf;
			
		EndDo;
		
		FieldName = StringFunctionsClientServer.SubstituteParametersToString("Companies[%1].Company", FirstRowNumber - 1);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagesToUserClientServer.GetMasterChartOfAccountsCompanySelectionErrorText(), 
			RowsNumbers);
		
		DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , FieldName, Cancel);
		
	EndDo;
	
	If UseAnalyticalDimensions Then
		
		CheckedAttributes.Add("AnalyticalDimensionsSet");
		
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsNew() Then
		
		ElemRef = ChartsOfAccounts.MasterChartOfAccounts.GetRef();
		SetNewObjectRef(ElemRef);
		
	Else
		
		ElemRef = Ref;
		
	EndIf;
	
	If Not ChartsOfAccounts.MasterChartOfAccounts.CheckCodeIsUnique(ElemRef, Code, ChartOfAccounts) Then
		
		ErrorTemplate = MessagesToUserClientServer.GetMasterChartOfAccountsNotUniqueCodeErrorText();
		
		DriveServer.ShowMessageAboutError(ThisObject, 
			StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, Code),
			,
			,
			"Object.Code", 
			Cancel);
		
	ElsIf Not ValueIsFilled(Order) Then

		ErrorTemplate = MessagesToUserClientServer.GetMasterChartOfAccountsFieldIsRequiredErrorText();
		
		DriveServer.ShowMessageAboutError(ThisObject, 
			StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, NStr("en = 'Sort order'; ru = 'Порядок сортировки';pl = 'Kolejność sortowania';es_ES = 'Clasificar el orden';es_CO = 'Clasificar el orden';tr = 'Sıralama';it = 'Ordinamento';de = 'Sortierreihenfolge'")),
			,
			,
			"Object.Order", 
			Cancel);
		
	EndIf;
	
	If Not UseAnalyticalDimensions And ExtDimensionTypes.Count() > 0 Then
		
		AnalyticalDimensionsSet = Undefined;
		AnalyticalDimensions.Clear();
		ExtDimensionTypes.Clear();
		
	Else 
		
		ChartsOfAccounts.MasterChartOfAccounts.FillExtDimensionTypesByAnalyticalDimensions(
			AnalyticalDimensions,
			ExtDimensionTypes,
			UseQuantity,
			Currency);
	
	EndIf;
	
	Quantity = UseQuantity;
	
	CheckUsing			= False;
	ModifiedAttributes	= DriveServer.GetModifiedAttributes(ThisObject, False);
	ModifiedCompanies	= DriveServer.GetModifiedTabularSectionAttributes(ThisObject, "Companies");
	CheckParent			= (ModifiedAttributes.Find("Parent") <> Undefined);
	CheckPeriod			= (ModifiedAttributes.Find("StartDate") <> Undefined Or ModifiedAttributes.Find("EndDate") <> Undefined);
	For Each Attribute In ModifiedAttributes Do
		
		If Attribute <> "Description"
			And Attribute <> "Code" 
			And Attribute <> "Order"
			And Attribute <> "Parent" Then
			CheckUsing = True;
			Break;
		EndIf;
			
	EndDo;
	
	If Not IsNew()
		And CheckUsing Then
		
		CheckTemplates(ElemRef);
		
	EndIf;
	
	ChartsOfAccounts.MasterChartOfAccounts.CheckActivityPeriod(ThisObject, CheckParent, CheckPeriod, ModifiedCompanies, Cancel);

	IsAvailableForAllCompanies = (Companies.Count() = 0);
	If IsAvailableForAllCompanies And DriveServer.IsRestrictedByCompany() Then
		
		ErrorMessage = NStr("en = 'Empty companies list is not allowed!'; ru = 'Заполните список организаций.';pl = 'Pusta lista firm nie jest dozwolona!';es_ES = 'No se permite una lista de empresas vacía.';es_CO = 'No se permite una lista de empresas vacía.';tr = 'Boş iş yeri listesine izin verilmez!';it = 'Non è concesso un elenco aziende vuoto!';de = 'Leere Firmenliste ist nicht gestattet!'");
		DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , "Object.Companies", Cancel);
		
	EndIf;
		
	If Not Cancel Then
		
		HistoryParameters = New Structure;
		HistoryParameters.Insert("StartDate"				, StartDate);
		HistoryParameters.Insert("EndDate"					, EndDate);
		HistoryParameters.Insert("UseQuantity"				, UseQuantity);
		HistoryParameters.Insert("UseAnalyticalDimensions"	, UseAnalyticalDimensions);
		HistoryParameters.Insert("AnalyticalDimensionsSet"	, AnalyticalDimensionsSet);
		HistoryParameters.Insert("CompaniesTable"			, Companies);
		
		InformationRegisters.MasterChartOfAccountsHistory.SaveAccountHistory(ElemRef, HistoryParameters, IsNew());
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	AllowedCompanies = ChartsOfAccounts.MasterChartOfAccounts.SelectAllowedCompaniesFromTable(Companies.Unload());
	
	DeniedCompanies = New Array;
	
	For Each Row In Companies Do
		
		If AllowedCompanies.Find(Row.Company, "Company") = Undefined Then
			DeniedCompanies.Add(Row);
		EndIf;
		
	EndDo;
	
	For Each Row In DeniedCompanies Do
		Companies.Delete(Row);
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Procedure CheckTemplates(ElemRef)
	
	CheckQuantity = (UseQuantity <> Common.ObjectAttributeValue(ElemRef, "UseQuantity"));
	CheckDimensionsSet = (AnalyticalDimensionsSet <> Common.ObjectAttributeValue(ElemRef, "AnalyticalDimensionsSet"));
	
	If Not CheckQuantity And Not CheckDimensionsSet Then
		Return;
	EndIf;
		
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	AccountingEntriesTemplatesEntries.Ref AS Ref,
	|	AccountingEntriesTemplatesEntries.Quantity AS Quantity,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsSet AS AnalyticalDimensionsSet,
	|	AccountingEntriesTemplatesEntries.Account AS Account,
	|	AccountingEntriesTemplatesEntries.LineNumber AS LineNumber,
	|	""Entries"" AS TabSectionName,
	|	"""" AS DrCr
	|FROM
	|	Catalog.AccountingEntriesTemplates.Entries AS AccountingEntriesTemplatesEntries
	|WHERE
	|	AccountingEntriesTemplatesEntries.Account = &Account
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesTemplatesEntriesSimple.Ref,
	|	AccountingEntriesTemplatesEntriesSimple.QuantityDr,
	|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsSetDr,
	|	AccountingEntriesTemplatesEntriesSimple.AccountDr,
	|	AccountingEntriesTemplatesEntriesSimple.LineNumber,
	|	""EntriesSimple"",
	|	""Dr""
	|FROM
	|	Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesTemplatesEntriesSimple
	|WHERE
	|	AccountingEntriesTemplatesEntriesSimple.AccountDr = &Account
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesTemplatesEntriesSimple.Ref,
	|	AccountingEntriesTemplatesEntriesSimple.QuantityCr,
	|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsSetCr,
	|	AccountingEntriesTemplatesEntriesSimple.AccountCr,
	|	AccountingEntriesTemplatesEntriesSimple.LineNumber,
	|	""EntriesSimple"",
	|	""Cr""
	|FROM
	|	Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesTemplatesEntriesSimple
	|WHERE
	|	AccountingEntriesTemplatesEntriesSimple.AccountCr = &Account";
	
	Query.SetParameter("Account", ElemRef);
	
	SelectionDetailRecords = Query.Execute().Select();
	
	TemplatesToFix = New Array;
	
	MessageTemplQuantity	= MessagesToUserClientServer.GetMasterChartOfAccountsQuantitySettingsErrorTemplate();
	MessageTemplDimensions	= MessagesToUserClientServer.GetMasterChartOfAccountsDimensionsSettingsErrorTemplate();
	
	While SelectionDetailRecords.Next() Do
		
		If CheckQuantity
			And (UseQuantity And Not ValueIsFilled(SelectionDetailRecords.Quantity) 
				Or Not UseQuantity And ValueIsFilled(SelectionDetailRecords.Quantity)) Then
			
			MessageText	 = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplQuantity, SelectionDetailRecords.Ref, SelectionDetailRecords.LineNumber);
			MessageField = CommonClientServer.PathToTabularSection(
				SelectionDetailRecords.TabSectionName,
				SelectionDetailRecords.LineNumber,
				"Quantity" + SelectionDetailRecords.DrCr + "Synonym");
				
			ErrTemplateStr = New Structure(
				"Ref, Message, Field",
				SelectionDetailRecords.Ref,
				MessageText,
				MessageField);
				
			TemplatesToFix.Add(ErrTemplateStr);
			
		EndIf;
		
		If CheckDimensionsSet And AnalyticalDimensionsSet <> SelectionDetailRecords.AnalyticalDimensionsSet Then
			
			MessageText	 = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplDimensions, SelectionDetailRecords.Ref, SelectionDetailRecords.LineNumber);
			MessageField = CommonClientServer.PathToTabularSection(
				SelectionDetailRecords.TabSectionName,
				SelectionDetailRecords.LineNumber,
				"AnalyticalDimensionsSet" + SelectionDetailRecords.DrCr);
			
			ErrTemplateStr = New Structure(
				"Ref, Message, Field", 
				SelectionDetailRecords.Ref,
				MessageText,
				MessageField);
				
			TemplatesToFix.Add(ErrTemplateStr);
			
		EndIf;
		
	EndDo;
	
	For Each Template In TemplatesToFix Do
		CommonClientServer.MessageToUser(Template.Message, Template.Ref, Template.Field, "Object");
	EndDo;
	
EndProcedure

#EndRegion

#EndIf