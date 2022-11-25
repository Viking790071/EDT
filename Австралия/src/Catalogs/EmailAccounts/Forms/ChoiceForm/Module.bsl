
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Items.ShowPersonalUsersAccounts.Visible = Users.IsFullUser();
	SwitchPersonalAccountsVisibility(List, ShowPersonalUsersAccounts);
	Items.AccountOwner.Visible = ShowPersonalUsersAccounts;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowPersonalUsersAccountsOnChange(Item)
	SwitchPersonalAccountsVisibility(List, ShowPersonalUsersAccounts);
	Items.AccountOwner.Visible = ShowPersonalUsersAccounts;
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
		
#EndRegion