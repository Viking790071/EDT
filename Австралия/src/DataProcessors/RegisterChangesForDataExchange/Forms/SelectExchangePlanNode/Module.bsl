
#Region EventHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	MultipleChoice = False;
	ReadExchangeNodeTree();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	CurParameters = SetFormParameters();
	ExpandNodes(CurParameters.Marked);
	Items.ExchangeNodesTree.CurrentRow = CurParameters.CurrentRow;
EndProcedure

&AtClient
Procedure OnReopen()
	CurParameters = SetFormParameters();
	ExpandNodes(CurParameters.Marked);
	Items.ExchangeNodesTree.CurrentRow = CurParameters.CurrentRow;
EndProcedure

#EndRegion

#Region NodeTreeFormTableItemEventHandlers
//

&AtClient
Procedure ExchangeNodeTreeChoice(Item, RowSelected, Field, StandardProcessing)
	PerformNodeChoice(False);
EndProcedure

&AtClient
Procedure ExchangeNodeTreeMarkOnChange(Item)
	ChangeMark(Items.ExchangeNodesTree.CurrentRow);
EndProcedure

#EndRegion

#Region FormCommandHandlers
//

// Opens the object form that is specified in the configuration for the exchange plan where the node belongs.
&AtClient
Procedure SelectNode(Command)
	PerformNodeChoice(MultipleChoice);
EndProcedure

// Opens node form that specified as an object form.
&AtClient
Procedure ChangeNode(Command)
	KeyRef = Items.ExchangeNodesTree.CurrentData.Ref;
	If KeyRef <> Undefined Then
		OpenForm(GetFormName(KeyRef) + "ObjectForm", New Structure("Key", KeyRef));
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeNodesTreeCode.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExchangeNodesTree.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);

EndProcedure
//

&AtClient
Procedure ExpandNodes(Marked) 
	If Marked <> Undefined Then
		For Each CurID In Marked Do
			curRow = ExchangeNodesTree.FindByID(CurID);
			CurParent = curRow.GetParent();
			If CurParent <> Undefined Then
				Items.ExchangeNodesTree.Expand(CurParent.GetID());
			EndIf;
		EndDo;
	EndIf;
EndProcedure	

&AtClient
Procedure PerformNodeChoice(IsMultiselect)
	
	If IsMultiselect Then
		Data = SelectedNodes();
		If Data.Count() > 0 Then
			NotifyChoice(Data);
		EndIf;
		Return;
	EndIf;
	
	Data = Items.ExchangeNodesTree.CurrentData;
	If Data <> Undefined AND Data.Ref <> Undefined Then
		NotifyChoice(Data.Ref);
	EndIf;
	
EndProcedure

&AtServer
Function SelectedNodes(NewData = Undefined)
	
	If NewData <> Undefined Then
		// Installing
		Marked = New Array;
		InternalMarkSelectedNodes(ThisObject(), ExchangeNodesTree, NewData, Marked);
		Return Marked;
	EndIf;
	
	// Receipt
	Result = New Array;
	For Each CurPlan In ExchangeNodesTree.GetItems() Do
		For Each curRow In CurPlan.GetItems() Do
			If curRow.Check AND curRow.Ref <> Undefined Then
				Result.Add(curRow.Ref);
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Procedure InternalMarkSelectedNodes(CurrentObject, Data, NewData, Marked)
	For Each curRow In Data.GetItems() Do
		If NewData.Find(curRow.Ref) <> Undefined Then
			curRow.Check = True;
			CurrentObject.SetMarksForParents(curRow);
			Marked.Add(curRow.GetID());
		EndIf;
		InternalMarkSelectedNodes(CurrentObject, curRow, NewData, Marked);
	EndDo;
EndProcedure

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function GetFormName(CurrentObject = Undefined)
	Return ThisObject().GetFormName(CurrentObject);
EndFunction	

&AtServer
Procedure ReadExchangeNodeTree()
	Tree = ThisObject().GenerateNodeTree();
	ValueToFormAttribute(Tree,  "ExchangeNodesTree");
EndProcedure

&AtServer
Procedure ChangeMark(DataString)
	DataItem = ExchangeNodesTree.FindByID(DataString);
	ThisObject().ChangeMark(DataItem);
EndProcedure

&AtServer
Function SetFormParameters()
	
	Result = New Structure("CurrentRow, Marked");
	
	// Multiple selection
	Items.ExchangeNodesTreeCheckMark.Visible = Parameters.MultipleChoice;
	// Clearing marks if selection type is changed.
	If Parameters.MultipleChoice <> MultipleChoice Then
		CurrentObject = ThisObject();
		For Each curRow In ExchangeNodesTree.GetItems() Do
			curRow.Check = False;
			CurrentObject.SetMarksForChilds(curRow);
		EndDo;
	EndIf;
	MultipleChoice = Parameters.MultipleChoice;
	
	// Positioning
	If MultipleChoice AND TypeOf(Parameters.ChoiceInitialValue) = Type("Array") Then 
		Marked = SelectedNodes(Parameters.ChoiceInitialValue);
		Result.Marked = Marked;
		If Marked.Count() > 0 Then
			Result.CurrentRow = Marked[0];
		EndIf;
			
	ElsIf Parameters.ChoiceInitialValue <> Undefined Then
		// Single item selection
		Result.CurrentRow = RowIDByNode(ExchangeNodesTree, Parameters.ChoiceInitialValue);
		
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function RowIDByNode(Data, Ref)
	For Each curRow In Data.GetItems() Do
		If curRow.Ref = Ref Then
			Return curRow.GetID();
		EndIf;
		Result = RowIDByNode(curRow, Ref);
		If Result <> Undefined Then 
			Return Result;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

#EndRegion
