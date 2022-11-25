#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	StatesContainer = New Structure;
	StatesContainer.Insert("SearchAreas", New ValueList); // Metadata objects IDs.
	StatesContainer.Insert("CurrentSection", "");
	StatesContainer.Insert("RowID", 0);
	
	Parameters.Property("SearchAreas", StatesContainer.SearchAreas);
	Parameters.Property("SearchInSections", RadioButtonsEverywhereInSections); // Convert from Boolean to Number.
	
	LoadCurrentSectionPath(StatesContainer);
	
	OnFillSearchSectionsTree(StatesContainer);
	
	SearchInSections = SearchInSections(RadioButtonsEverywhereInSections);
	UpdateAvailabilityOnSwitchEverywhereInSections(Items.SearchSectionsTree, SearchInSections);
	UpdateAvailabilityOnSwitchEverywhereInSections(Items.Commands, SearchInSections);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ExpandCurrentSectionsTreeSection(Items.SearchSectionsTree, StatesContainer)
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SearchAreaOnChange(Item)
	
	SearchInSections = SearchInSections(RadioButtonsEverywhereInSections);
	UpdateAvailabilityOnSwitchEverywhereInSections(Items.SearchSectionsTree, SearchInSections);
	UpdateAvailabilityOnSwitchEverywhereInSections(Items.Commands, SearchInSections);
	
EndProcedure

#EndRegion

#Region SearchSectionsTreeFormTableItemsEventHandlers

&AtClient
Procedure SearchSectionsTreeMarkOnChange(Item)
	
	TreeItem = CurrentItem.CurrentData;
	
	OnMarkTreeItem(TreeItem);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OkCommand(Command)
	
	CurrentData = Items.SearchSectionsTree.CurrentData;
	
	CurrentSection = "";
	If CurrentData <> Undefined Then
		CurrentSection = CurrentData.Section;
	EndIf;
	RowID = Items.SearchSectionsTree.CurrentRow;
	
	SaveCurrentSectionPath(CurrentSection, RowID);
	
	SearchSettings = New Structure;
	SearchSettings.Insert("SearchAreas", SectionsTreeAreasList());
	SearchSettings.Insert("SearchInSections", SearchInSections(RadioButtonsEverywhereInSections));
	
	Close(SearchSettings);
	
EndProcedure

&AtClient
Procedure ClearAll(Command)
	
	MarkAllTreeItemsRecursively(SearchSectionsTree, MarkCheckBoxIsNotSelected());
	
EndProcedure

&AtClient
Procedure SelectAll(Command)
	
	MarkAllTreeItemsRecursively(SearchSectionsTree, MarkCheckBoxIsSelected());
	
EndProcedure

&AtClient
Procedure CollapseAll(Command)
	
	TreeItemsCollection = SearchSectionsTree.GetItems();
	SectionsTreeItem = Items.SearchSectionsTree;
	
	For each TreeItem In TreeItemsCollection Do
		SectionsTreeItem.Collapse(TreeItem.GetID());
	EndDo;
	
EndProcedure

&AtClient
Procedure ExpandAll(Command)
	
	TreeItemsCollection = SearchSectionsTree.GetItems();
	SectionsTreeItem = Items.SearchSectionsTree;
	
	For each TreeItem In TreeItemsCollection Do
		SectionsTreeItem.Expand(TreeItem.GetID(), True);
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

#Region PrivateEventHandlers

&AtServer
Procedure OnFillSearchSectionsTree(StatesContainer)
	
	Tree = FormAttributeToValue("SearchSectionsTree");
	FillSearchSectionsTree(Tree);
	ValueToFormAttribute(Tree, "SearchSectionsTree");
	
	OnSetSearchArea(SearchSectionsTree, StatesContainer);
	
EndProcedure

