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
	
	SimpleRolesOnly = False;
	
	If Parameters.Property("SimpleRolesOnly", SimpleRolesOnly) AND SimpleRolesOnly = True Then
		CommonClientServer.SetDynamicListFilterItem(
			List, "ExternalRole", True, , , True);
	EndIf;
	
	IsExternalUser = UsersClientServer.IsExternalUserSession();
	
	If IsExternalUser Then
		
		CommonClientServer.SetFormItemProperty(Items.CommandBar.ChildItems, "FormChange",
			"Visible", False);
		FIlterRowInQueryText = SetFilterForExternalUser();
		
	Else
		
		FIlterRowInQueryText = " WHERE PerformerRolesAssignmentOverridable.UsersType = VALUE(Catalog.Users.EmptyRef)";
		
	EndIf;
	
	ListProperties = Common.DynamicListPropertiesStructure();
	ListProperties.MainTable              = "Catalog.PerformerRoles";
	ListProperties.DynamicDataRead = True;
	ListProperties.QueryText                 = List.QueryText + FIlterRowInQueryText;
	Common.SetDynamicListProperties(Items.List, ListProperties);
	
	NativeLanguagesSupportServer.ChangeListQueryTextForCurrentLanguage(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	
	If IsExternalUser Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function SetFilterForExternalUser()
	
	CurrentExternalUser =  ExternalUsers.CurrentExternalUser();
	
	FIlterRowInQueryText = StrReplace(" WHERE PerformerRolesAssignmentOverridable.UsersType = VALUE(Catalog.%Name%.EmptyRef)",
		"%Name%", CurrentExternalUser.AuthorizationObject.Metadata().Name);
	
	Return FIlterRowInQueryText;
	
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	List.ConditionalAppearance.Items.Clear();
	Item = List.ConditionalAppearance.Items.Add();
	
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