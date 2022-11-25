#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure ChangeStatusWithCheck(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	TemplatesTable = Undefined;
	
	If Not ParametersStructure.Property("TemplatesTable", TemplatesTable) Then
		Return;
	EndIf;
	
	NewTemplateParameters = ParametersStructure.NewTemplateParameters;
	
	For Each TemplateRow In TemplatesTable Do
		
		If TemplateRow.Error = 0 Then // Template already processed
			Continue;
		EndIf;
		
		TemplateRow.Error = CheckStatusChangeAvailable(TemplateRow.TemplateRef, NewTemplateParameters);
		
	EndDo;
	
	ResultStructure = New Structure();
	ResultStructure.Insert("Messages", TimeConsumingOperations.UserMessages(True));
	ResultStructure.Insert("TemplatesTable", TemplatesTable);
	
	PutToTempStorage(ResultStructure, BackgroundJobStorageAddress);

EndProcedure

Function FindTemplateUsage(AccEntryTemplateRef, StatusRef) Export

	Query = New Query;
	
	Query.Text = 
	"SELECT
	|	AccountingTransactionsTemplatesEntries.Ref.Code AS Code,
	|	""Entries"" AS TabName,
	|	AccountingTransactionsTemplatesEntries.LineNumber AS LineNumber,
	|	AccountingTransactionsTemplatesEntries.Ref AS Ref,
	|	CASE
	|		WHEN AccountingTransactionsTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Draft)
	|			THEN AccountingTransactionsTemplates.PlanStartDate
	|		ELSE AccountingTransactionsTemplates.StartDate
	|	END AS StartDate,
	|	CASE
	|		WHEN AccountingTransactionsTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Draft)
	|			THEN AccountingTransactionsTemplates.PlanEndDate
	|		ELSE AccountingTransactionsTemplates.EndDate
	|	END AS EndDate
	|FROM
	|	Catalog.AccountingTransactionsTemplates.Entries AS AccountingTransactionsTemplatesEntries
	|		LEFT JOIN Catalog.AccountingTransactionsTemplates AS AccountingTransactionsTemplates
	|		ON AccountingTransactionsTemplatesEntries.Ref = AccountingTransactionsTemplates.Ref
	|WHERE
	|	AccountingTransactionsTemplatesEntries.EntriesTemplate = &EntriesTemplate
	|	AND AccountingTransactionsTemplatesEntries.Ref.Status = &Status
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingTransactionsTemplatesEntriesSimple.Ref.Code,
	|	""EntriesSimple"",
	|	AccountingTransactionsTemplatesEntriesSimple.LineNumber,
	|	AccountingTransactionsTemplatesEntriesSimple.Ref,
	|	CASE
	|		WHEN AccountingTransactionsTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Draft)
	|			THEN AccountingTransactionsTemplates.PlanStartDate
	|		ELSE AccountingTransactionsTemplates.StartDate
	|	END,
	|	CASE
	|		WHEN AccountingTransactionsTemplatesEntriesSimple.Ref.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Draft)
	|			THEN AccountingTransactionsTemplatesEntriesSimple.Ref.PlanEndDate
	|		ELSE AccountingTransactionsTemplatesEntriesSimple.Ref.EndDate
	|	END
	|FROM
	|	Catalog.AccountingTransactionsTemplates.EntriesSimple AS AccountingTransactionsTemplatesEntriesSimple
	|		LEFT JOIN Catalog.AccountingTransactionsTemplates AS AccountingTransactionsTemplates
	|		ON AccountingTransactionsTemplatesEntriesSimple.Ref = AccountingTransactionsTemplates.Ref
	|WHERE
	|	AccountingTransactionsTemplatesEntriesSimple.EntriesTemplate = &EntriesTemplate
	|	AND AccountingTransactionsTemplatesEntriesSimple.Ref.Status = &Status";

	Query.SetParameter("EntriesTemplate", AccEntryTemplateRef);
	Query.SetParameter("Status"			, StatusRef);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Unload();

EndFunction