&AtServerNoContext
Procedure OnSetSearchArea(SearchSectionsTree, StatesContainer)
	
	SearchAreas = StatesContainer.SearchAreas;
	
	For each SearchArea In SearchAreas Do
		
		TreeItem = Undefined;
		CurrentSection = Undefined;
		NestedItems = SearchSectionsTree.GetItems();
		
		// Search for a tree item by a path to the data.
		
		DataPath = SearchArea.Presentation;
		Sections = StrSplit(DataPath, ",", False);
		For each CurrentSection In Sections Do
			For each TreeItem In NestedItems Do
				
				If TreeItem.Section = CurrentSection Then
					NestedItems = TreeItem.GetItems();
					Break;
				EndIf;
				
			EndDo;
		EndDo;
		
		// If the tree item is found, the check mark is set.
		
		If TreeItem <> Undefined
			AND TreeItem.Section = CurrentSection Then
			
			TreeItem.Check = MarkCheckBoxIsSelected();
			MarkParentsItemsRecursively(TreeItem);
		EndIf;
		
	EndDo;
	
EndProcedure

// Parameters:
//  TreeItem - FormDataTreeItem.
//      * CheckMark             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Procedure OnMarkTreeItem(TreeItem)
	
	TreeItem.Check = NextItemCheckMarkValue(TreeItem);
	
	If RequiredToMarkNestedItems(TreeItem) Then 
		MarkNestedItemsRecursively(TreeItem);
	EndIf;
	
	If TreeItem.Check = MarkCheckBoxIsNotSelected() Then 
		TreeItem.Check = CheckMarkValueRelativeToNestedItems(TreeItem);
	EndIf;
	
	MarkParentsItemsRecursively(TreeItem);
	
EndProcedure

#EndRegion

#Region PresentationModel

&AtClientAtServerNoContext
Function MarkCheckBoxIsNotSelected()
	
	Return 0;
	
EndFunction

&AtClientAtServerNoContext
Function MarkCheckBoxIsSelected()
	
	Return 1;
	
EndFunction

&AtClientAtServerNoContext
Function MarkSquare()
	
	Return 2;
	
EndFunction

&AtServerNoContext
Procedure FillSearchSectionsTree(SearchSectionsTree)
	
	AddSearchSectionsTreeRowsBySubsystemsRecursively(SearchSectionsTree, Metadata.Subsystems);
	
	FullTextSearchServerOverridable.OnGetFullTextSearchSections(SearchSectionsTree);
	
	FillServicePropertiesAfterGetSectionsRecursively(SearchSectionsTree);
	
EndProcedure

&AtServerNoContext
Procedure AddSearchSectionsTreeRowsBySubsystemsRecursively(CurrentTreeRow, Subsystems)
	
	For each Subsystem In Subsystems Do
		
		If MetadataObjectAvailable(Subsystem) Then
			
			NewRowSubsystem = NewTreeItemSection(CurrentTreeRow, Subsystem);
			
			AddSearchSectionsTreeRowsByContentRecursively(NewRowSubsystem, Subsystem.Content);
			
			If Subsystem.Subsystems.Count() > 0 Then
				AddSearchSectionsTreeRowsBySubsystemsRecursively(NewRowSubsystem, Subsystem.Subsystems);
			EndIf;
			
			If NewRowSubsystem.Rows.Count() = 0 Then
				CurrentTreeRow.Rows.Delete(NewRowSubsystem);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure AddSearchSectionsTreeRowsByContentRecursively(CurrentTreeRow, SubsystemComposition)
	
	For each SubsystemObject In SubsystemComposition Do
		
		If Common.IsCatalog(SubsystemObject)
			Or Common.IsDocument(SubsystemObject)
			Or Common.IsInformationRegister(SubsystemObject)
			Or Common.IsTask(SubsystemObject) Then
			
			If MetadataObjectAvailable(SubsystemObject) Then
				
				NewRowObject = NewTreeItemMetadataObject(CurrentTreeRow, SubsystemObject);
				
				If Common.IsCatalog(SubsystemObject) Then 
					SubordinateCatalogs = SubordinateCatalogs(SubsystemObject);
					AddSearchSectionsTreeRowsByContentRecursively(NewRowObject, SubordinateCatalogs);
				EndIf;
				
			EndIf;
			
		ElsIf Common.IsDocumentJournal(SubsystemObject) Then
			
			If MetadataObjectAvailable(SubsystemObject) Then
				
				NewRowLog = NewTreeItemSection(CurrentTreeRow, SubsystemObject);
				
				AddSearchSectionsTreeRowsByContentRecursively(NewRowLog, SubsystemObject.RegisteredDocuments);
				
				If NewRowLog.Rows.Count() = 0 Then
					CurrentTreeRow.Rows.Delete(NewRowLog);
				EndIf;
				
			EndIf;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function NewTreeItemSection(CurrentTreeRow, Section)
	
	SectionPresentation = Section;
	If Common.IsDocumentJournal(Section) Then
		SectionPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1 (Журнал)'; en = '%1 (Log)'; pl = '%1 (Dziennik)';es_ES = '%1 (Registro)';es_CO = '%1 (Registro)';tr = '%1 (Günlük)';it = '%1 (Registro)';de = '%1 (Protokoll)'"), SectionPresentation);
	EndIf;
	
	NewRow = CurrentTreeRow.Rows.Add();
	NewRow.Section = SectionPresentation;
	
	If IsRootSubsystem(Section) Then 
		NewRow.Picture = Section.Picture;
	EndIf;
	
	Return NewRow;
	
