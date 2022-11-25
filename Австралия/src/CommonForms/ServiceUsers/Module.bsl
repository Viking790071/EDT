
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	RunMode = Constants.InfobaseUsageMode.Get();
	If RunMode = Enums.InfobaseUsageModes.Demo Then
		Raise(NStr("ru = 'В демонстрационном режиме не доступно добавление новых пользователей'; en = 'Adding users is not available in the demo mode.'; pl = 'Nowi użytkownicy nie mogą zostać dodani w trybie demonstracyjnym';es_ES = 'Nuevos usuarios no pueden añadirse en el modo demo';es_CO = 'Nuevos usuarios no pueden añadirse en el modo demo';tr = 'Demo modunda yeni kullanıcı eklenemez.';it = 'Non è possibile aggiungere utenti in modalità demo.';de = 'Neue Benutzer können im Demo-Modus nicht hinzugefügt werden'"));
	EndIf;
	
	// The form is not available until the preparation is finished.
	Enabled = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ServiceUserPassword = Undefined Then
		Cancel = True;
		StandardSubsystemsClient.SetFormStorage(ThisObject, True);
		AttachIdleHandler("RequestPasswordForAuthenticationInService", 0.1, True);
	Else
		PrepareForm();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SelectAll(Command)
	
	For each TableRow In ServiceUsers Do
		If TableRow.Access Then
			Continue;
		EndIf;
		TableRow.Add = True;
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearAll(Command)
	
	For each TableRow In ServiceUsers Do
		TableRow.Add = False;
	EndDo;
	
EndProcedure

&AtClient
Procedure AddSelectedUsers(Command)
	
	AddSelectedUsersAtServer();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersAdd.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ServiceUsers.Access");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Enabled", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersAdd.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersName.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersFullName.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ServiceUsersAccess.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ServiceUsers.Access");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("BackColor", StyleColors.InaccessibleCellTextColor);

EndProcedure

&AtClient
Procedure RequestPasswordForAuthenticationInService()
	
	StandardSubsystemsClient.SetFormStorage(ThisObject, False);
	
	UsersInternalClient.RequestPasswordForAuthenticationInService(
		New NotifyDescription("OnOpenFollowUp", ThisObject));
	
EndProcedure

&AtClient
Procedure OnOpenFollowUp(SaaSUserNewPassword, Context) Export
	
	If SaaSUserNewPassword <> Undefined Then
		ServiceUserPassword = SaaSUserNewPassword;
		Open();
	EndIf;
	
EndProcedure

&AtServer
Procedure PrepareForm()
	
	UsersInternalSaaS.GetActionsWithSaaSUser(
		Catalogs.Users.EmptyRef());
		
	UsersTable = UsersInternalSaaS.GetSaaSUsers(
		ServiceUserPassword);
		
	For each UserInformation In UsersTable Do
		UserRow = ServiceUsers.Add();
		FillPropertyValues(UserRow, UserInformation);
	EndDo;
	
	Enabled = True;
	
EndProcedure

&AtServer
Procedure AddSelectedUsersAtServer()
	
	SetPrivilegedMode(True);
	
	Counter = 0;
	StringsCount = ServiceUsers.Count();
	For Counter = 1 To StringsCount Do
		TableRow = ServiceUsers[StringsCount - Counter];
		If NOT TableRow.Add Then
			Continue;
		EndIf;
		
		UsersInternalSaaS.GrantSaaSUserAccess(
			TableRow.ID, ServiceUserPassword);
		
		ServiceUsers.Delete(TableRow);
	EndDo;
	
EndProcedure

#EndRegion
