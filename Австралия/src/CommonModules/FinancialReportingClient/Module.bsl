#Region Public

Procedure ExpandExistingItemsTree(Form, ItemsTreeData) Export
	
	FoundItems = ItemsTreeData.GetItems();
	If FoundItems.Count() = 1 Then
		RowID = FoundItems[0].GetID();
		Form.Items.ExistingItemsTree.Expand(RowID);
	EndIf;
	
EndProcedure

Procedure FinishEditingReportItem(Form, AdditionalInfo = Undefined) Export
	
	If Form.CheckFilling() Then
		If Not Form.ReadOnly Then
			Form.Write();
			Form.Modified = False;
		EndIf;
		Structure = FinancialReportingClientServer.ReportItemStructure();
		FillPropertyValues(Structure, Form.Object, , "FormulaOperands, ItemTypeAttributes");
		If ValueIsFilled(AdditionalInfo) Then
			For Each KeyValue In AdditionalInfo Do
				Structure.Insert(KeyValue.Key, KeyValue.Value);
			EndDo;
		EndIf;
		Form.Close(Structure);
	EndIf;
	
EndProcedure

Function AddFormulaOperands(Form, NewOperands, OperandsTable, Unique = True) Export
	
	TotalsType = PredefinedValue("Enum.TotalsTypes.BalanceDr");
	ArrayOfAdded = New Array;
	For Each Operand In NewOperands Do
		
		If Operand.IsFolder Then
			Continue;
		EndIf;
		
		ID = OperandName(Operand, OperandsTable, Unique);
		FoundOperand = Undefined;
		If HasIndicator(ID, OperandsTable, FoundOperand) Then
			ArrayOfAdded.Add(FoundOperand);
		ElsIf Operand.IsLinked Then
			AddExistingOperand(Form, OperandsTable, Operand, ArrayOfAdded);
		Else
			NewRow = OperandsTable.Add();
			FillPropertyValues(NewRow, Operand, , "IsLinked");
			NewRow.ID = ID;
			NewRow.Account = Operand.ReportItem;
			NewRow.TotalsType = TotalsType;
			NewRow.AccountIndicatorDimension = Operand.ReportItem;
			ArrayOfAdded.Add(NewRow);
		EndIf;
		
		If Not Form.Modified Then
			Form.Modified = True;
		EndIf;
		
	EndDo;
	
	Return ArrayOfAdded;
	
EndFunction