EndFunction

&AtServerNoContext
Function NewTreeItemMetadataObject(CurrentTreeRow, MetadataObject)
	
	ObjectPresentation = ListFormPresentation(MetadataObject);
	
	NewRow = CurrentTreeRow.Rows.Add();
	NewRow.Section = ObjectPresentation;
	NewRow.MetadateObject = Common.MetadataObjectID(MetadataObject);
	
	Return NewRow;
	
EndFunction

&AtServerNoContext
Procedure FillServicePropertiesAfterGetSectionsRecursively(CurrentTreeRow)
	
	If TypeOf(CurrentTreeRow) = Type("ValueTreeRow") Then 
		
		// DataPath, IsSubsection, and IsMetadataObject are filled after the tree is generated in order to 
		// place these flags correctly for sections added in the event
		// FullTextSearchServerOverridable.OnGetFullTextSearchSections and free configuration developers 
		// from having to think about these fields.
		
		IsMetadataObject = ValueIsFilled(CurrentTreeRow.MetadateObject);
		
		CurrentTreeRow.IsMetadataObject = IsMetadataObject;
		
		If CurrentTreeRow.Level() = 0 Then 
			CurrentTreeRow.DataPath = CurrentTreeRow.Section;
		Else 
			CurrentTreeRow.IsSubsection = Not IsMetadataObject;
			CurrentTreeRow.DataPath = CurrentTreeRow.Parent.DataPath + "," + CurrentTreeRow.Section;
		EndIf;
		
	EndIf;
	
	For each SubordinateRow In CurrentTreeRow.Rows Do 
		FillServicePropertiesAfterGetSectionsRecursively(SubordinateRow);
		SubordinateRow.Rows.Sort("IsSubsection, Section");
	EndDo;
	
EndProcedure

&AtServer
Function SectionsTreeAreasList()
	
	Tree = FormAttributeToValue("SearchSectionsTree");
	
	AreasList = New ValueList;
	FillAreasListRecursively(AreasList, Tree.Rows);
	
	Return AreasList;
	
EndFunction

&AtServerNoContext
Procedure FillAreasListRecursively(AreasList, SectionsTreeRows)
	
	For each RowSection In SectionsTreeRows Do
		
		If RowSection.Check = MarkCheckBoxIsSelected() Then
			
			If RowSection.IsMetadataObject Then
				AreasList.Add(RowSection.MetadateObject, RowSection.DataPath);
			EndIf;
			
		EndIf;
		
		FillAreasListRecursively(AreasList, RowSection.Rows);
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function SearchInSections(RadioButtonsEverywhereInSections)
	
	Return (RadioButtonsEverywhereInSections = 1);
	
EndFunction

#EndRegion

