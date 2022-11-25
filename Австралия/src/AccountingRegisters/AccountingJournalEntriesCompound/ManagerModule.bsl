#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function GetCompoundPresentation(RecordSetMasterTable) Export
	
	ResultTable = New ValueTable;
	
	ResultTable.Columns.Add("RecordSetPicture");
	ResultTable.Columns.Add("Active");
	ResultTable.Columns.Add("LineNumber");
	ResultTable.Columns.Add("EntryNumber");
	ResultTable.Columns.Add("EntryLineNumber");
	ResultTable.Columns.Add("Period");
	ResultTable.Columns.Add("RecordType");
	ResultTable.Columns.Add("Recorder");
	ResultTable.Columns.Add("Company");
	ResultTable.Columns.Add("Status");
	ResultTable.Columns.Add("PlanningPeriod");
	ResultTable.Columns.Add("Account");
	ResultTable.Columns.Add("ExtDimension1");
	ResultTable.Columns.Add("ExtDimension2");
	ResultTable.Columns.Add("ExtDimension3");
	ResultTable.Columns.Add("ExtDimension4");
	ResultTable.Columns.Add("ExtDimensionType1");
	ResultTable.Columns.Add("ExtDimensionType2");
	ResultTable.Columns.Add("ExtDimensionType3");
	ResultTable.Columns.Add("ExtDimensionType4");
	ResultTable.Columns.Add("ExtDimensionPresentation1");
	ResultTable.Columns.Add("ExtDimensionPresentation2");
	ResultTable.Columns.Add("ExtDimensionPresentation3");
	ResultTable.Columns.Add("ExtDimensionPresentation4");
	ResultTable.Columns.Add("ExtDimensionEnabled1");
	ResultTable.Columns.Add("ExtDimensionEnabled2");
	ResultTable.Columns.Add("ExtDimensionEnabled3");
	ResultTable.Columns.Add("ExtDimensionEnabled4");
	ResultTable.Columns.Add("Currency");
	ResultTable.Columns.Add("CurrencyDr");
	ResultTable.Columns.Add("CurrencyCr");
	ResultTable.Columns.Add("UseQuantity");
	ResultTable.Columns.Add("UseCurrency");
	ResultTable.Columns.Add("Amount");
	ResultTable.Columns.Add("AmountDr");
	ResultTable.Columns.Add("AmountCr");
	ResultTable.Columns.Add("Quantity");
	ResultTable.Columns.Add("QuantityDr");
	ResultTable.Columns.Add("QuantityCr");
	ResultTable.Columns.Add("AmountCur");
	ResultTable.Columns.Add("AmountCurDr");
	ResultTable.Columns.Add("AmountCurCr");
	ResultTable.Columns.Add("OfflineRecord");
	ResultTable.Columns.Add("TypeOfAccounting");
	ResultTable.Columns.Add("Content");
	ResultTable.Columns.Add("TransactionTemplate");
	ResultTable.Columns.Add("TransactionTemplateLineNumber");
	ResultTable.Columns.Add("NumberPresentation");
	
	For Each Record In RecordSetMasterTable Do
		NewRow = ResultTable.Add();
		FillPropertyValues(NewRow, Record);
	EndDo;
	
	Return ResultTable;

EndFunction

Function DecomposeCompoundPresentation(RecordSetMasterSimpleTable, RecordSetMaster, ClearRecordSet = True) Export
	
	If ClearRecordSet Then
		RecordSetMaster.Clear();
	EndIf;
	
	MaxExtDimension = WorkWithArbitraryParametersServerCall.MaxAnalyticalDimensionsNumber();
	
	For Each Row In RecordSetMasterSimpleTable Do
		
		NewRow = RecordSetMaster.Add();
		FillPropertyValues(NewRow, Row);
		
		If Not ValueIsFilled(NewRow.PlanningPeriod) Then
			NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
		EndIf;
		
		If Row.RecordType = AccountingRecordType.Debit Then
			
			NewRow.Amount = Row.AmountDr;
			NewRow.AmountCur = Row.AmountCurDr;
			NewRow.Currency = Row.CurrencyDr;
			NewRow.Quantity = Row.QuantityDr;
			
		Else
			
			NewRow.Amount = Row.AmountCr;
			NewRow.AmountCur = Row.AmountCurCr;
			NewRow.Currency = Row.CurrencyCr;
			NewRow.Quantity = Row.QuantityCr;
			
		EndIf;
		
		For Index = 1 To MaxExtDimension Do
			
			FieldName = MasterAccountingClientServer.GetExtDimensionFieldName(Index);
			FieldTypeName = MasterAccountingClientServer.GetExtDimensionFieldName(Index, , "Type");
			If ValueIsFilled(Row[FieldName]) Then
				NewRow.ExtDimensions.Insert(Row[FieldTypeName], Row[FieldName]);
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndFunction

