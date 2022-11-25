#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function GetChartOfAccounts(Company, TypeOfAccounting, Period) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CompaniesTypesOfAccounting.ChartOfAccounts AS ChartOfAccounts
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(
	|			&Period,
	|			Company = &Company
	|				AND TypeOfAccounting = &TypeOfAccounting) AS CompaniesTypesOfAccounting
	|WHERE
	|	NOT CompaniesTypesOfAccounting.Inactive";
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Period", Period);
	Query.SetParameter("TypeOfAccounting", TypeOfAccounting);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		Return SelectionDetailRecords.ChartOfAccounts;
	EndIf;

EndFunction

Procedure SaveTypesOfAccountingTable(TypesOfAccountingTable, Company, Period, SavedPeriod, TypesOfAccountingToDelete, TypesOfAccountingArray, Cancel) Export
	
	EndDatePeriod = ?(ValueIsFilled(SavedPeriod), SavedPeriod, Period) - 86400;
	CheckTypesOfAccountingArray = New Array;
	For Each Row In TypesOfAccountingTable Do
		
		If Row.StartDate = Period Then
			CheckTypesOfAccountingArray.Add(Row.TypeOfAccounting);
		EndIf;
		
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CompaniesTypesOfAccountingSliceLast.TypeOfAccounting AS TypeOfAccounting,
	|	CompaniesTypesOfAccountingSliceLast.StartDate AS StartDate,
	|	CompaniesTypesOfAccountingSliceLast.EndDate AS EndDate
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(
	|			,
	|			Company = &Company
	|				AND StartDate <> &StartDate
	|				AND TypeOfAccounting IN (&TypeOfAccountingList)) AS CompaniesTypesOfAccountingSliceLast
	|WHERE
	|	CompaniesTypesOfAccountingSliceLast.EndDate <> &EndDate";
	
	Query.SetParameter("Company"				, Company);
	Query.SetParameter("StartDate"				, SavedPeriod);
	Query.SetParameter("EndDate"				, EndDatePeriod);
	Query.SetParameter("TypeOfAccountingList"	, CheckTypesOfAccountingArray);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		While Selection.Next() Do
			
			TypeOfAccountingStructure = New Structure;
			TypeOfAccountingStructure.Insert("TypeOfAccounting"	, Selection.TypeOfAccounting);
			TypeOfAccountingStructure.Insert("StartDate"		, Selection.StartDate);
			TypeOfAccountingStructure.Insert("EndDate"			, Selection.EndDate);
			
			TypesOfAccountingArray.Add(TypeOfAccountingStructure);
			
		EndDo;
		
		Cancel = True;
		Return;
		
	EndIf;
	
	RecordSet = InformationRegisters.CompaniesTypesOfAccounting.CreateRecordSet();
	RecordSet.Filter.Company.Set(Company);
	RecordSet.Filter.Period.Set(Period);
	RecordSet.Read();
	
	RecordSetTable = RecordSet.Unload();
	
	RecordSet.Clear();
	
	ChangedEntriesPostingOptionRowsForCheck = New ValueTable;
	ChangedEntriesPostingOptionRowsForCheck.Columns.Add("TypeOfAccounting"		, New TypeDescription("CatalogRef.TypesOfAccounting"));
	ChangedEntriesPostingOptionRowsForCheck.Columns.Add("StartDate"				, New TypeDescription("Date"));
	ChangedEntriesPostingOptionRowsForCheck.Columns.Add("EndDate"				, New TypeDescription("Date"));
	ChangedEntriesPostingOptionRowsForCheck.Columns.Add("Period"				, New TypeDescription("Date"));
	ChangedEntriesPostingOptionRowsForCheck.Columns.Add("EntriesPostingOption"	, New TypeDescription("EnumRef.AccountingEntriesRegisterOptions"));
	
	For Each TableRow In TypesOfAccountingTable Do
		
		If TableRow.EntriesPostingOptionBeforeEditing <> TableRow.EntriesPostingOption
			And (Not TableRow.Inactive Or TableRow.EndDate >= Period) Then
			
			Record = RecordSet.Add();
			
			FillPropertyValues(Record, TableRow);
			
			Record.Inactive	= False;
			Record.EndDate	= Undefined;
			Record.Company	= Company;
			Record.Period	= Period;
			
			If TableRow.Inactive Then
				NewRow = ChangedEntriesPostingOptionRowsForCheck.Add();
				FillPropertyValues(NewRow, Record);
			EndIf;
			
		ElsIf TableRow.StartDate = Period
			And Not TableRow.Inactive
			Or TableRow.EndDate = Period - 86400 Then
			
			Record = RecordSet.Add();
			
			FillPropertyValues(Record, TableRow);
			
			Record.Company	= Company;
			Record.Period	= Period;
			
		ElsIf TableRow.StartDate = Period And TableRow.Inactive Then
			
			Record = RecordSet.Add();
			
			FillPropertyValues(Record, TableRow);
			
			Record.Inactive	= False;
			Record.EndDate	= Undefined;
			Record.Company	= Company;
			Record.Period	= Period;
			
		ElsIf TableRow.Inactive And ValueIsFilled(TableRow.EndDateBeforeEditing) Then
			
			AddedEarlierRow = RecordSetTable.Find(TableRow.TypeOfAccounting, "TypeOfAccounting");
			
			If AddedEarlierRow <> Undefined Then
				Record = RecordSet.Add();
				FillPropertyValues(Record, AddedEarlierRow);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	RecordSet.Write();
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	EditedRowsForCheck.TypeOfAccounting AS TypeOfAccounting,
	|	EditedRowsForCheck.Period AS Period,
	|	EditedRowsForCheck.StartDate AS StartDate,
	|	EditedRowsForCheck.EntriesPostingOption AS EntriesPostingOption
	|INTO EditedRowsForCheck
	|FROM
	|	&EditedRowsForCheck AS EditedRowsForCheck
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompaniesTypesOfAccountingSliceLast.Period AS Period,
	|	CompaniesTypesOfAccountingSliceLast.Company AS Company,
	|	CompaniesTypesOfAccountingSliceLast.TypeOfAccounting AS TypeOfAccounting,
	|	CompaniesTypesOfAccountingSliceLast.StartDate AS StartDate,
	|	CompaniesTypesOfAccountingSliceLast.EntriesPostingOption AS EntriesPostingOption,
	|	CompaniesTypesOfAccountingSliceLast.ChartOfAccounts AS ChartOfAccounts,
	|	CompaniesTypesOfAccountingSliceLast.Inactive AS Inactive,
	|	CompaniesTypesOfAccountingSliceLast.EndDate AS EndDate
	|INTO SliceLastData
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(
	|			,
	|			Company = &Company
	|				AND (TypeOfAccounting, StartDate) IN
	|					(SELECT
	|						EditedRowsForCheck.TypeOfAccounting AS TypeOfAccounting,
	|						EditedRowsForCheck.StartDate AS StartDate
	|					FROM
	|						EditedRowsForCheck AS EditedRowsForCheck)) AS CompaniesTypesOfAccountingSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(CompaniesTypesOfAccounting.Period) AS Period,
	|	CompaniesTypesOfAccounting.Company AS Company,
	|	CompaniesTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting,
	|	CompaniesTypesOfAccounting.StartDate AS StartDate
	|INTO BeforeTheLastDates
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting AS CompaniesTypesOfAccounting
	|		INNER JOIN SliceLastData AS SliceLastData
	|		ON CompaniesTypesOfAccounting.Period < SliceLastData.Period
	|
	|GROUP BY
	|	CompaniesTypesOfAccounting.Company,
	|	CompaniesTypesOfAccounting.TypeOfAccounting,
	|	CompaniesTypesOfAccounting.StartDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompaniesTypesOfAccounting.Company AS Company,
	|	CompaniesTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting,
	|	CompaniesTypesOfAccounting.StartDate AS StartDate,
	|	CompaniesTypesOfAccounting.EntriesPostingOption AS EntriesPostingOption,
	|	BeforeTheLastDates.Period AS Period
	|INTO BeforeTheLastData
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting AS CompaniesTypesOfAccounting
	|		INNER JOIN BeforeTheLastDates AS BeforeTheLastDates
	|		ON CompaniesTypesOfAccounting.Period = BeforeTheLastDates.Period
	|			AND CompaniesTypesOfAccounting.Company = BeforeTheLastDates.Company
	|			AND CompaniesTypesOfAccounting.TypeOfAccounting = BeforeTheLastDates.TypeOfAccounting
	|			AND CompaniesTypesOfAccounting.StartDate = BeforeTheLastDates.StartDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BeforeTheLastData.Company AS Company,
	|	BeforeTheLastData.TypeOfAccounting AS TypeOfAccounting,
	|	BeforeTheLastData.StartDate AS StartDate,
	|	CASE
	|		WHEN EditedRowsForCheck.Period < BeforeTheLastData.Period
	|			THEN BeforeTheLastData.EntriesPostingOption
	|		ELSE EditedRowsForCheck.EntriesPostingOption
	|	END AS EntriesPostingOption,
	|	BeforeTheLastData.Period AS Period
	|INTO BeforeLastUnionData
	|FROM
	|	BeforeTheLastData AS BeforeTheLastData
	|		INNER JOIN EditedRowsForCheck AS EditedRowsForCheck
	|		ON BeforeTheLastData.TypeOfAccounting = EditedRowsForCheck.TypeOfAccounting
	|			AND BeforeTheLastData.StartDate = EditedRowsForCheck.StartDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SliceLastData.Period AS Period,
	|	SliceLastData.Company AS Company,
	|	SliceLastData.TypeOfAccounting AS TypeOfAccounting,
	|	SliceLastData.StartDate AS StartDate,
	|	BeforeLastUnionData.EntriesPostingOption AS EntriesPostingOption,
	|	SliceLastData.ChartOfAccounts AS ChartOfAccounts,
	|	SliceLastData.Inactive AS Inactive,
	|	SliceLastData.EndDate AS EndDate
	|FROM
	|	BeforeLastUnionData AS BeforeLastUnionData
	|		INNER JOIN SliceLastData AS SliceLastData
	|		ON BeforeLastUnionData.Company = SliceLastData.Company
	|			AND BeforeLastUnionData.TypeOfAccounting = SliceLastData.TypeOfAccounting
	|			AND BeforeLastUnionData.StartDate = SliceLastData.StartDate
	|			AND BeforeLastUnionData.EntriesPostingOption <> SliceLastData.EntriesPostingOption";
	
	Query.SetParameter("EditedRowsForCheck"	, ChangedEntriesPostingOptionRowsForCheck);
	Query.SetParameter("Company"			, Company);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		RecordEndDate = InformationRegisters.CompaniesTypesOfAccounting.CreateRecordManager();
		
		FillPropertyValues(RecordEndDate, SelectionDetailRecords);
		
		RecordEndDate.Write();
		
	EndDo;
	
	For Each Row In TypesOfAccountingToDelete Do
		
		RecordSet = InformationRegisters.CompaniesTypesOfAccounting.CreateRecordSet();
		RecordSet.Filter.Company.Set(Company);
		RecordSet.Filter.TypeOfAccounting.Set(Row.TypeOfAccounting);
		RecordSet.Filter.StartDate.Set(Row.StartDate);
		RecordSet.Write();
		
	EndDo;
	
	// Rebuild changed start date
	If Period <> SavedPeriod Then
		
		RecordSet = InformationRegisters.CompaniesTypesOfAccounting.CreateRecordSet();
		RecordSet.Filter.Company.Set(Company);
		RecordSet.Filter.Period.Set(SavedPeriod);
		RecordSet.Write();
		
		RecordSetOldStartDate = InformationRegisters.CompaniesTypesOfAccounting.CreateRecordSet();
		RecordSetOldStartDate.Filter.Company.Set(Company);
		RecordSetOldStartDate.Filter.StartDate.Set(SavedPeriod);
		RecordSetOldStartDate.Read();
		
		For Each Record In RecordSetOldStartDate Do
			
			RecordEndDate = InformationRegisters.CompaniesTypesOfAccounting.CreateRecordManager();
			
			FillPropertyValues(RecordEndDate, Record);
			
			RecordEndDate.Company	= Company;
			RecordEndDate.StartDate	= Period;
			
			RecordEndDate.Write();
			
		EndDo;
		
		RecordSetOldStartDate.Clear();
		RecordSetOldStartDate.Write();
		
	EndIf;
	