Function FindTemplatePeriodsNotMatch(AccEntryTemplateRef, StatusRef, PeriodStart, PeriodEnd) Export

	TemplateUsageTable = FindTemplateUsage(AccEntryTemplateRef, StatusRef);
	
	CorrectTemplates = New Array;
	
	For Each Row In TemplateUsageTable Do
		
		If CheckNestingPeriod(PeriodStart, PeriodEnd, Row.StartDate, Row.EndDate) Then
			CorrectTemplates.Add(Row);
		EndIf;
		
	EndDo;
	
	DeleteRowsInATable(TemplateUsageTable, CorrectTemplates);
	
	Return TemplateUsageTable;

EndFunction

Function DeleteTemplateUsage(TemplateUsageTable, AccountingEntriesTemplate = Undefined, ShowMessages = False) Export

	TemplatesRefs = TemplateUsageTable.Copy(, "Ref");
	TemplatesRefs.GroupBy("Ref");
	
	TemplatesWithTabNames = TemplateUsageTable.Copy(, "Ref, TabName");
	TemplatesWithTabNames.GroupBy("Ref, TabName");
	
	For Each TemplatesRef In TemplatesRefs Do
		
		TemplatesObject = TemplatesRef.Ref.GetObject();
		
		Filter = New Structure;
		Filter.Insert("Ref", TemplatesRef.Ref);
		
		TabularSections =  TemplatesWithTabNames.FindRows(Filter);
		
		For Each TabularSection In TabularSections Do
			
			Filter = New Structure;
			Filter.Insert("Ref"		, TabularSection.Ref);
			Filter.Insert("TabName"	, TabularSection.TabName);
			
			RowsInTemplate = TemplateUsageTable.FindRows(Filter);
			
			EntriesRows						 = New Array;
			EntriesFiltersRows				 = New Array;
			ElementsSynonymsRows			 = New Array;
			ParametersValuesRows			 = New Array;
			AdditionalEntriesParametersRows	 = New Array;
			
			For Each Row In RowsInTemplate Do
				
				RowInCatalog = TemplatesObject[TabularSection.TabName][Row.LineNumber - 1];
				
				EntriesRows.Add(RowInCatalog);
				
				Filter = New Structure;
				Filter.Insert("MetadataName", TabularSection.TabName);
				Filter.Insert("ConnectionKey", RowInCatalog.ConnectionKey);
				
				CatalogElementsSynonymsRows = TemplatesObject.ElementsSynonyms.FindRows(Filter);
				For Each CatalogElementsSynonymsRow In CatalogElementsSynonymsRows Do
					ElementsSynonymsRows.Add(CatalogElementsSynonymsRow);
				EndDo;
				
				Filter = New Structure;
				Filter.Insert("EntryConnectionKey", RowInCatalog.ConnectionKey);
				
				CatalogEntriesFiltersRows = TemplatesObject.EntriesFilters.FindRows(Filter);
				For Each CatalogEntriesFiltersRow In CatalogEntriesFiltersRows Do
					EntriesFiltersRows.Add(CatalogEntriesFiltersRow);
					
					FilterParametersValues = New Structure;
					FilterParametersValues.Insert("MetadataName", "EntriesFilters");
					FilterParametersValues.Insert("ConnectionKey", CatalogEntriesFiltersRow.ValuesConnectionKey);
					
					CatalogParametersValuesRows = TemplatesObject.ParametersValues.FindRows(FilterParametersValues);
					For Each CatalogParametersValuesRow In CatalogParametersValuesRows Do
						ParametersValuesRows.Add(CatalogParametersValuesRow);
					EndDo;
				EndDo;
				
				CatalogAdditionalEntriesParametersRows = TemplatesObject.AdditionalEntriesParameters.FindRows(Filter);
				For Each CatalogAdditionalEntriesParametersRow In CatalogAdditionalEntriesParametersRows Do
					AdditionalEntriesParametersRows.Add(CatalogAdditionalEntriesParametersRow);
					
					FilterParametersValues = New Structure;
					FilterParametersValues.Insert("MetadataName", "AdditionalEntriesParameters");
					FilterParametersValues.Insert("ConnectionKey", CatalogAdditionalEntriesParametersRow.ValuesConnectionKey);
					
					CatalogParametersValuesRows = TemplatesObject.ParametersValues.FindRows(FilterParametersValues);
					For Each CatalogParametersValuesRow In CatalogParametersValuesRows Do
						ParametersValuesRows.Add(CatalogParametersValuesRow);
					EndDo;
				EndDo;
				
			EndDo;
			
			DeleteRowsInATable(TemplatesObject[TabularSection.TabName]		, EntriesRows);
			DeleteRowsInATable(TemplatesObject.EntriesFilters				, EntriesFiltersRows);
			DeleteRowsInATable(TemplatesObject.ElementsSynonyms				, ElementsSynonymsRows);
			DeleteRowsInATable(TemplatesObject.ParametersValues				, ParametersValuesRows);
			DeleteRowsInATable(TemplatesObject.AdditionalEntriesParameters	, AdditionalEntriesParametersRows);
			
		EndDo;
		
		TemplatesObject.Write();
		
		If ShowMessages And AccountingEntriesTemplate <> Undefined Then
			MessageTemplate = NStr("en = '%1, {%2} is removed from Accounting transaction template {%3}'; ru = '%1, {%2} удалены из шаблона бухгалтерских операций {%3}';pl = '%1, {%2} jest usunięty z szablonu transakcji księgowej {%3}';es_ES = '%1, {%2} se elimina de la plantilla de Transacción contable{%3}';es_CO = '%1, {%2} se elimina de la plantilla de Transacción contable{%3}';tr = '%1, {%2} şu Muhasebe işlemi şablonundan çıkarıldı: {%3}';it = '%1, {%2} è rimosso dal modello di transazione Contabilità {%3}';de = '%1, {%2} ist aus der Buchhaltungstransaktionsvorlage {%3} entfernt'");

			MessageText = StrTemplate(MessageTemplate, AccountingEntriesTemplate.Description, AccountingEntriesTemplate.Code, TemplatesObject.Code);
			
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
	EndDo;

