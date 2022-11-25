
#Region EventHandlers

&AtClient
Procedure OnOpen(Cancel)
	
#If ThickClientOrdinaryApplication OR ThickClientManagedApplication Then
	DomainsAndUsersTable = OSUsers();
#ElsIf ThinClient Then
	DomainsAndUsersTable = New FixedArray (OSUsers());
#EndIf
	
	FillDomainList();
	
EndProcedure

#EndRegion

#Region DomainTableFormTableItemsEventHandlers

&AtClient
Procedure DomainTableOnActivateRow(Item)
	
	CurrentDomainUsersList.Clear();
	
	If Item.CurrentData <> Undefined Then
		DomainName = Item.CurrentData.DomainName;
		
		For Each Record In DomainsAndUsersTable Do
			If Record.DomainName = DomainName Then
				
				For Each User In Record.Users Do
					DomainUser = CurrentDomainUsersList.Add();
					DomainUser.UserName = User;
				EndDo;
				Break;
				
			EndIf;
		EndDo;
		
		CurrentDomainUsersList.Sort("UserName");
	EndIf;
	
EndProcedure

#EndRegion

#Region UserTableFormTableItemsEventHandlers

&AtClient
Procedure DomainUserTableChoice(Item, RowSelected, Field, StandardProcessing)
	
	ComposeResultAndCloseForm();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	
	If Items.DomainsTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("ru = 'Выберите домен.'; en = 'Select a domain.'; pl = 'Wybierz domenę.';es_ES = 'Seleccionar el dominio.';es_CO = 'Seleccionar el dominio.';tr = 'Alanı seçin.';it = 'Selezionare un dominio.';de = 'Wählen Sie die Domäne aus.'"));
		Return;
	EndIf;
	DomainName = Items.DomainsTable.CurrentData.DomainName;
	
	If Items.DomainUsersTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("ru = 'Выберите пользователя домена.'; en = 'Select a domain user.'; pl = 'Wybierz użytkownika domeny.';es_ES = 'Seleccionar el usuario del dominio.';es_CO = 'Seleccionar el usuario del dominio.';tr = 'Alan kullanıcısını seçin.';it = 'Selezionare un dominio utente.';de = 'Wählen Sie den Domänenbenutzer aus.'"));
		Return;
	EndIf;
	Username = Items.DomainUsersTable.CurrentData.UserName;
	
	ComposeResultAndCloseForm();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FillDomainList()
	
	DomainsList.Clear();
	
	For Each Record In DomainsAndUsersTable Do
		Domain = DomainsList.Add();
		Domain.DomainName = Record.DomainName;
	EndDo;
	
	DomainsList.Sort("DomainName");
	
EndProcedure

&AtClient
Procedure ComposeResultAndCloseForm()
	
	DomainName = Items.DomainsTable.CurrentData.DomainName;
	Username = Items.DomainUsersTable.CurrentData.UserName;
	
	SelectionResult = "\\" + DomainName + "\" + Username;
	NotifyChoice(SelectionResult);
	
EndProcedure

#EndRegion