EndProcedure

Procedure DeleteRecords(Company, Period, TypesOfAccountingArray, Cancel) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	CompaniesTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting,
	|	CompaniesTypesOfAccounting.StartDate AS StartDate
	|INTO TypesOfAccountsTable
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting AS CompaniesTypesOfAccounting
	|WHERE
	|	CompaniesTypesOfAccounting.Company = &Company
	|	AND CompaniesTypesOfAccounting.Period = &Period
	|	AND NOT CompaniesTypesOfAccounting.Inactive
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompaniesTypesOfAccountingSliceLast.TypeOfAccounting AS TypeOfAccounting,
	|	CompaniesTypesOfAccountingSliceLast.Period AS Period
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(
	|			,
	|			Company = &Company
	|				AND (TypeOfAccounting, StartDate) IN
	|					(SELECT
	|						TypesOfAccountsTable.TypeOfAccounting AS TypeOfAccounting,
	|						TypesOfAccountsTable.StartDate AS StartDate
	|					FROM
	|						TypesOfAccountsTable AS TypesOfAccountsTable)) AS CompaniesTypesOfAccountingSliceLast
	|WHERE
	|	CompaniesTypesOfAccountingSliceLast.Inactive
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TypesOfAccountsTable.TypeOfAccounting AS TypeOfAccounting
	|FROM
	|	TypesOfAccountsTable AS TypesOfAccountsTable";
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Period", Period);
	
	QueryResultArray = Query.ExecuteBatch();
	
	If Not QueryResultArray[1].IsEmpty() Then
		
		Selection = QueryResultArray[1].Select();
		While Selection.Next() Do
			
			TypeOfAccountingStructure = New Structure;
			TypeOfAccountingStructure.Insert("TypeOfAccounting"	, Selection.TypeOfAccounting);
			TypeOfAccountingStructure.Insert("Period"			, Selection.Period);
			
			TypesOfAccountingArray.Add(TypeOfAccountingStructure);
			
		EndDo;
		
		Cancel = True;
		Return;
		
	EndIf;
	
	Selection = QueryResultArray[2].Select();
	While Selection.Next() Do
		
		RecordSet = InformationRegisters.AccountingSourceDocuments.CreateRecordSet();
		RecordSet.Filter.Company.Set(Company);
		RecordSet.Filter.TypeOfAccounting.Set(Selection.TypeOfAccounting);
		RecordSet.Filter.Period.Set(Period);
		RecordSet.Write();
		
	EndDo;
	
	RecordSet = InformationRegisters.CompaniesTypesOfAccounting.CreateRecordSet();
	RecordSet.Filter.Company.Set(Company);
	RecordSet.Filter.Period.Set(Period);
	RecordSet.Write();
	