#Region Presentations

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Section.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue  = New DataCompositionField("SearchSectionsTree.IsSubsection");
	ItemFilter.ComparisonType   = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	If ClientApplication.CurrentInterfaceVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Item.Appearance.SetParameterValue("Font", New Font(,, True)); // Bold.
	Else 
		Item.Appearance.SetParameterValue("TextColor", StyleColors.FunctionsPanelSectionColor);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ListFormPresentation(MetadataObject)
	
	If Not IsBlankString(MetadataObject.ExtendedListPresentation) Then
		Presentation = MetadataObject.ExtendedListPresentation;
	ElsIf Not IsBlankString(MetadataObject.ListPresentation) Then
		Presentation = MetadataObject.ListPresentation;
	Else 
		Presentation = MetadataObject.Presentation();
	EndIf;
	
	Return Presentation;
	
EndFunction

#EndRegion

#Region InteractivePresentationLogic

&AtClientAtServerNoContext
Procedure UpdateAvailabilityOnSwitchEverywhereInSections(Item, SearchInSections)
	
	Item.Enabled = SearchInSections;
	
EndProcedure

&AtClient
Procedure ExpandCurrentSectionsTreeSection(Item, StatesContainer)
	
	CurrentSection       = StatesContainer.CurrentSection;
	RowID = StatesContainer.RowID;
	
	// Go to the section, with which you worked at previous settings.
	If Not IsBlankString(CurrentSection) AND RowID <> 0 Then
		
		SearchSection = SearchSectionsTree.FindByID(RowID);
		If SearchSection = Undefined 
			Or SearchSection.Section <> CurrentSection Then
			Return;
		EndIf;
		
		SectionParent = SearchSection.GetParent();
		While SectionParent <> Undefined Do
			Items.SearchSectionsTree.Expand(SectionParent.GetID());
			SectionParent = SectionParent.GetParent();
		EndDo;
		
		Items.SearchSectionsTree.CurrentRow = RowID;
		
	EndIf;
	
EndProcedure

// Parameters:
//  TreeItem - FormDataTreeItem.
//      * CheckMark             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Function NextItemCheckMarkValue(TreeItem)
	
	// 0 - Check box is not selected.
	// 1 - Check box is selected.
	// 2 - Square is selected.
	//
	// Override the state machine graph.
	//
	// The platform performs a permanent cycle upon check mark change, which means it has a strongly 
	// connected digraph component:
	// 0-1-2-0-1-2-0-1...
	//
	//    0
	//   / \
	//  2 - 1
	//
	// So it performs a cycle: not selected - selected - square - not selected.
	//
	// We need behavior of a non-deterministic state machine with a strongly connected component:
	// 0-1-0-1-0...
	//
	// It means, the selected one must go to the not selected one, and the latter one must go to the selected one again.
	//
	// In such a case:
	//
	// Cycles for sections are as follows:
	// 1) 1-0-1-0-1...
	// 2) 2-0-1-0-1-0-...
	//
	//      /\
	// 2 - 0 -1 It means that the square must go to the not selected check box.
	//
	// 
	//
	// Cycles for metadata are as follows:
	// 1) 1-0-1-0-1-0...
	// 2) 2-1-0-1-0-1-0...
	//
	//      /\
	// 2 - 0 -1 It means that the square must go to the selected check box.
	//
	// 
	
	// At the time of checking, the platform has already changed the check box value.
	
	If TreeItem.IsMetadataObject Then
		// Previous check box value = 2: Square is selected.
		If TreeItem.Check = 0 Then
			Return MarkCheckBoxIsSelected();
		EndIf;
	EndIf;
	
	// Previous check box value = 1: Check box is selected.
	If TreeItem.Check = 2 Then 
		Return MarkCheckBoxIsNotSelected();
	EndIf;
	
	// In all other cases, the platform sets a value.
	Return TreeItem.Check;
	
EndFunction

