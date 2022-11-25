
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	AttributeTree = FormAttributeToValue("ObjectAttributes");
	ObjectAttributeCollection = AttributeTree.Rows;
	
	SelectedAllAttributes = Parameters.Filter.Count() = 0 Or Parameters.Filter[0] = "*";
	MetadataObject = Parameters.Ref.Metadata();
	For Each AttributeDetails In MetadataObject.Attributes Do
		Attribute = ObjectAttributeCollection.Add();
		FillPropertyValues(Attribute, AttributeDetails);
		Attribute.Check = SelectedAllAttributes Or Parameters.Filter.Find(AttributeDetails.Name) <> Undefined;
		Attribute.Synonym = AttributeDetails.Presentation();
	EndDo;
	
	ObjectAttributeCollection.Sort("Synonym");
	
	For Each TabularSectionDetails In MetadataObject.TabularSections Do
		TabularSection = ObjectAttributeCollection.Add();
		FillPropertyValues(TabularSection, TabularSectionDetails);
		SelectedAllTabularSection = SelectedAllAttributes Or Parameters.Filter.Find(TabularSectionDetails.Name + ".*") <> Undefined;
		HasSelectedItems = SelectedAllTabularSection;
		For Each AttributeDetails In TabularSectionDetails.Attributes Do
			Attribute = TabularSection.Rows.Add();
			FillPropertyValues(Attribute, AttributeDetails);
			Attribute.Synonym = AttributeDetails.Presentation();
			Attribute.Check = SelectedAllAttributes Or SelectedAllTabularSection Or Parameters.Filter.Find(TabularSectionDetails.Name + "." + AttributeDetails.Name) <> Undefined;
			HasSelectedItems = HasSelectedItems Or Attribute.Check;
		EndDo;
		TabularSection.Check = HasSelectedItems + ?(HasSelectedItems, (Not SelectedAllTabularSection), HasSelectedItems);
		TabularSection.Rows.Sort("Synonym");
	EndDo;
	
	ValueToFormAttribute(AttributeTree, "ObjectAttributes");
	
	ObjectsVersioningOverridable.OnSelectObjectAttributes(Parameters.Ref, ObjectAttributes);
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		Items.Move(Items.ObjectAttributesSelect, Items.CommandBarForm);
		Items.Move(Items.FormSelectAll, Items.CommandBarForm);
		Items.Move(Items.FormClearAll, Items.CommandBarForm);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region TableFormAttributeObjectEventHandlers

&AtClient
Procedure ObjectAttributesCheckOnChange(Item)
	
	OnChangeCheckBox(Items.ObjectAttributes, "Check");
	SetSelectionButtonAvailability();

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SelectAll(Command)
	SelectOrClearAll(True);
EndProcedure

&AtClient
Procedure ClearAll(Command)
	SelectOrClearAll(False);
EndProcedure

&AtClient
Procedure Select(Command)
	Result = New Structure;
	Result.Insert("SelectedAttributes", SelectedAttributes(ObjectAttributes.GetItems()));
	Result.Insert("SelectedItemsPresentation", SelectedAttributePresentation());

	Close(Result);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SelectOrClearAll(Mark)
	For Each Attribute In ObjectAttributes.GetItems() Do 
		Attribute.Check = Mark;
		For Each SubordinateAttribute In Attribute.GetItems() Do
			SubordinateAttribute.Check = Mark;
		EndDo;
	EndDo;
	SetSelectionButtonAvailability();
EndProcedure

&AtClient
Function SelectedAttributes(AttributesCollection)
	Result = New Array;
	SelectedAllAttributes = True;
	
	For Each Attribute In AttributesCollection Do
		SubordinateAttributes = Attribute.GetItems();
		If SubordinateAttributes.Count() > 0 Then
			SelectedItemsList = SelectedAttributes(SubordinateAttributes);
			SelectedAllAttributes = SelectedAllAttributes AND SelectedItemsList.Count() = 1 AND SelectedItemsList[0] = "*";
			For Each SubordinateAttribute In SelectedItemsList Do
				Result.Add(Attribute.Name + "." + SubordinateAttribute);
			EndDo;
		Else
			SelectedAllAttributes = SelectedAllAttributes AND Attribute.Check;
			If Attribute.Check Then
				Result.Add(Attribute.Name);
			EndIf;
		EndIf;
	EndDo;
	
	If SelectedAllAttributes Then
		Result.Clear();
		Result.Add("*");
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Function SelectedAttributePresentation()
	Result = StrConcat(SelectedAttributeSynonyms(), ", ");
	If Result = "*" Then
		Result = NStr("ru = 'Все реквизиты'; en = 'All attributes'; pl = 'Wszystkie atrybuty';es_ES = 'Todos atributos';es_CO = 'Todos atributos';tr = 'Tüm özellikler';it = 'Tutti gli attributi';de = 'Alle Attribute'");
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function SelectedAttributeSynonyms()
	Result = New Array;
	
	AttributesCollection = FormAttributeToValue("ObjectAttributes");
	
	SelectedAttributes = AttributesCollection.Rows.FindRows(New Structure("Check", 1));
	If SelectedAttributes.Count() = AttributesCollection.Rows.Count() Then
		Result.Add(NStr("ru = 'Все'; en = 'All'; pl = 'Wszystkie';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutti';de = 'Alle'"));
		Return Result;
	EndIf;
	
	For Each Attribute In SelectedAttributes Do
		Result.Add(Attribute.Synonym);
	EndDo;
	
	SelectedAttributes = AttributesCollection.Rows.FindRows(New Structure("Check", 2));
	For Each Attribute In SelectedAttributes Do
		SubordinateAttributes = Attribute.Rows;
		For Each SubordinateAttribute In SubordinateAttributes Do
			If SubordinateAttribute.Check Then
				Result.Add(Attribute.Synonym + "." + SubordinateAttribute.Synonym);
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
EndFunction


// Selects linked check boxes.
&AtClient
Procedure OnChangeCheckBox(FormTree, CheckBoxName)
	
	CurrentData = FormTree.CurrentData;
	
	If CurrentData[CheckBoxName] = 2 Then
		CurrentData[CheckBoxName] = 0;
	EndIf;
	
	Mark = CurrentData[CheckBoxName];
	
	// Updating subordinate check boxes.
	For Each SubordinateAttribute In CurrentData.GetItems() Do
		SubordinateAttribute[CheckBoxName] = Mark;
	EndDo;
	
	// Updating a parent check box.
	Parent = CurrentData.GetParent();
	If Parent <> Undefined Then
		HasSelectedItems = False;
		SelectedAllItems = True;
		For Each Item In Parent.GetItems() Do
			HasSelectedItems = HasSelectedItems Or Item[CheckBoxName];
			SelectedAllItems = SelectedAllItems AND Item[CheckBoxName];
		EndDo;
		Parent[CheckBoxName] = HasSelectedItems + ?(HasSelectedItems, (Not SelectedAllItems), HasSelectedItems);
	EndIf;

EndProcedure

&AtClient
Procedure SetSelectionButtonAvailability()
	Items.ObjectAttributesSelect.Enabled = SelectedAttributes(ObjectAttributes.GetItems()).Count() > 0
EndProcedure

#EndRegion