Procedure AddFormulaText(Form, NewOperands) Export
	
	For Each Operand In NewOperands Do
		
		ID = Operand.ID;
		
		Form.Items.Formula.SelectedText = "[" + ID + "]";
		
		BegOfRow = Undefined; BegOfColumn = Undefined;
		EndOfRow = Undefined; EndOfColumn = Undefined;
		Form.Items.Formula.GetTextSelectionBounds(BegOfRow, BegOfColumn, EndOfRow, EndOfColumn);
		
		BegOfRowPosition = Undefined; BegOfColumnPosition = Undefined;
		EndOfRowPosition = Undefined; EndOfColumnPosition = Undefined;
		If HasOpeningTag(Form.Formula, BegOfRow, BegOfColumn, BegOfRowPosition, BegOfColumnPosition)
			And HasClosingTag(Form.Formula, BegOfRow, BegOfColumn, EndOfRowPosition, EndOfColumnPosition) Then
			
			NewFormula = "";
			
			SelectionBegOfRow = Undefined; SelectionBegOfColumn = Undefined;
			SelectionEndOfRow = Undefined; SelectionEndOfColumn = Undefined;
			For Counter = 1 To StrLineCount(Form.Formula) Do
				If Counter > 1 Then
					NewFormula = NewFormula + Chars.LF;
				EndIf;
				FormulaLine = StrGetLine(Form.Formula, Counter);
				If Counter < BegOfRowPosition Then
					NewFormula = NewFormula + FormulaLine;
				ElsIf Counter = BegOfRowPosition Then
					NewFormula = NewFormula + Left(FormulaLine, BegOfColumnPosition - 1) + "[" + ID + "]";
					SelectionBegOfRow = Counter;
					SelectionBegOfColumn = BegOfColumnPosition;
					SelectionEndOfColumn = BegOfColumnPosition + StrLen(ID);
				EndIf;
				If Counter > EndOfRowPosition Then
					NewFormula = NewFormula + FormulaLine;
				ElsIf Counter = EndOfRowPosition Then
					NewFormula = NewFormula + Mid(FormulaLine, EndOfColumnPosition + 1);
					SelectionEndOfRow = Counter;
				EndIf;
			EndDo;
			
			Form.Formula = NewFormula;
			Form.Items.Formula.SetTextSelectionBounds(SelectionBegOfRow, SelectionBegOfColumn, SelectionEndOfRow, SelectionEndOfColumn);
			
		EndIf;
		
		If Not Form.Modified Then
			Form.Modified = True;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ReportDetailProcessing(ReportForm, Item, Details) Export
	
	If TypeOf(Details) <> Type("Structure") Then
		Return;
	EndIf;
	
	ReportParameters = NewReportParameters();
	FillPropertyValues(ReportParameters, ReportForm);
	FillPropertyValues(ReportParameters, ReportForm.Report);
	If Not Details.Property("Filter") Then
		Details.Insert("Filter", New Structure);
	EndIf;
	If ReportForm.UseFilterByCompanies Then
		Details.Filter.Insert("Company", ReportForm.Companies.UnloadValues());
	EndIf;
	If ReportForm.UseFilterByBusinessUnits Then
		Details.Filter.Insert("BusinessUnit", ReportForm.BusinessUnits.UnloadValues());
	EndIf;
	If ReportForm.UseFilterByLinesOfBusiness Then
		Details.Filter.Insert("LineOfBusiness", ReportForm.LinesOfBusniess.UnloadValues());
	EndIf;
	ReportParameters.Insert("Value", Item.CurrentArea.Text);
	ReportParameters.SettingsAddress = PutToTempStorage(Undefined, ReportForm.UUID);
	DetailsParameters = FinancialReportingServerCall.ReportDetailsParameters(Details, ReportParameters);
	DetailsParameters.AmountsInThousands = ReportForm.Report.AmountsInThousands;
	
	If DetailsParameters = Undefined Or DetailsParameters.Indicator = Undefined Then
		Return;
	EndIf;
	
	Indicator = DetailsParameters.Indicator;
	If Indicator.ItemType = ItemType("AccountingDataIndicator") Then
		
		If TypeOf(Indicator.Account) = Type("ChartOfAccountsRef.PrimaryChartOfAccounts") Then
			OpenManagerialAccountAnalysisReport(DetailsParameters);
		ElsIf TypeOf(Indicator.Account) = Type("ChartOfAccountsRef.FinancialChartOfAccounts") Then
			OpenFinancialAccountAnalysisReport(DetailsParameters);
		Else
			ShowValue(Undefined, Indicator.ReportItem);
		EndIf;
		
	ElsIf Indicator.ItemType = ItemType("UserDefinedCalculatedIndicator") Then
		
		FormParameters = New Structure("GenerateReport", True);
		FormParameters.Insert("DetailsParameters", DetailsParameters);
		OpenForm("Report.FinancialReport.Form", FormParameters, ReportForm, True);
		
	ElsIf Indicator.ItemType = ItemType("UserDefinedFixedIndicator") Then
		
		ShowValue(Undefined, Indicator.UserDefinedFixedIndicator);
		
	ElsIf ReportParameters.ReportType <> Indicator.Owner And ValueIsFilled(Indicator.Owner) Then
		
		FormParameters = New Structure("GenerateReport", True);
		DetailsParameters.ReportType = Indicator.Owner;
		If DetailsParameters.Indicator.ItemType = ItemType("GroupTotal") Then
			DetailsParameters.Indicator = DetailsParameters.EmptyRef;
		EndIf;
		FormParameters.Insert("DetailsParameters", DetailsParameters);
		OpenForm("Report.FinancialReport.Form.ReportForm", FormParameters, ReportForm, True);
		
	EndIf;
	
EndProcedure