EndFunction

Function AreEntriesWithTemplate(Template, NewTemplateParameters) Export
	
	If ValueIsFilled(Template) Then
		
		CurrentData = Common.ObjectAttributesValues(Template, "Status, StartDate, EndDate");
		
		If CurrentData.Status = NewTemplateParameters.Status 
			And CurrentData.StartDate = NewTemplateParameters.StartDate
			And CurrentData.EndDate = NewTemplateParameters.EndDate Then
			
			Return False;
			
		EndIf;
		
		CurrentData.EndDate				= GetEmptyEndDate(CurrentData.EndDate);
		NewTemplateParameters.EndDate	= GetEmptyEndDate(NewTemplateParameters.EndDate);
		
		CurrentData.Insert("StartDate1"	, CurrentData.StartDate);
		CurrentData.Insert("EndDate1"	, CurrentData.EndDate);
		CurrentData.Insert("StartDate2"	, CurrentData.EndDate);
		CurrentData.Insert("EndDate2"	, CurrentData.StartDate);
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	AccountingJournalEntriesCompound.Account AS Account
		|FROM
		|	AccountingRegister.AccountingJournalEntriesCompound AS AccountingJournalEntriesCompound
		|WHERE
		|	AccountingJournalEntriesCompound.TransactionTemplate = &TransactionTemplate
		|	AND AccountingJournalEntriesCompound.Period BETWEEN &PeriodStart1 AND &PeriodEnd1
		|	AND AccountingJournalEntriesCompound.Active
		|
		|UNION ALL
		|
		|SELECT
		|	AccountingJournalEntriesSimple.AccountDr
		|FROM
		|	AccountingRegister.AccountingJournalEntriesSimple AS AccountingJournalEntriesSimple
		|WHERE
		|	AccountingJournalEntriesSimple.TransactionTemplate = &TransactionTemplate
		|	AND AccountingJournalEntriesSimple.Period BETWEEN &PeriodStart1 AND &PeriodEnd1
		|	AND AccountingJournalEntriesSimple.Active
		|
		|UNION ALL
		|
		|SELECT
		|	AccountingJournalEntriesCompound.Account
		|FROM
		|	AccountingRegister.AccountingJournalEntriesCompound AS AccountingJournalEntriesCompound
		|WHERE
		|	AccountingJournalEntriesCompound.TransactionTemplate = &TransactionTemplate
		|	AND AccountingJournalEntriesCompound.Period BETWEEN &PeriodStart2 AND &PeriodEnd2
		|	AND AccountingJournalEntriesCompound.Active
		|
		|UNION ALL
		|
		|SELECT
		|	AccountingJournalEntriesSimple.AccountDr
		|FROM
		|	AccountingRegister.AccountingJournalEntriesSimple AS AccountingJournalEntriesSimple
		|WHERE
		|	AccountingJournalEntriesSimple.TransactionTemplate = &TransactionTemplate
		|	AND AccountingJournalEntriesSimple.Period BETWEEN &PeriodStart2 AND &PeriodEnd2
		|	AND AccountingJournalEntriesSimple.Active";
		
		If NewTemplateParameters.Status = CurrentData.Status Then
			
			If NewTemplateParameters.EndDate < CurrentData.StartDate 
				Or NewTemplateParameters.StartDate > CurrentData.EndDate Then
				
				CurrentData.StartDate2	= NewTemplateParameters.StartDate;
				CurrentData.EndDate2	= NewTemplateParameters.EndDate;
				
			Else
				
				If NewTemplateParameters.StartDate < CurrentData.StartDate Then
					
					CurrentData.StartDate1	= NewTemplateParameters.StartDate;
					CurrentData.EndDate1	= CurrentData.StartDate;
					
				ElsIf NewTemplateParameters.StartDate > CurrentData.StartDate Then
					
					CurrentData.StartDate1	= CurrentData.StartDate;
					CurrentData.EndDate1	= NewTemplateParameters.StartDate;
					
				Else
					
					CurrentData.StartDate1	= Date(1, 1, 2);
					CurrentData.EndDate1	= Date(1, 1, 1);
					
				EndIf;
				
				If NewTemplateParameters.EndDate < CurrentData.EndDate Then
					
					CurrentData.StartDate2	= NewTemplateParameters.EndDate;
					CurrentData.EndDate2	= CurrentData.EndDate;
					
				ElsIf NewTemplateParameters.EndDate > CurrentData.EndDate Then
					
					CurrentData.StartDate2	= CurrentData.EndDate;
					CurrentData.EndDate2	= NewTemplateParameters.EndDate;
					
				Else
					
					CurrentData.StartDate2	= Date(1, 1, 2);
					CurrentData.EndDate2	= Date(1, 1, 1);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		Query.SetParameter("PeriodStart1"		, BegOfDay(CurrentData.StartDate1));
		Query.SetParameter("PeriodEnd1"			, EndOfDay(CurrentData.EndDate1));
		Query.SetParameter("PeriodStart2"		, BegOfDay(CurrentData.StartDate2));
		Query.SetParameter("PeriodEnd2"			, EndOfDay(CurrentData.EndDate2));
		Query.SetParameter("TransactionTemplate", Template);
		
		QueryResult = Query.Execute();
		
		Return Not QueryResult.IsEmpty();
		
	EndIf;
	
	Return False;
	
