#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function GetSimplePresentation(RecordSetMasterTable) Export

	ResultTable = New ValueTable;
	ResultTable.Columns.Add("LineNumber");
	ResultTable.Columns.Add("Recorder");
	ResultTable.Columns.Add("Active");
	ResultTable.Columns.Add("Period");
	ResultTable.Columns.Add("Company");
	ResultTable.Columns.Add("PlanningPeriod");
	ResultTable.Columns.Add("UseCurrencyDr");
	ResultTable.Columns.Add("UseCurrencyCr");
	ResultTable.Columns.Add("CurrencyDr");
	ResultTable.Columns.Add("CurrencyCr");
	ResultTable.Columns.Add("Status");
	ResultTable.Columns.Add("TypeOfAccounting");
	ResultTable.Columns.Add("AccountDr");
	ResultTable.Columns.Add("RecordType");
	ResultTable.Columns.Add("Amount");
	ResultTable.Columns.Add("AmountCur");
	ResultTable.Columns.Add("Content");
	ResultTable.Columns.Add("OfflineRecord");
	ResultTable.Columns.Add("TransactionTemplate");
	ResultTable.Columns.Add("TransactionTemplateLineNumber");
	ResultTable.Columns.Add("RecordSetPicture");
	ResultTable.Columns.Add("AmountCr");
	ResultTable.Columns.Add("AmountDr");
	ResultTable.Columns.Add("UseQuantityDr");
	ResultTable.Columns.Add("UseQuantityCr");
	ResultTable.Columns.Add("QuantityCr");
	ResultTable.Columns.Add("QuantityDr");
	ResultTable.Columns.Add("AmountCurCr");
	ResultTable.Columns.Add("AmountCurDr");
	ResultTable.Columns.Add("AccountCr");
	ResultTable.Columns.Add("ExtDimensionDr1");
	ResultTable.Columns.Add("ExtDimensionDr2");
	ResultTable.Columns.Add("ExtDimensionDr3");
	ResultTable.Columns.Add("ExtDimensionDr4");
	ResultTable.Columns.Add("ExtDimensionCr1");
	ResultTable.Columns.Add("ExtDimensionCr2");
	ResultTable.Columns.Add("ExtDimensionCr3");
	ResultTable.Columns.Add("ExtDimensionCr4");
	ResultTable.Columns.Add("ExtDimensionTypeDr1");
	ResultTable.Columns.Add("ExtDimensionTypeDr2");
	ResultTable.Columns.Add("ExtDimensionTypeDr3");
	ResultTable.Columns.Add("ExtDimensionTypeDr4");
	ResultTable.Columns.Add("ExtDimensionTypeCr1");
	ResultTable.Columns.Add("ExtDimensionTypeCr2");
	ResultTable.Columns.Add("ExtDimensionTypeCr3");
	ResultTable.Columns.Add("ExtDimensionTypeCr4");
	ResultTable.Columns.Add("ExtDimensionPresentationDr1");
	ResultTable.Columns.Add("ExtDimensionPresentationDr2");
	ResultTable.Columns.Add("ExtDimensionPresentationDr3");
	ResultTable.Columns.Add("ExtDimensionPresentationDr4");
	ResultTable.Columns.Add("ExtDimensionPresentationCr1");
	ResultTable.Columns.Add("ExtDimensionPresentationCr2");
	ResultTable.Columns.Add("ExtDimensionPresentationCr3");
	ResultTable.Columns.Add("ExtDimensionPresentationCr4");
	ResultTable.Columns.Add("ExtDimensionEnabledDr1");
	ResultTable.Columns.Add("ExtDimensionEnabledDr2");
	ResultTable.Columns.Add("ExtDimensionEnabledDr3");
	ResultTable.Columns.Add("ExtDimensionEnabledDr4");
	ResultTable.Columns.Add("ExtDimensionEnabledCr1");
	ResultTable.Columns.Add("ExtDimensionEnabledCr2");
	ResultTable.Columns.Add("ExtDimensionEnabledCr3");
	ResultTable.Columns.Add("ExtDimensionEnabledCr4");
	
	For Each Record In RecordSetMasterTable Do
		NewRow = ResultTable.Add();
		FillPropertyValues(NewRow, Record);
	EndDo;
	
	Return ResultTable;

EndFunction

Function DecomposeSimplePresentation(RecordSetMasterSimpleTable, RecordSetMaster, ClearRecordSet = True) Export
	
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
		
		For Index = 1 To MaxExtDimension Do
			
			FieldName = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr");
			FieldTypeName = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Type");
			If ValueIsFilled(Row[FieldName]) Then
				NewRow.ExtDimensionsDr.Insert(Row[FieldTypeName], Row[FieldName]);
			EndIf;
			
			FieldName = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr");
			FieldTypeName = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Type");
			If ValueIsFilled(Row[FieldName]) Then
				NewRow.ExtDimensionsCr.Insert(Row[FieldTypeName], Row[FieldName]);
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndFunction

#EndRegion

#EndIf