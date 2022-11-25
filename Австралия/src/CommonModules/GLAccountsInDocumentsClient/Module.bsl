
#Region Public

Function IsGLAccountsChoiceProcessing(FormName) Export
	
	Return FormName = "CommonForm.CounterpartyGLAccounts"
		Or FormName = "CommonForm.ProductGLAccounts";	
	
EndFunction

Procedure GLAccountsChoiceProcessing(Form, GLAccounts) Export

	DocObject = Form.Object;
	TabName = GLAccounts.TableName;
	
	If DocObject.Property(TabName) Then
		TabRow = Form.Items[TabName].CurrentData;
	Else
		TabRow = Form.Object;
	EndIf;
	
	FillPropertyValues(TabRow, GLAccounts);
	Form.Modified = True;
	
	CheckItemRegistration(DocObject, TabName, TabRow);
	
	If Not DocObject.Property(TabName) Then
		If TabName = "Header" Then
			Form["GLAccounts"] = GLAccounts.GLAccounts;
		Else
			Form["GLAccounts" + TabName] = GLAccounts.GLAccounts;
		EndIf;
	EndIf;
	
EndProcedure

Procedure GLAccountsStartChoice(Form, TabName, StandardProcessing) Export
	
	StandardProcessing = False;
	SelectedRow = Form.Items[TabName].CurrentRow;
	OpenCounterpartyGLAccountsForm(Form, SelectedRow, TabName);
	
EndProcedure

Procedure OpenCounterpartyGLAccountsForm(Form, SelectedValue, TabName = "PaymentDetails") Export

	If SelectedValue = Undefined Then
		Return;
	EndIf;

	If Not Form.ReadOnly Then
		Form.LockFormDataForEdit();
	EndIf;

	FormParameters = New Structure;
	FormParameters.Insert("DocObject", Form.Object);
	FormParameters.Insert("TabName", TabName);
	FormParameters.Insert("SelectedValue", SelectedValue);
	FormParameters.Insert("CounterpartyGLAccounts", True);
	
	OpenForm("CommonForm.CounterpartyGLAccounts", FormParameters, Form);
	
EndProcedure

Procedure OpenProductGLAccountsForm(Form, SelectedValue, TabName = "Inventory", AttributeName = "Products", IsReadOnly = False) Export

	If SelectedValue = Undefined Then
		Return;
	EndIf;

	If Not Form.ReadOnly Then
		Form.LockFormDataForEdit();
	EndIf;

	FormParameters = New Structure;
	FormParameters.Insert("DocObject", Form.Object);
	FormParameters.Insert("TabName", TabName);
	FormParameters.Insert("SelectedValue", SelectedValue);
	FormParameters.Insert("AttributeName", AttributeName);
	FormParameters.Insert("ProductGLAccounts", True);
	FormParameters.Insert("IsReadOnly", IsReadOnly);
	
	OpenForm("CommonForm.ProductGLAccounts", FormParameters, Form);
	
EndProcedure

#Region TableEventHandlers

Procedure TableOnActivateCell(Form, TabName, ThisIsNewRow) Export
	
	CurrentData = Form.Items[TabName].CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Form.Items[TabName].CurrentItem;
		If TableCurrentColumn.Name = TabName + "GLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Form.Items[TabName].CurrentRow;
			OpenCounterpartyGLAccountsForm(Form, SelectedRow, TabName);
		EndIf;
	EndIf;
	
EndProcedure

Procedure TableOnStartEnd(Item, NewRow, Clone) Export
	
	If Not NewRow Or Clone Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	
EndProcedure

Procedure TableOnEditEnd(ThisIsNewRow) Export
	
	ThisIsNewRow = False;
	
EndProcedure

Procedure TableSelection(Form, TabName, SelectedRow, Field, StandardProcessing) Export
	
	If Field.Name = TabName + "GLAccounts" Then
		StandardProcessing = False;
		OpenCounterpartyGLAccountsForm(Form, SelectedRow, TabName);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

Procedure CheckItemRegistration(DocObject, TabName, TabRow)
	
	Structure = New Structure("IncomeAndExpenseItems");
	FillPropertyValues(Structure,TabRow);
	
	If Structure.IncomeAndExpenseItems = Undefined Then
		Return;
	EndIf;
	
	If TabName = "" Then
		TabName = "Header";
	EndIf;
	
	StructureData = IncomeAndExpenseItemsInDocumentsServerCall.GetIncomeAndExpenseStructureData(DocObject, TabName);
	FillPropertyValues(StructureData, DocObject);
	FillPropertyValues(StructureData, TabRow);
	
	IncomeAndExpenseItemsGLAMap = GLAccountsInDocumentsServerCall.GetIncomeAndExpenseItemsGLAMap(DocObject.Ref, StructureData);
	If IncomeAndExpenseItemsGLAMap.Count() = 0 Then
		Return;
	EndIf;
	
	StructureData.Insert("Manual", True);
	
	ListOfProperties = "IncomeAndExpenseItems,IncomeAndExpenseItemsFilled";
	ListOfRegisterProperties = "";
	For Each Elem In IncomeAndExpenseItemsGLAMap Do
		If TypeOf(Elem.Value) = Type("Array") Then
			For Each Value In Elem.Value Do
				ListOfProperties = ListOfProperties + "," + Value;
				RegisterItemName = "Register" + Left(Value, StrLen(Value)-4);
				ListOfRegisterProperties = ListOfRegisterProperties + RegisterItemName;
			EndDo;
		Else
			ListOfProperties = ListOfProperties + "," + Elem.Value;
			RegisterItemName = "Register" + Left(Elem.Value, StrLen(Elem.Value)-4);
			ListOfRegisterProperties = ListOfRegisterProperties + RegisterItemName;
		EndIf;
	EndDo;
	
	Structure = New Structure(ListOfRegisterProperties);
	FillPropertyValues(Structure, TabRow);
	For Each Elem In Structure Do
		If Elem.Value <> Undefined Then
			ListOfProperties = ListOfProperties + "," + Elem.Key;
		EndIf;
	EndDo;
	
	GLAccountsInDocumentsServerCall.CheckItemRegistration(StructureData);
	FillPropertyValues(TabRow, StructureData, ListOfProperties);
	
EndProcedure

#EndRegion
