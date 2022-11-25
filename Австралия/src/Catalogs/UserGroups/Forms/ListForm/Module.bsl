
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	SetAllUsersGroupOrder(List);
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "SelectionPick");
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		
		// Excluding "All external users" group from the list of available parents.
		CommonClientServer.SetDynamicListFilterItem(
			List, "Ref", Catalogs.UserGroups.AllUsers,
			DataCompositionComparisonType.NotEqual, , Parameters.Property("SelectParent"));
		
		If Parameters.CloseOnChoice = False Then
			// Pick mode.
			Title = NStr("ru = 'Подбор групп пользователей'; en = 'Select user groups'; pl = 'Wybór grup użytkowników';es_ES = 'Seleccionar los grupos de usuarios';es_CO = 'Seleccionar los grupos de usuarios';tr = 'Kullanıcı gruplarını seçin';it = 'Selezione gruppi utente';de = 'Wählen Sie Benutzergruppen'");
			Items.List.MultipleChoice = True;
			Items.List.SelectionMode = TableSelectionMode.MultiRow;
		Else
			Title = NStr("ru = 'Выбор группы пользователей'; en = 'Select user group'; pl = 'Wybór grupy użytkowników';es_ES = 'Seleccionar el grupo de usuarios';es_CO = 'Seleccionar el grupo de usuarios';tr = 'Kullanıcı grubunu seçin';it = 'Gruppo selezionare utente';de = 'Wählen Sie eine Benutzergruppe aus'");
		EndIf;
		
		AutoTitle = False;
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
Procedure SetAllUsersGroupOrder(List)
	
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
