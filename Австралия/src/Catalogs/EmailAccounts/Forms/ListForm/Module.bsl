
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Items.ShowPersonalUsersAccounts.Visible = Users.IsFullUser();
	SwitchPersonalAccountsVisibility(List, ShowPersonalUsersAccounts);
	SwitchInvalidAccountsVisibility(List, ShowInvalidAccounts);
	Items.AccountOwner.Visible = ShowPersonalUsersAccounts;
	Items.ShowInvalidAccounts.Enabled = ShowPersonalUsersAccounts;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowPersonalUsersAccountsOnChange(Item)
	SwitchPersonalAccountsVisibility(List, ShowPersonalUsersAccounts);
	Items.AccountOwner.Visible = ShowPersonalUsersAccounts;
	Items.ShowInvalidAccounts.Enabled = ShowPersonalUsersAccounts;
EndProcedure

&AtClient
Procedure ShowInvalidItemsOnChange(Item)
	SwitchInvalidAccountsVisibility(List, ShowInvalidAccounts);
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure SwitchPersonalAccountsVisibility(List, ShowPersonalUsersAccounts)
	UsersList = New Array;
	UsersList.Add(PredefinedValue("Catalog.Users.EmptyRef"));
	UsersList.Add(UsersClientServer.CurrentUser());
	CommonClientServer.SetDynamicListFilterItem(
		List, "AccountOwner", UsersList, DataCompositionComparisonType.InList, ,
			Not ShowPersonalUsersAccounts);
EndProcedure

&AtClientAtServerNoContext
Procedure SwitchInvalidAccountsVisibility(List, ShowInvalidItems)
	CommonClientServer.SetDynamicListFilterItem(
		List, "OwnerInvalid", False, DataCompositionComparisonType.Equal, ,
			Not ShowInvalidItems);
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	List.ConditionalAppearance.Items.Clear();
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("OwnerInvalid");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

#EndRegion