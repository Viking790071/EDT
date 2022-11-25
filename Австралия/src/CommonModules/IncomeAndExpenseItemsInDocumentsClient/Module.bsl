
#Region Public

Function IsIncomeAndExpenseItemsChoiceProcessing(FormName) Export
	
	Return FormName = "CommonForm.IncomeAndExpenseItems";	
	
EndFunction

Procedure IncomeAndExpenseItemsChoiceProcessing(Form, Items) Export

	DocObject = Form.Object;
	TabName = Items.TableName;
	
	If DocObject.Property(TabName) Then 
		TabRow = Form.Items[TabName].CurrentData;
	Else
		TabRow = Form.Object;
	EndIf;
	
	FillPropertyValues(TabRow, Items);
	Form.Modified = True;
	
	If TabName = "Header" Then
		FillPropertyValues(Form, Items);
	EndIf;
	
EndProcedure

Procedure IncomeAndExpenseItemsStartChoice(Form, TabName, StandardProcessing) Export
	
	StandardProcessing = False;
	SelectedRow = Form.Items[TabName].CurrentRow;
	OpenIncomeAndExpenseItemsForm(Form, SelectedRow, TabName);
	
EndProcedure

Procedure OpenIncomeAndExpenseItemsForm(Form, SelectedValue, TabName = "Inventory") Export

	If SelectedValue = Undefined Then
		Return;
	EndIf;

	If Not Form.ReadOnly Then
		Form.LockFormDataForEdit();
	EndIf;

	FormParameters = New Structure;
	
	If TypeOf(SelectedValue) = Type("Structure") And SelectedValue.Property("ShamObject") Then
		FormParameters.Insert("DocObject", SelectedValue.ShamObject);
	Else
		FormParameters.Insert("DocObject", Form.Object);
	EndIf;
	
	FormParameters.Insert("TabName", TabName);
	FormParameters.Insert("SelectedValue", SelectedValue);
	
	OpenForm("CommonForm.IncomeAndExpenseItems", FormParameters, Form);
	
EndProcedure

#Region TableEventHandlers

Procedure TableOnStartEnd(Item, NewRow, Clone) Export
	
	If Not NewRow Or Clone Then
		Return;	
	EndIf;
	
	Item.CurrentData.IncomeAndExpenseItems = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	
EndProcedure

#EndRegion

#EndRegion
