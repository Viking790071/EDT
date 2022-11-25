///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.SimpleRolesOnly Then
		CommonClientServer.SetDynamicListFilterItem(
			ListRoles, "UsedWithoutAddressingObjects", True,,True);
	EndIf;	
	If Parameters.NoExternalRoles = True Then
		CommonClientServer.SetDynamicListFilterItem(
			ListRoles, "ExternalRole", False);
	EndIf;	
	
	If TypeOf(Parameters.Performer) = Type("CatalogRef.Users") Then
		
		CurrentItem = Items.ListUsers;
		Items.ListUsers.CurrentRow = Parameters.Performer;
		
	ElsIf TypeOf(Parameters.Performer) = Type("CatalogRef.PerformerRoles") Then
		
		Items.Pages.CurrentPage = Items.Roles;
		CurrentItem = Items.ListRoles;
		Items.ListRoles.CurrentRow = Parameters.Performer;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.SelectPerformerRole") Then
		If TypeOf(SelectedValue) = Type("Structure") Then
			NotifyChoice(SelectedValue);
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlersRoles

&AtClient
Procedure SelectUserListValue(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	NotifyChoice(Value);
	
EndProcedure

&AtClient
Procedure SelectRolesListValue(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	SelectRole(Item.CurrentData);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	
	If Items.Pages.CurrentPage = Items.Users Then 
		NotifyChoice(Items.ListUsers.CurrentRow);
		
	ElsIf Items.Pages.CurrentPage = Items.Roles Then 
		SelectRole(Items.ListRoles.CurrentData);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SelectRole(CurrentData)
	
	If CurrentData.UsedByAddressingObjects Then 
		FormParameters = New Structure;
		FormParameters.Insert("PerformerRole",               CurrentData.Ref);
		FormParameters.Insert("MainAddressingObject",       Undefined);
		FormParameters.Insert("AdditionalAddressingObject", Undefined);
		FormParameters.Insert("SelectAddressingObject",         True);
		OpenForm("CommonForm.SelectPerformerRole", FormParameters, ThisObject);
	Else
		SelectedValue = New Structure("PerformerRole, MainAddressingObject, AdditionalAddressingObject", CurrentData.Ref, Undefined, Undefined);
		NotifyChoice(SelectedValue);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ListRoles.ConditionalAppearance.Items.Clear();
	Item = ListRoles.ConditionalAppearance.Items.Add();
	
	FilterItemsGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemsGroup .GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	ItemFilter = FilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("HasPerformers");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = FilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExternalRole");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.RoleWithoutPerformers);
	
EndProcedure


#EndRegion
