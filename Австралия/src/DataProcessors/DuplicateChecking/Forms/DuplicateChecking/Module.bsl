
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ObjectRef = Parameters.Ref;
	DuplicatesTableStructure = Parameters.DuplicatesTableStructure;
	
	If ValueIsFilled(DuplicatesTableStructure.DuplicateRulesIndexTableAddress) Then
		VT = GetFromTempStorage(DuplicatesTableStructure.DuplicateRulesIndexTableAddress);
		DuplicatesTable.Load(VT);
		DeleteFromTempStorage(DuplicatesTableStructure.DuplicateRulesIndexTableAddress);
	EndIf;
	
	If ValueIsFilled(DuplicatesTableStructure.DuplicatesTableAddress) Then
		VT = GetFromTempStorage(DuplicatesTableStructure.DuplicatesTableAddress);
		For Each VTLine In VT Do
			
			NewDuplicateLine = DuplicatesTable.Add();
			FillPropertyValues(NewDuplicateLine, VTLine);
			
			If DuplicatesList.FindByValue(VTLine.ObjectRef) = Undefined Then
				LinkedDataCount = Format(LinkedDataCount(VTLine.ObjectRef), "NZ=""0""");
				NewListValue = DuplicatesList.Add(VTLine.ObjectRef,
					String(VTLine.ObjectType) + ": " + VTLine.ObjectRef + " (" + LinkedDataCount + ")");
			EndIf;
				
		EndDo;
		DeleteFromTempStorage(DuplicatesTableStructure.DuplicatesTableAddress);
	EndIf;
	
	If DuplicatesList.Count() = 0 Then
		Cancel = True;
	EndIf;
	
	Items.NewObjectData.RowFilter = New FixedStructure("ObjectRef", ObjectRef);
	Items.GroupExistingObjectData.Title = DuplicateObjectRef;
	Items.ExistingObjectData.RowFilter = New FixedStructure("ObjectRef", DuplicateObjectRef);
	
	SetConditionalAppearance();
	
EndProcedure

#EndRegion

#Region DuplicatesListFormTableItemsEventHandlers

&AtClient
Procedure DuplicatesListOnActivateRow(Item)
	
	DuplicateObjectRef = Item.CurrentData.Value;
	Items.GroupExistingObjectData.Title = DuplicateObjectRef;
	Items.ExistingObjectData.RowFilter = New FixedStructure("ObjectRef", DuplicateObjectRef);

EndProcedure

&AtClient
Procedure DuplicatesListBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure DuplicatesListBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;
EndProcedure

&AtClient
Procedure DuplicatesListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ShowValue(, Item.CurrentData.Value);
	
EndProcedure

#EndRegion

#Region KanbanFormTableItemsEventHandlers

&AtClient
Procedure KanbanSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	ShowValue( , Item.CurrentData.ObjectRef);
EndProcedure

&AtClient
Procedure KanbanBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;
EndProcedure

&AtClient
Procedure KanbanDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	If DragParameters.Value.Count() > 0
		AND TypeOf(DragParameters.Value[0]) <> Type("Number") Then
		
		For Each DragLine In DragParameters.Value Do
			If DragLine.ObjectRef = ObjectRef Then
				DragLine.ObjectRef = DuplicateObjectRef;
			ElsIf DragLine.NewObjectData Then
				DragLine.ObjectRef = ObjectRef;
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ShowLinkedData(Command)
	
	LinkedDataAddress = LinkedDataAtServer();
	
	SelectionParameters = New Structure;
	SelectionParameters.Insert("LinkedDataAddress", LinkedDataAddress);
	
	OpenForm("DataProcessor.DuplicateChecking.Form.LinkedData",
		SelectionParameters,
		ThisObject,
		True,
		,
		,
		,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure AutoMerge(Command)
	
	AutoMergeAtServer();
	
EndProcedure

&AtClient
Procedure DoNothing(Command)
	
	ThisObject.Close();
	
EndProcedure

&AtClient
Procedure Merge(Command)
	
	ThisObject.Close(StructureToReturn("Delete", "Change"));
	
EndProcedure

&AtClient
Procedure CreateAnyway(Command)
	
	ThisObject.Close(StructureToReturn("Create"));
	
EndProcedure

&AtClient
Procedure CreateNew(Command)
	
	ThisObject.Close(StructureToReturn("Create", "Delete"));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	DeleteItems = New Array;
	
	For Each ConditionalAppearanceItem In ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "DuplicateItem" Then
			DeleteItems.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	
	For Each DeleteItem In DeleteItems Do
		ConditionalAppearance.Items.Delete(DeleteItem);
	EndDo;
	
	// Nikola red
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("BackColor", StyleColors.DuplicateDataColor);
	ConditionalAppearanceItem.UserSettingID = "DuplicateItem";
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess;
	
	FormattedFields = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedFields.Field = New DataCompositionField("NewObjectDataObjectCriteria");
	FormattedFields = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedFields.Field = New DataCompositionField("NewObjectDataType");
	FormattedFields = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedFields.Field = New DataCompositionField("NewObjectDataPresentation");
	FormattedFields = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedFields.Field = New DataCompositionField("ExistingObjectDataObjectCriteria");
	FormattedFields = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedFields.Field = New DataCompositionField("ExistingObjectDataType");
	FormattedFields = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedFields.Field = New DataCompositionField("ExistingObjectDataPresentation");
	
	FilterIsDuplicate = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterIsDuplicate.LeftValue = New DataCompositionField("DuplicatesTable.IsDuplicate");
	FilterIsDuplicate.ComparisonType = DataCompositionComparisonType.Equal;
	FilterIsDuplicate.RightValue = True;
	
	// Bold font
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(, , True));
	ConditionalAppearanceItem.UserSettingID = "DuplicateItem";
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess;
	
	FormattedFields = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedFields.Field = New DataCompositionField("NewObjectData");
	FormattedFields = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedFields.Field = New DataCompositionField("ExistingObjectData");
	
	FilterIsDuplicate = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterIsDuplicate.LeftValue = New DataCompositionField("DuplicatesTable.NewObjectData");
	FilterIsDuplicate.ComparisonType = DataCompositionComparisonType.Equal;
	FilterIsDuplicate.RightValue = True;

	
EndProcedure

&AtServer
Function LinkedDataAtServer()
	
	SetPrivilegedMode(True);
	
	SearchRefs = New Array;
	SearchRefs.Add(DuplicateObjectRef);
	
	ExcludeObjects = New Array;
	ExcludeObjects.Add(DuplicateObjectRef.Metadata());
	
	LinkedData = FindByRef(SearchRefs, , , ExcludeObjects);
	
	SetPrivilegedMode(False);
	
	Return PutToTempStorage(LinkedData);
	
EndFunction

&AtServerNoContext
Function LinkedDataCount(Ref)
	
	SetPrivilegedMode(True);
	
	SearchRefs = New Array;
	SearchRefs.Add(Ref);
	
	ExcludeObjects = New Array;
	ExcludeObjects.Add(Ref.Metadata());
	
	LinkedData = FindByRef(SearchRefs, , , ExcludeObjects);
	
	SetPrivilegedMode(False);
	
	Index = 0;
	
	For Each DataRow In LinkedData Do
		
		If Metadata.Catalogs.Contains(DataRow.Metadata)
			OR Metadata.Documents.Contains(DataRow.Metadata) Then
			
			Index = Index + 1;
			
		EndIf;
		
	EndDo;
	
	Return Index;
	
EndFunction

&AtServer
Function AutoMergeAtServer()
	
	For Each DuplicateLine In DuplicatesTable Do
		
		If DuplicateLine.NewObjectData And (DuplicateLine.ObjectRef = ObjectRef) Then
			
			If DuplicateLine.ObjectCriteria = Enums.DuplicateObjectsCriterias.ContactInformation Then
				
				If Not DuplicateLine.IsDuplicate Then
					
					DuplicateLine.ObjectRef = DuplicateObjectRef;
					
				EndIf;
				
			Else
				
				AttributeName = XMLString(DuplicateLine.ObjectCriteria);
				Try
					AtrValue = DuplicateObjectRef[AttributeName];
				Except
					Continue;
				EndTry;
				
				If Not ValueIsFilled(AtrValue) Then
					DuplicateLine.ObjectRef = DuplicateObjectRef;
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndFunction

&AtServer
Function StructureToReturn(ActionWithNewObject, ActionWithExistingObject = "")
	
	StructureToReturn = New Structure();
	StructureToReturn.Insert("ActionWithNewObject", ActionWithNewObject);
	StructureToReturn.Insert("ActionWithExistingObject", ActionWithExistingObject);
	
	Filter = New Structure("NewObjectData", True);
	StructureToReturn.Insert("DuplicateRulesIndexTableAddress", PutToTempStorage(DuplicatesTable.Unload(Filter)));
	
	If ActionWithExistingObject = "Delete" Then
		
		ModificationTable = ModificationTableColumns();
		For Each Duplicate In DuplicatesList Do
			NewLine = ModificationTable.Add();
			NewLine.Object = Duplicate.Value;
			NewLine.Delete = True;
		EndDo;
		StructureToReturn.Insert("ModificationTableAddress", PutToTempStorage(ModificationTable));
		
	ElsIf ActionWithExistingObject = "Change" Then
		
		ModificationTable = ModificationTableColumns();
		For Each Duplicate In DuplicatesList Do
			ChangedAttributes = ChangedAttributesTable(Duplicate.Value);
			If ChangedAttributes.Count() Then
				NewLine = ModificationTable.Add();
				NewLine.Object = Duplicate.Value;
				NewLine.Delete = False;
				NewLine.ChangedAttributes = ChangedAttributes;
			EndIf;
		EndDo;
		StructureToReturn.Insert("ModificationTableAddress", PutToTempStorage(ModificationTable));
		
	EndIf;
		
	Return StructureToReturn;
	
EndFunction

&AtServerNoContext
Function ModificationTableColumns()
	
	ValueTable = New ValueTable;
	
	ValueTable.Columns.Add("Object");
	ValueTable.Columns.Add("Delete");
	ValueTable.Columns.Add("ChangedAttributes");
	
	Return ValueTable;
	
EndFunction

&AtServer
Function ChangedAttributesTable(Ref)
	
	Filter = New Structure();
	Filter.Insert("NewObjectData",	True);
	Filter.Insert("IsDuplicate",	False);
	Filter.Insert("ObjectRef",		Ref);
	
	ChangedAttributesTable = DuplicatesTable.Unload(Filter, "ObjectCriteria, Type, Kind, Presentation");
	
	Return ChangedAttributesTable;
	
EndFunction

#EndRegion