EndFunction

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)

	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.AccountingTransactionsTemplates);

EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)

	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);

EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)

	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);

EndProcedure

#EndRegion

#Region Internal

#Region InfobaseUpdate

Procedure RenameDataSource() Export 
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Table.Ref AS Ref
	|INTO TT_Refs
	|FROM
	|	Catalog.AccountingTransactionsTemplates.ElementsSynonyms AS Table
	|WHERE
	|	Table.MetadataName = ""DataSource""
	|	AND Table.Synonym LIKE &InventoryDiscrepancyCost1
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Ref
	|FROM
	|	Catalog.AccountingTransactionsTemplates.Entries AS Table
	|WHERE
	|	Table.DataSource LIKE &InventoryDiscrepancyCost2
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Ref
	|FROM
	|	Catalog.AccountingTransactionsTemplates.EntriesSimple AS Table
	|WHERE
	|	Table.DataSource LIKE &InventoryDiscrepancyCost2
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TT_Refs.Ref AS Ref
	|FROM
	|	TT_Refs AS TT_Refs";
	
	Query.SetParameter("InventoryDiscrepancyCost1", "%Inventory - Discrepancy cost%");
	Query.SetParameter("InventoryDiscrepancyCost2", "%InventoryDiscrepancyCost%");
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		CatalogObject = Selection.Ref.GetObject();
		If CatalogObject = Undefined Then
			Continue;
		EndIf;
		
		For Each Row In CatalogObject.Entries Do
			
			Row.DataSource = StrReplace(Row.DataSource, 
				"InventoryDiscrepancyCost",
				"GoodsReceivedNotInvoicedDiscrepancyCost");
			
		EndDo;
		
		For Each Row In CatalogObject.EntriesSimple Do
			
			Row.DataSource = StrReplace(Row.DataSource, 
				"InventoryDiscrepancyCost",
				"GoodsReceivedNotInvoicedDiscrepancyCost");
			
		EndDo;
		
		For Each Row In CatalogObject.ElementsSynonyms Do
			
			Row.Synonym = StrReplace(Row.Synonym,
				"Inventory - Discrepancy cost",
				"Goods received not invoiced - Discrepancy cost");
			
		EndDo;
		
		Try
			
			InfobaseUpdate.WriteObject(CatalogObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save catalog ""%1"". Details: %2'; ru = 'Не удалось записать справочник ""%1"". Подробнее: %2';pl = 'Nie można zapisać katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el catálogo ""%1"". Detalles: %2';tr = '""%1"" kataloğu saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare l''anagrafica ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'", DefaultLanguageCode),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Catalogs.AccountingTransactionsTemplates,
				,
				ErrorDescription);
				
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion 