Procedure SetEntryNumbers(RecordSetTable) Export
	
	If RecordSetTable.Columns.Find("EntryNumber") = Undefined Then
		
		RecordSetTable.Columns.Add("EntryNumber");
		RecordSetTable.Columns.Add("EntryLineNumber");
		
	ElsIf RecordSetTable.Find(0, "EntryNumber") = Undefined
		And RecordSetTable.Find(Undefined, "EntryNumber") = Undefined Then
		Return;
	EndIf;
	
	RecordSetFieldsTemplate = ",
		|	AccountingJournalEntriesCompound.%1 AS %1";
	TemporaryTableFieldsTemplate = ",
		|	TemporaryTableRecordSet.%1 AS %1";
	
	RecordSetFields = "";
	TemporaryTableFields = "";
	
	FieldsEmpty = True;
	
	For Each Column In RecordSetTable.Columns Do
		
		If Column.Name = "PointInTime"
			Or Column.Name = "RecordType"
			Or Column.Name = "TypeOfAccounting"
			Or Column.Name = "TransactionTemplate"
			Or Column.Name = "TransactionTemplateLineNumber" Then
			Continue;
		EndIf;
		
		If FieldsEmpty Then
			
			RecordSetFields = RecordSetFields + StrTemplate(
				"AccountingJournalEntriesCompound.%1 AS %1",
				Column.Name);
			
			TemporaryTableFields = TemporaryTableFields + StrTemplate(
				"TemporaryTableRecordSet.%1 AS %1",
				Column.Name);
			
			FieldsEmpty = False
			
		Else
			
			RecordSetFields = RecordSetFields + StrTemplate(
				RecordSetFieldsTemplate,
				Column.Name);
			
			TemporaryTableFields = TemporaryTableFields + StrTemplate(
				TemporaryTableFieldsTemplate,
				Column.Name);
			
		EndIf;

	EndDo;
	
	Query = New Query;
	
	Query.Text = 
	"SELECT
	|	&RecordSetFields,
	|	AccountingJournalEntriesCompound.RecordType AS RecordType,
	|	AccountingJournalEntriesCompound.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingJournalEntriesCompound.TransactionTemplate AS TransactionTemplate,
	|	AccountingJournalEntriesCompound.TransactionTemplateLineNumber AS TransactionTemplateLineNumber
	|INTO TemporaryTableRecordSet
	|FROM
	|	&RecordSet AS AccountingJournalEntriesCompound
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&TemporaryTableFields,
	|	TemporaryTableRecordSet.RecordType AS RecordType,
	|	TemporaryTableRecordSet.TypeOfAccounting AS TypeOfAccounting,
	|	TemporaryTableRecordSet.TransactionTemplate AS TransactionTemplate,
	|	TemporaryTableRecordSet.TransactionTemplateLineNumber AS TransactionTemplateLineNumber,
	|	AccountingTransactionsTemplatesEntries.EntriesTemplate AS EntriesTemplate
	|FROM
	|	TemporaryTableRecordSet AS TemporaryTableRecordSet
	|		LEFT JOIN Catalog.AccountingTransactionsTemplates.Entries AS AccountingTransactionsTemplatesEntries
	|		ON TemporaryTableRecordSet.TransactionTemplate = AccountingTransactionsTemplatesEntries.Ref
	|			AND TemporaryTableRecordSet.TransactionTemplateLineNumber = AccountingTransactionsTemplatesEntries.LineNumber
	|ORDER BY
	|	TransactionTemplate,
	|	RecordType,
	|	TransactionTemplateLineNumber
	|
	|TOTALS BY
	|	TypeOfAccounting,
	|	TransactionTemplate,
	|	EntriesTemplate";
	
	Query.Text = StrReplace(Query.Text, "&RecordSetFields", RecordSetFields);
	Query.Text = StrReplace(Query.Text, "&TemporaryTableFields", TemporaryTableFields);
	
	Query.SetParameter("RecordSet", RecordSetTable);
	
	QueryResult = Query.Execute();
	
	SelectionTypeOfAccounting = QueryResult.Select(QueryResultIteration.ByGroups);
	
	RecordSetTable.Clear();
	
	While SelectionTypeOfAccounting.Next() Do
		
		EntryNumber = 1;
		EntryLineNumber = 1;
		
		SelectionTransactionTemplate = SelectionTypeOfAccounting.Select(QueryResultIteration.ByGroups);
		
		While SelectionTransactionTemplate.Next() Do
			
			SelectionEntriesTemplate = SelectionTransactionTemplate.Select(QueryResultIteration.ByGroups);
			
			While SelectionEntriesTemplate.Next() Do
				
				Selection = SelectionEntriesTemplate.Select(QueryResultIteration.ByGroups);
				
				While Selection.Next() Do
					
					Row = RecordSetTable.Add();
					
					FillPropertyValues(Row, Selection);
					
					Row.EntryNumber = EntryNumber;
					Row.EntryLineNumber = EntryLineNumber;
					
					EntryLineNumber = EntryLineNumber + 1;
					
				EndDo;
				
				EntryNumber = EntryNumber + 1;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf