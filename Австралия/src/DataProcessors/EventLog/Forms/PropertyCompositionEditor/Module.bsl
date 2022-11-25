
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ListToEdit = Parameters.ListToEdit;
	ParametersToSelect = Parameters.ParametersToSelect;
	
	SetEditorParameters(ListToEdit, ParametersToSelect);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CheckOnChange(Item)
	SelectTreeItem(Items.List.CurrentData, Items.List.CurrentData.Check);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SelectFilterComposition(Command)
	
	Notify("EventLogFilterItemValueChoice",
	           GetEditedList(),
	           FormOwner);
	Close();
	
EndProcedure

&AtClient
Procedure SelectAllCheckBoxes()
	SetMarks(True);
EndProcedure

&AtClient
Procedure ClearAllCheckBoxes()
	SetMarks(False);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetEditorParameters(ListToEdit, ParametersToSelect)
	FilterParameterStructure = GetEventLogFilterValues(ParametersToSelect);
	FilterValues = FilterParameterStructure[ParametersToSelect];
	// Getting a list of event presentations.
	If ParametersToSelect = "Event" Or ParametersToSelect = "Event" Then
		
		For Each MapItem In FilterValues Do
			EventPresentationString = EventPresentations.Add();
			EventPresentationString.Presentation = MapItem.Value;
		EndDo;
		
	EndIf;
	
	If TypeOf(FilterValues) = Type("Array") Then
		ListItems = List.GetItems();
		For Each ArrayElement In FilterValues Do
			NewItem = ListItems.Add();
			NewItem.Check = False;
			NewItem.Value = ArrayElement;
			NewItem.Presentation = ArrayElement;
		EndDo;
	ElsIf TypeOf(FilterValues) = Type("Map") Then
		
		If ParametersToSelect = "Event"
			Or ParametersToSelect = "Event"
			Or ParametersToSelect = "Metadata"
			Or ParametersToSelect = "Metadata" Then
			
			// Getting as a tree.
			For Each MapItem In FilterValues Do
				NewItem = GetTreeBranch(MapItem.Value, ParametersToSelect);
				NewItem.Check = False;
				If IsBlankString(NewItem.Value) Then
					NewItem.Value = MapItem.Key;
				Else
					NewItem.Value = NewItem.Value + Chars.LF + MapItem.Key;
				EndIf;
				NewItem.FullPresentation = MapItem.Value;
			EndDo;
			
		Else 
			// Getting as a flat list.
			ListItems = List.GetItems();
			For Each MapItem In FilterValues Do
				NewItem = ListItems.Add();
				NewItem.Check = False;
				NewItem.Value = MapItem.Key;
				
				If (ParametersToSelect = "User" Or ParametersToSelect = "User") Then
					// In this case the username serves as a key.
					NewItem.Value = MapItem.Value;
					NewItem.Presentation = MapItem.Value;
					NewItem.FullPresentation = MapItem.Value;
					
					If NewItem.Value = "" Then
						// In case of default user.
						NewItem.Value = "";
						NewItem.FullPresentation = UnspecifiedUserFullName();
						NewItem.Presentation = UnspecifiedUserFullName();
					Else
						// In case of internal user.
						InternalUserPresentation = InternalUserFullName(MapItem.Key);
						If Not IsBlankString(InternalUserPresentation) Then
							
							NewItem.FullPresentation = InternalUserPresentation;
							NewItem.Presentation = InternalUserPresentation;
							
						EndIf;
					EndIf;
					
				Else
					NewItem.Presentation = MapItem.Value;
					NewItem.FullPresentation = MapItem.Value;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	// Selecting marks of tree items that are mapped to ListToEdit items.
	SelectFoundItems(List.GetItems(), ListToEdit);
	
	// Finding child items in the list. If there are no such items, switching the control to a list mode.
	// 
	IsTree = False;
	For Each TreeItem In List.GetItems() Do
		If TreeItem.GetItems().Count() > 0 Then 
			IsTree = True;
			Break;
		EndIf;
	EndDo;
	If Not IsTree Then
		Items.List.Representation = TableRepresentation.List;
	EndIf;
	
	OrderTreeItems();
	
EndProcedure

&AtClient
Function GetEditedList()
	
	ListToEdit = New ValueList;
	
	ListToEdit.Clear();
	HasNotSelected = False;
	FillListToEdit(ListToEdit, List.GetItems(), HasNotSelected);
	
	Return ListToEdit;
	
EndFunction

