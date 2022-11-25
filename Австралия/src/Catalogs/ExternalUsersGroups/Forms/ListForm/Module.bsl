
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	SetAllExternalUsersGroupOrder(List);
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "SelectionPick");
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		
		// Excluding "All external users" group from the list of available parents.
		CommonClientServer.SetDynamicListFilterItem(
			List, "Ref", Catalogs.ExternalUsersGroups.AllExternalUsers,
			DataCompositionComparisonType.NotEqual, , Parameters.Property("SelectParent"));
		
		If Parameters.CloseOnChoice = False Then
			// Pick mode.
			Title = NStr("ru = 'Подбор групп внешних пользователей'; en = 'Select external user groups'; pl = 'Dobór grup użytkowników zewnętrznych';es_ES = 'Seleccionar los grupos de usuarios externos';es_CO = 'Seleccionar los grupos de usuarios externos';tr = 'Harici kullanıcı grupları seçin';it = 'Selezione gruppi di utenti esterni';de = 'Wählen Sie externe Benutzergruppen'");
			Items.List.MultipleChoice = True;
			Items.List.SelectionMode = TableSelectionMode.MultiRow;
		Else
			Title = NStr("ru = 'Подбор групп внешних пользователей'; en = 'Select external user groups'; pl = 'Dobór grup użytkowników zewnętrznych';es_ES = 'Seleccionar los grupos de usuarios externos';es_CO = 'Seleccionar los grupos de usuarios externos';tr = 'Harici kullanıcı grupları seçin';it = 'Selezione gruppi di utenti esterni';de = 'Wählen Sie externe Benutzergruppen'");
		EndIf;
	Else
		Items.List.ChoiceMode = False;
	EndIf;
	
	If Common.IsStandaloneWorkplace() Then
		ReadOnly = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListOnChange(Item)
	
	ListOnChangeAtServer();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetAllExternalUsersGroupOrder(List)
	
	Var Order;
	
	// Order.
	Order = List.SettingsComposer.Settings.Order;
	Order.UserSettingID = "DefaultOrder";
	
	Order.Items.Clear();
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Predefined");
	OrderItem.OrderType = DataCompositionSortDirection.Desc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Description");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
EndProcedure

&AtServerNoContext
Procedure ListOnChangeAtServer()
	
	UsersInternal.AfterChangeUserOrUserGroupInForm();
	
EndProcedure

#EndRegion