Procedure CalculateSpreadsheetDocumentSelectedCellsTotalAmount(TotalAmount, Result, SelectedAreaCache, CalculationAtServerNeeded) Export
	
	If AmountRecalculationNeeded(Result, SelectedAreaCache) Then
		TotalAmount = 0;
		SelectedAreasCount = SelectedAreaCache.Count();
		If SelectedAreasCount = 0
			Or SelectedAreaCache.Property("T") Then // Entire spreadsheet document is selected (Ctrl+A)
			
			SelectedAreaCache.Insert("Amount", 0);
			
		ElsIf SelectedAreasCount = 1 Then
			
			// If small number of cells is selected calculating at client
			For Each KeyValue In SelectedAreaCache Do
				SelectedAreaAddressStructure = KeyValue.Value;
			EndDo;
			
			AreaHeight = SelectedAreaAddressStructure.Bottom - SelectedAreaAddressStructure.Top;
			AreaWidth = SelectedAreaAddressStructure.Right - SelectedAreaAddressStructure.Left;
			
			CalculateAtClient = (AreaHeight + AreaWidth) < 12;
			If CalculateAtClient Then
				AmountInCells = 0;
				For IndexRow = SelectedAreaAddressStructure.Top To SelectedAreaAddressStructure.Bottom Do
					For IndexColumn = SelectedAreaAddressStructure.Left To SelectedAreaAddressStructure.Right Do
						Try
							Cell = Result.Area(IndexRow, IndexColumn, IndexRow, IndexColumn);
							If Cell.Visible = True Then
								If Cell.ContainsValue And TypeOf(Cell.Value) = Type("Number") Then
									AmountInCells = AmountInCells + Cell.Value;
								ElsIf ValueIsFilled(Cell.Text) Then
									AmountInCell = Number(StringFunctionsClientServer.ReplaceCharsWithOther(
										Char(32) + Char(43), Cell.Text, Char(0)));
									AmountInCells = AmountInCells + AmountInCell;
								EndIf;
							EndIf;
						Except
							// No event log record is required
						EndTry;
					EndDo;
				EndDo;
				
				TotalAmount = AmountInCells;
				SelectedAreaCache.Insert("Amount", TotalAmount);
				
			Else
				
				CalculationAtServerNeeded = True;
				
			EndIf;
			
		Else
			
			CalculationAtServerNeeded = True;
			
		EndIf;
		
	Else
		
		TotalAmount = SelectedAreaCache.Amount;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function ItemType(ItemTypeName)
	
	Return PredefinedValue("Enum.FinancialReportItemsTypes." + ItemTypeName);
	
EndFunction

Function HasIndicator(ID, OperandsTable, FoundOperand = Undefined)
	
	For Each OperandRow In OperandsTable Do
		If OperandRow.ID = ID Then
			FoundOperand = OperandRow;
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function OperandName(Operand, OperandsTable, Unique = True)
	
	If Operand.Property("ReportItem")And TypeOf(Operand.ReportItem) = Type("ChartOfAccountsRef.PrimaryChartOfAccounts")
		Or Operand.Property("Account") And ValueIsFilled(Operand.Account) Then
		
		Result = "A" + Operand.Code;
		Result = StrReplace(StrReplace(Result, " ", ""), ".", "_");
		
	Else
		
		Try
			Result = "P" + Format(Number(Operand.Code), "NZ=0; NG=0");
		Except
			Result = "P" + Operand.Code;
		EndTry;
		
	EndIf;
	
	ID = Result;
	If Not Unique Then
		Return ID;
	EndIf;
	
	Counter = 0;
	While HasIndicator(ID, OperandsTable) Do
		Counter = Counter + 1;
		ID = Result + "_" + Format(Counter, "NG=");
	EndDo;
	
	Return ID;
	
EndFunction

Procedure AddExistingOperand(Form, OperandsTable, Operand, ArrayOfAdded)

	OperandData = FinancialReportingClientServer.NewOperandData();
	FillPropertyValues(OperandData, Operand);
	Added = FinancialReportingServerCall.AddExistingOperand(OperandData, Form.MainStorageID);
	
	For Each NewOperand In Added.NewOperands Do
		NewRow = OperandsTable.Add();
		FillPropertyValues(NewRow, NewOperand);
		If IsBlankString(NewRow.ID) Then
			NewRow.ID = OperandName(NewOperand, OperandsTable);
		EndIf;
		ArrayOfAdded.Add(NewOperand);
	EndDo;
	
	If Not IsBlankString(Added.Formula) Then
		If Not IsBlankString(Form.Formula) Then
			Form.Formula = Form.Formula + Chars.LF;
		EndIf;
		Form.Formula = Form.Formula + Added.Formula;
	EndIf;

EndProcedure

Function HasOpeningTag(Formula, RowNumber, ColumnNumber, NewRowNumber = Undefined, NewColumnNumber = Undefined)
	
	HasOpeningTag = False;
	For RowCounter = 1 To RowNumber Do
		RowByNumber = StrGetLine(Formula, RowCounter);
		If RowCounter = RowNumber Then
			End = ColumnNumber;
		Else
			End = StrLen(RowByNumber);
		EndIf;
		For ColumnCounter = 1 To End Do
			If Mid(RowByNumber, ColumnCounter, 1) = "<" Then
				HasOpeningTag = True;
				NewRowNumber = RowCounter;
				NewColumnNumber = ColumnCounter;
			EndIf;
			If Mid(RowByNumber, ColumnCounter, 1) = ">" Then
				HasOpeningTag = False;
			EndIf;
		EndDo;
	EndDo;
	
	Return HasOpeningTag;
	
EndFunction

Function HasClosingTag(Formula, RowNumber, ColumnNumber, NewRowNumber = Undefined, NewColumnNumber = Undefined)
	
	For NewRowNumber = RowNumber To StrLineCount(Formula) Do
		RowByNumber = StrGetLine(Formula, NewRowNumber);
		If NewRowNumber = RowNumber Then
			Begin = ColumnNumber;
		Else
			Begin = 1;
		EndIf;
		For NewColumnNumber = Begin To StrLen(RowByNumber) Do
			Row = RowByNumber;
			If Mid(Row, NewColumnNumber, 1) = "<" Then
				Return False; // looking for the first closing tag
			EndIf;
			If Mid(Row, NewColumnNumber, 1) = ">" Then
				Return True;
			EndIf;
		EndDo;
	EndDo;
	
	Return False;
	
EndFunction

Function NewReportParameters()
	
	Result = New Structure;
	Result.Insert("ReportType");
	Result.Insert("ReportsSet");
	Result.Insert("BeginOfPeriod");
	Result.Insert("EndOfPeriod");
	Result.Insert("DetailsData");
	Result.Insert("SettingsAddress");
	Result.Insert("Company");
	Result.Insert("BusinessUnit");
	Result.Insert("LineOfBusiness");
	Result.Insert("Resource");
	Result.Insert("IndicatorData");
	Return Result;
	
EndFunction

Procedure OpenManagerialAccountAnalysisReport(DetailsParameters)
	
	// until such a report appears
	Return;
	
	AccountAnalysisSetting = DetailsParameters.AccountAnalysisSetting;
	SettingsKey = "FinancialReportDetails";
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", "AccountAnalysisManagerial");
	FormParameters.Insert("PurposeUseKey", SettingsKey);
	FormParameters.Insert("UserSettingsKey", SettingsKey);
	FormParameters.Insert("UserSettings", AccountAnalysisSetting.UserSettings);
	FormParameters.Insert("FixedSettings", AccountAnalysisSetting.FixedSettings);
	FormParameters.Insert("GenerateOnOpen", True);
	
EndProcedure

Procedure OpenFinancialAccountAnalysisReport(DetailsParameters)
	
	// until such a report appears
	Return;
	
	ReportSetting = DetailsParameters.AccountAnalysisSetting;
	
	FormParameters = New Structure("Filter, VariantKey, GenerateOnOpen");
	FormParameters.GenerateOnOpen = True;
	FormParameters.VariantKey = "AccountAnalysis";
	
	FilledSettings = New Structure;
	FilledSettings.Insert("Indicators", False);
	FilledSettings.Insert("Grouping", True);
	FilledSettings.Insert("Filter", False);
	FilledSettings.Insert("OutputData", True);
	
	FormParameters = New Structure;
	FormParameters.Insert("DetailsType", 1);
	FormParameters.Insert("SettingsAddress", ReportSetting.SettingsAddress);
	FormParameters.Insert("GenerateOnOpen", True);
	FormParameters.Insert("DetailsID", "AccountAnalysis");
	FormParameters.Insert("FilledSettings", FilledSettings);
	