#EndRegion 

#Region Private

Function CheckStatusChangeAvailable(Template, NewTemplateParameters)

	CurrentData = Common.ObjectAttributesValues(Template, "Status, StartDate, EndDate");
	
	If CurrentData.Status = NewTemplateParameters.Status 
		And CurrentData.StartDate = NewTemplateParameters.StartDate
		And CurrentData.EndDate = NewTemplateParameters.EndDate Then
		
		Return 0;
		
	Else
		
		Return RunTemplateCheck(Template, NewTemplateParameters);
		
	EndIf;

EndFunction

Function RunTemplateCheck(Template, NewTemplateParameters)

	TemplateObject = Template.GetObject();
	FillPropertyValues(TemplateObject, NewTemplateParameters);
	
	CorrectFilling = TemplateObject.CheckFilling();
	
	If CorrectFilling Then
		TemplateObject.Write();
		Return 0;
	Else
		Return 1;
	EndIf;
	
EndFunction

Function CheckNestingPeriod(StartDate, EndDate, NestingStartDate, NestingEndDate)
	
	CheckStartDate = (NestingStartDate >= StartDate);
	
	If Not ValueIsFilled(NestingEndDate) Then
		CheckEndDate = Not ValueIsFilled(EndDate);
	Else
		CheckEndDate = (Not ValueIsFilled(EndDate) Or NestingEndDate <= EndDate);
	EndIf;
	
	Return CheckStartDate And CheckEndDate;
	
EndFunction

Procedure DeleteRowsInATable(Table, Rows)
	
	For Each Row In Rows Do
		
		If Table.IndexOf(Row) > -1 Then
			Table.Delete(Row);
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetEmptyEndDate(Date)
	Return ?(ValueIsFilled(Date), Date, Date(3999, 12, 31));
EndFunction

#EndRegion

#EndIf