// Parameters:
//  TreeItem - FormDataTreeItem.
//      * CheckMark             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Procedure MarkParentsItemsRecursively(TreeItem)
	
	Parent = TreeItem.GetParent();
	
	If Parent = Undefined Then
		Return;
	EndIf;
	
	ParentItems = Parent.GetItems();
	If ParentItems.Count() = 0 Then
		Parent.Check = MarkCheckBoxIsSelected();
	ElsIf TreeItem.Check = MarkSquare() Then
		Parent.Check = MarkSquare();
	Else
		Parent.Check = CheckMarkValueRelativeToNestedItems(Parent);
	EndIf;
	
	MarkParentsItemsRecursively(Parent);
	
EndProcedure

// Parameters:
//  TreeItem - FormDataTreeItem.
//      * CheckMark             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Function CheckMarkValueRelativeToNestedItems(TreeItem)
	
	NestedItemsState = NestedItemsState(TreeItem);
	
	HasMarkedItems   = NestedItemsState.HasMarkedItems;
	HasUnmarkedItems = NestedItemsState.HasUnmarkedItems;
	
	If TreeItem.IsMetadataObject Then 
		
		// For a metadata object, it is important, which state it has at the moment, as this metadata object 
		// is to be returned.
		// Cannot reset the selected check box.
		
		If TreeItem.Check = MarkCheckBoxIsSelected() Then 
			// Leave the check box selected, regardless of nested items.
			Return MarkCheckBoxIsSelected();
		EndIf;
		
		If TreeItem.Check = MarkCheckBoxIsNotSelected()
			Or TreeItem.Check = MarkSquare() Then 
			
			If HasMarkedItems Then
				Return MarkSquare();
			Else 
				Return MarkCheckBoxIsNotSelected();
			EndIf;
		EndIf;
		
	Else 
		
		// For sections, it is not important, which state they have at the moment, they always depend only 
		// on nested items.
		
		If HasMarkedItems Then
			
			If HasUnmarkedItems Then
				Return MarkSquare();
			Else
				Return MarkCheckBoxIsSelected();
			EndIf;
			
		EndIf;
		
		Return MarkCheckBoxIsNotSelected();
		
	EndIf;
	
EndFunction

// Parameters:
//  TreeItem - FormDataTreeItem.
//      * CheckMark             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Function NestedItemsState(TreeItem)
	
	NestedItems = TreeItem.GetItems();
	
	HasMarkedItems   = False;
	HasUnmarkedItems = False;
	
	For each NestedItem In NestedItems Do
		
		If NestedItem.Check = MarkCheckBoxIsNotSelected() Then 
			HasUnmarkedItems = True;
			Continue;
		EndIf;
		
		If NestedItem.Check = MarkCheckBoxIsSelected() Then 
			HasMarkedItems = True;
			
			If NestedItem.IsMetadataObject Then 
				
				// A metadata object can have not marked nested items but be marked itself.
				//  To resolve this situation, raise the nested items to the level of the object they belong to.
				// 
				
				State = NestedItemsState(NestedItem);
				HasMarkedItems   = HasMarkedItems   Or State.HasMarkedItems;
				HasUnmarkedItems = HasUnmarkedItems Or State.HasUnmarkedItems;
			EndIf;
			
			Continue;
		EndIf;
		
		If NestedItem.Check = MarkSquare() Then 
			HasMarkedItems   = True;
			HasUnmarkedItems = True;
			Continue;
		EndIf;
		
	EndDo;
	
	Result = New Structure;
	Result.Insert("HasMarkedItems",   HasMarkedItems);
	Result.Insert("HasUnmarkedItems", HasUnmarkedItems);
	
	Return Result;
	
EndFunction

// Parameters:
//  TreeItem - FormDataTreeItem.
//      * CheckMark             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Function RequiredToMarkNestedItems(TreeItem)
	
	If TreeItem.IsMetadataObject Then 
		
		// If a metadata object contains incompletely selected nested items, it means that these items were 
		// selected by the user, do not spoil this choice.
		
		NestedItemsState = NestedItemsState(TreeItem);
		
		HasMarkedItems   = NestedItemsState.HasMarkedItems;
		HasUnmarkedItems = NestedItemsState.HasUnmarkedItems;
		
		If HasMarkedItems AND HasUnmarkedItems Then 
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

// Parameters:
//  TreeItem - FormDataTreeItem.
//      * CheckMark             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Procedure MarkNestedItemsRecursively(TreeItem)
	
	NestedItems = TreeItem.GetItems();
	
	For each NestedItem In NestedItems Do
		
		NestedItem.Check = TreeItem.Check;
		MarkNestedItemsRecursively(NestedItem);
		
	EndDo;
	
EndProcedure

// Parameters:
//  TreeItemsCollection - TreeFormData, FormDataTreeItem.
//      * CheckMark             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//  MarkValue - Number - a value being set.
//
&AtClientAtServerNoContext
Procedure MarkAllTreeItemsRecursively(ItemSearchSectionsTree, MarkValue)
	
	TreeItemsCollection = ItemSearchSectionsTree.GetItems();
	
	For each TreeItem In TreeItemsCollection Do
		TreeItem.Check = MarkValue;
		MarkAllTreeItemsRecursively(TreeItem, MarkValue);
	EndDo;
	
EndProcedure

#EndRegion

#Region BusinessLogic

&AtServerNoContext
Function IsRootSubsystem(MetadataObject)
	
	Return Metadata.Subsystems.Contains(MetadataObject);
	
EndFunction

&AtServerNoContext
Function MetadataObjectAvailable(MetadataObject)
	
	AvailableByRights = AccessRight("View", MetadataObject);
	AvailableByFunctionalOptions = Common.MetadataObjectAvailableByFunctionalOptions(MetadataObject);
	
	MetadataProperties = New Structure("FullTextSearch, IncludeInCommandInterface");
	FillPropertyValues(MetadataProperties, MetadataObject);
	
	If MetadataProperties.FullTextSearch = Undefined Then 
		FullTextSearchUsing = True; // Ignore if there are no properties.
	Else 
		FullTextSearchUsing = (MetadataProperties.FullTextSearch = 
			Metadata.ObjectProperties.FullTextSearchUsing.Use);
	EndIf;
	
	If MetadataProperties.IncludeInCommandInterface = Undefined Then 
		IncludeInCommandInterface = True; // Ignore if there are no properties.
	Else 
		IncludeInCommandInterface = MetadataProperties.IncludeInCommandInterface;
	EndIf;
	
	Return AvailableByRights AND AvailableByFunctionalOptions 
		AND FullTextSearchUsing AND IncludeInCommandInterface;
	
EndFunction

&AtServerNoContext
Function SubordinateCatalogs(MetadataObject)
	
	Result = New Array;
	
	For Each Catalog In Metadata.Catalogs Do
		If Catalog.Owners.Contains(MetadataObject)
			AND MetadataObjectAvailable(Catalog) Then 
			
			Result.Add(Catalog);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Procedure SaveCurrentSectionPath(CurrentSection, RowID)
	
	CurrentSectionParameters = New Structure;
	CurrentSectionParameters.Insert("CurrentSection",       CurrentSection);
	CurrentSectionParameters.Insert("RowID", RowID);
	Common.CommonSettingsStorageSave("FullTextSearchCurrentSection", "", CurrentSectionParameters);
	
EndProcedure

&AtServerNoContext
Procedure LoadCurrentSectionPath(CurrentSectionParameters)
	
	SavedSearchSettings = Common.CommonSettingsStorageLoad("FullTextSearchCurrentSection", "");
	
	CurrentSection       = Undefined;
	RowID = Undefined;
	
	If TypeOf(SavedSearchSettings) = Type("Structure") Then
		SavedSearchSettings.Property("CurrentSection",       CurrentSection);
		SavedSearchSettings.Property("RowID", RowID);
	EndIf;
	
	CurrentSectionParameters.CurrentSection       = ?(CurrentSection = Undefined, "", CurrentSection);
	CurrentSectionParameters.RowID = ?(RowID = Undefined, 0, RowID);
	
EndProcedure

#EndRegion

#EndRegion