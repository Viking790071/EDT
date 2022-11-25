#Region Public

Procedure FillBatchesByFEFO_Selected(Form, Parameters) Export
	
	TableName = Parameters.TableName;
	
	LineNumbers = New Array;
	For Each RowID In Form.Items[TableName].SelectedRows Do
		LineNumbers.Add(Form.Object[TableName].FindByID(RowID).LineNumber);
	EndDo;
	
	LineNumberShift = 0;
	
	For Each CurLineNumer In LineNumbers Do
		RowData = Form.Object[TableName][CurLineNumer + LineNumberShift - 1];
		Form.Items[TableName].CurrentRow = RowData.GetID();
		FillBatchesByFEFO(Form, Parameters, RowData, True, LineNumberShift);
	EndDo;
	
EndProcedure

Procedure FillBatchesByFEFO_All(Form, Parameters) Export
	
	If Parameters.Property("TableName") Then
		TableName = Parameters.TableName;
	Else
		TableName = "Inventory";
	EndIf;
	
	CurLineNumer = 1;
	LineNumberShift = 0;
	
	While CurLineNumer <= Form.Object[TableName].Count() Do
		RowData = Form.Object[TableName][CurLineNumer - 1];
		Form.Items[TableName].CurrentRow = RowData.GetID();
		FillBatchesByFEFO(Form, Parameters, RowData, False, LineNumberShift);
		CurLineNumer = CurLineNumer + 1 + LineNumberShift;
		LineNumberShift = 0;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Procedure FillBatchesByFEFO(Form, Parameters, RowData, ShowMessages, LineNumberShift)
	
	If RowData = Undefined Then
		Return;
	EndIf;
	
	TableName = Parameters.TableName;
	
	Result = Form.Attachable_FillByFEFOData(TableName, ShowMessages);
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	TotalQuantity = RowData.Quantity;
	
	RowInputMode = Form.Items[TableName].RowInputMode;
	Form.Items[TableName].RowInputMode = TableRowInputMode.AfterCurrentRow;
	
	For Each BalanceData In Result Do
		
		RowData.Batch = BalanceData.Batch;
		If Parameters.BatchOnChangeHandler Then
			Form.Attachable_FillBatchesByFEFO_BatchOnChange(TableName);
		EndIf;
		
		RowData.Quantity = Min(BalanceData.Quantity, TotalQuantity);
		If Parameters.QuantityOnChangeHandler Then
			Form.Attachable_FillBatchesByFEFO_QuantityOnChange(TableName, RowData);
		EndIf;
		
		TotalQuantity = TotalQuantity - RowData.Quantity;
		
		If TotalQuantity > 0 Then
			Form.Items[TableName].CopyRow();
			RowData = Form.Items[TableName].CurrentData;
			LineNumberShift = LineNumberShift + 1;
		Else
			Break;
		EndIf;
		
	EndDo;
	
	Form.Items[TableName].EndEditRow(False);
	
	Form.Items[TableName].RowInputMode = RowInputMode;
	
EndProcedure

#EndRegion