&AtServer
Function GetTreeBranch(Presentation, ParametersToSelect, Recursion = False)
	PathStrings = StringFunctionsClientServer.SplitStringIntoSubstringsArray(Presentation, ".", True, True);
	If (ParametersToSelect = "Metadata"
			Or ParametersToSelect = "Metadata")
		AND PathStrings.Count() > 2 Then
		ObjectName = PathStrings[0];
		PathStrings.Delete(0);
		MetadataObjectName = StrConcat(PathStrings, ". ");
		PathStrings = New Array;
		PathStrings.Add(ObjectName);
		PathStrings.Add(MetadataObjectName);
	EndIf;
	
	If PathStrings.Count() = 1 Then
		TreeItems = List.GetItems();
		BranchName = PathStrings[0];
	Else
		// Assembling a path to the parent branch by path fragments.
		ParentPathPresentation = "";
		For Cnt = 0 To PathStrings.Count() - 2 Do
			If Not IsBlankString(ParentPathPresentation) Then
				ParentPathPresentation = ParentPathPresentation + ".";
			EndIf;
			ParentPathPresentation = ParentPathPresentation + PathStrings[Cnt];
		EndDo;
		TreeItems = GetTreeBranch(ParentPathPresentation, ParametersToSelect, True).GetItems();
		BranchName = PathStrings[PathStrings.Count() - 1];
	EndIf;
	
	For Each TreeItem In TreeItems Do
		If TreeItem.Presentation = BranchName Then
			If PathStrings.Count() = 1 AND Not Recursion Then
				Break;
			EndIf;
			Return TreeItem;
		EndIf;
	EndDo;
	// The tree item is not found, it has to be created.
	TreeItem = TreeItems.Add();
	TreeItem.Presentation = BranchName;
	TreeItem.Check = False;
	Return TreeItem;
EndFunction

&AtClient
Procedure FillListToEdit(ListToEdit, TreeItems, HasNotSelected)
	For Each TreeItem In TreeItems Do
		If TreeItem.GetItems().Count() <> 0 Then
			FillListToEdit(ListToEdit, TreeItem.GetItems(), HasNotSelected);
		Else
			If TreeItem.Check Then
				NewListItem = ListToEdit.Add();
				NewListItem.Value      = TreeItem.Value;
				NewListItem.Presentation = TreeItem.FullPresentation;
			Else
				HasNotSelected = True;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

&AtServer
Procedure SelectFoundItems(TreeItems, ListToEdit)
	
	For Each TreeItem In TreeItems Do
		If TreeItem.GetItems().Count() <> 0 Then
			SelectFoundItems(TreeItem.GetItems(), ListToEdit);
		Else
			For Each ListItem In ListToEdit Do
				If TreeItem.FullPresentation = ListItem.Presentation Then
					TreeItem.Check = True;
					CheckBranchMarked(TreeItem.GetParent());
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure SelectTreeItem(TreeItem, Mark, CheckBranchMarked = True)
	TreeItem.Check = Mark;
	// Selecting marks of all child items of the tree.
	For Each TreeChildItem In TreeItem.GetItems() Do
		SelectTreeItem(TreeChildItem, Mark, False);
	EndDo;
	// Checking if parent item state should be changed.
	If CheckBranchMarked Then
		CheckBranchMarked(TreeItem.GetParent());
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Procedure CheckBranchMarked(Branch)
	If Branch = Undefined Then 
		Return;
	EndIf;
	ChildBranches = Branch.GetItems();
	
	HasTrue = False;
	HasFalse = False;
	For Each ChildBranch In ChildBranches Do
		If ChildBranch.Check Then
			HasTrue = True;
			If HasFalse Then
				Break;
			EndIf;
		Else
			HasFalse = True;
			If HasTrue Then
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If HasTrue Then
		If HasFalse Then
			// There are branches with both selected and cleared marks. If necessary, clearing the mark of the current item and then checking the parent.
			If Branch.Check Then
				Branch.Check = False;
				CheckBranchMarked(Branch.GetParent());
			EndIf;
		Else
			// All child branch marks are selected.
			If Not Branch.Check Then
				Branch.Check = True;
				CheckBranchMarked(Branch.GetParent());
			EndIf;
		EndIf;
	Else
		// All child branch marks are cleared.
		If Branch.Check Then
			Branch.Check = False;
			CheckBranchMarked(Branch.GetParent());
		EndIf;
	EndIf;
EndProcedure

&AtServer
Procedure SetMarks(Value, TreeBranch = Undefined)
	
	If TreeBranch = Undefined Then
		TreeBranch = List;
	EndIf;
	
	For Each ListLine In TreeBranch.GetItems() Do
		ListLine.Check = Value;
		SetMarks(Value, ListLine);
	EndDo;
	
EndProcedure

&AtServer
Procedure OrderTreeItems()
	
	ListTree = FormAttributeToValue("List");
	ListTree.Rows.Sort("Presentation Asc", True);
	ValueToFormAttribute(ListTree, "List");
	
EndProcedure

&AtServer
Function UnspecifiedUserFullName()
	
	Return NStr("ru = '<Не указано>'; en = '<Not specified>'; pl = '<Nieokreślono>';es_ES = '<No especificado>';es_CO = '<No especificado>';tr = '<Belirtilmedi>';it = '<Non specificato>';de = '<Nicht eingegeben>'");
	
EndFunction

&AtServerNoContext
Function InternalUserFullName(IBUserID)
	
	If Not Common.DataSeparationEnabled() Then
		Return "";
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		Return ModuleSaaS.InfobaseUserAlias(IBUserID);
	EndIf;
	
	Return "";
	
EndFunction

#EndRegion