EndProcedure

Function AmountRecalculationNeeded(Result, SelectedAreaCache)
	Var SelectedAreaAddressStructure;
	
	SelectedAreas = Result.SelectedAreas;
	SelectedAreasCount = SelectedAreas.Count();
	
	If SelectedAreasCount = 0 Then
		SelectedAreaCache = New Structure;
		Return True;
	EndIf;
	
	ReturnValue = False;
	If TypeOf(SelectedAreaCache) <> Type("Structure") Then
		
		SelectedAreaCache = New Structure;
		ReturnValue = True;
		
	ElsIf SelectedAreas.Count() <> SelectedAreaCache.Count() Then
		
		SelectedAreaCache = New Structure;
		ReturnValue = True;
		
	Else
		
		For AreaIndex = 0 To SelectedAreasCount - 1 Do
			
			SelectedArea = SelectedAreas[AreaIndex];
			AreaName = StrReplace(SelectedArea.Name, ":", "_");
			SelectedAreaCache.Property(AreaName, SelectedAreaAddressStructure);
			
			// Haven't found the needed are in cache, reinitializing cache
			If TypeOf(SelectedAreaAddressStructure) <> Type("Structure") Then
				SelectedAreaCache = New Structure;
				ReturnValue = True;
				Break;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	For AreaIndex = 0 To SelectedAreasCount - 1 Do
		SelectedArea = SelectedAreas[AreaIndex];
		AreaName = StrReplace(SelectedArea.Name, ":", "_");
		
		If TypeOf(SelectedArea) <> Type("SpreadsheetDocumentRange") Then
			SelectedAreaAddressStructure = New Structure;
			SelectedAreaAddressStructure.Insert("Top", 0);
			SelectedAreaAddressStructure.Insert("Bottom", 0);
			SelectedAreaAddressStructure.Insert("Left", 0);
			SelectedAreaAddressStructure.Insert("Right",0);
			SelectedAreaCache.Insert(AreaName, SelectedAreaAddressStructure);
			ReturnValue = True;
			Continue;
		EndIf;
		
		SelectedAreaCache.Property(AreaName, SelectedAreaAddressStructure);
		If TypeOf(SelectedAreaAddressStructure) <> Type("Structure") Then
			SelectedAreaAddressStructure = New Structure;
			SelectedAreaAddressStructure.Insert("Top", 0);
			SelectedAreaAddressStructure.Insert("Bottom",  0);
			SelectedAreaAddressStructure.Insert("Left", 0);
			SelectedAreaAddressStructure.Insert("Right",0);
			SelectedAreaCache.Insert(AreaName, SelectedAreaAddressStructure);
			ReturnValue = True;
		EndIf;
		
		If SelectedAreaAddressStructure.Top <> SelectedArea.Top
			Or SelectedAreaAddressStructure.Bottom <> SelectedArea.Bottom
			Or SelectedAreaAddressStructure.Left <> SelectedArea.Left
			Or SelectedAreaAddressStructure.Right <> SelectedArea.Right Then
				SelectedAreaAddressStructure = New Structure;
				SelectedAreaAddressStructure.Insert("Top", SelectedArea.Top);
				SelectedAreaAddressStructure.Insert("Bottom", SelectedArea.Bottom);
				SelectedAreaAddressStructure.Insert("Left", SelectedArea.Left);
				SelectedAreaAddressStructure.Insert("Right", SelectedArea.Right);
				SelectedAreaCache.Insert(AreaName, SelectedAreaAddressStructure);
				ReturnValue = True;
		EndIf;
		
	EndDo;
	
	Return ReturnValue;
	
EndFunction

#EndRegion