EndProcedure

Function GetTypesOfAccountingTable(Company, Val Period = Undefined) Export
	
	CommonClientServer.Validate(
		ValueIsFilled(Company),
		NStr("en = 'Company is not filled'; ru = 'Не указана организация';pl = 'Firma nie jest wypełniona';es_ES = 'La empresa no está rellenada.';es_CO = 'La empresa no está rellenada.';tr = 'İş yeri doldurulmadı';it = 'Azienda non compilata';de = 'Firma ist nicht ausgefüllt.'"),
		"InformationRegister.CompaniesTypesOfAccounting.GetTypesOfAccountingTable");
	
	If Not ValueIsFilled(Period) Then
		Period = CurrentSessionDate();
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	CompaniesTypesOfAccounting.TypeOfAccounting AS TypeOfAccounting,
	|	CompaniesTypesOfAccounting.ChartOfAccounts AS ChartOfAccounts,
	|	ChartsOfAccounts.TypeOfEntries AS TypeOfEntries,
	|	CompaniesTypesOfAccounting.EntriesPostingOption AS EntriesPostingOption
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(&Period, Company = &Company) AS CompaniesTypesOfAccounting
	|		INNER JOIN Catalog.ChartsOfAccounts AS ChartsOfAccounts
	|		ON CompaniesTypesOfAccounting.ChartOfAccounts = ChartsOfAccounts.Ref
	|WHERE
	|	NOT CompaniesTypesOfAccounting.Inactive";
	
	Query.SetParameter("Period", Period);
	Query.SetParameter("Company", Company);
	
	Return Query.Execute().Unload();
	
EndFunction

#EndRegion

#EndIf