
#Region Variables

#Region FormVariables

&AtClient
Var SettingMainAccountCompleted; // Flag of successful setting of main bank account from a form of company / counterparty

#EndRegion

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	If Parameters.Property("AutoTest") Then
		Return; // Return if the form for analysis is received..
	EndIf;
	
	Parameters.Filter.Property("Owner", AccountsOwner);
	
	If ValueIsFilled(AccountsOwner) Then
		// Context opening of the form with the selection by the counterparty / company
		
		AutoTitle = False;
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Bank accounts of %1'; ru = 'Банковские счета %1';pl = 'Rachunki bankowe %1';es_ES = 'Cuentas bancarias de %1';es_CO = 'Cuentas bancarias de %1';tr = '%1 banka hesapları';it = 'Conti corrente di %1';de = 'Bankkonten von %1'"),
			AccountsOwner);
		
		IsCounterparty = TypeOf(AccountsOwner) = Type("CatalogRef.Counterparties");
		
		Items.UseAsMain.Visible = AccessRight("Edit",
			?(IsCounterparty, Metadata.Catalogs.Counterparties, Metadata.Catalogs.Companies));
		
		List.Parameters.SetParameterValue("OwnerMainAccount",
			Common.ObjectAttributeValue(AccountsOwner, "BankAccountByDefault"));
			
	Else
		// Opening in general mode
	
		Items.Owner.Visible = True;
		Items.UseAsMain.Visible = AccessRight("Edit", Metadata.Catalogs.Counterparties)
			AND AccessRight("Edit", Metadata.Catalogs.Companies);
		
		List.Parameters.SetParameterValue("OwnerMainAccount", Undefined);
		
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SettingMainAccountCompleted" Then
		SettingMainAccountCompleted = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	If TypeOf(Items.List.CurrentRow) <> Type("DynamicListGroupRow")
		AND Items.List.CurrentData <> Undefined Then
		
		Items.UseAsMain.Enabled = Not Items.List.CurrentData.IsMainAccount;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure UseAsMain(Command)
	
	If TypeOf(Items.List.CurrentRow) = Type("DynamicListGroupRow")
		Or Items.List.CurrentData = Undefined
		Or Items.List.CurrentData.IsMainAccount Then
		
		Return;
	EndIf;
	
	NewMainAccount = Items.List.CurrentData.Ref;
	
	// If the form of counterparty / organization is opened, then change the main account in it
	SettingMainAccountCompleted = False;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Owner", Items.List.CurrentData.Owner);
	ParametersStructure.Insert("NewMainAccount", NewMainAccount);
	
	Notify("SettingMainAccount", ParametersStructure, ThisObject);
	
	// If the form of counterparty / organization is closed, then change the main account by ourselves
	If Not SettingMainAccountCompleted Then
		WriteMainAccount(ParametersStructure);
	EndIf;
	
	// Update dynamical list
	If ValueIsFilled(AccountsOwner) Then
		List.Parameters.SetParameterValue("OwnerMainAccount", NewMainAccount);
	Else
		Items.List.Refresh();
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Procedure WriteMainAccount(ParametersStructure)
	
	OwnerObject = ParametersStructure.Owner.GetObject();
	OwnerSuccesfullyLocked = True;
	
	Try
		OwnerObject.Lock();
	Except
		
		OwnerSuccesfullyLocked = False;
		
		MessageText = NStr("en = 'Cannot lock object for changing the main bank account.'; ru = 'Не удалось заблокировать объект для изменения основного банковского счета.';pl = 'Nie można zablokować obiektu w celu zmiany głównego konta bankowego.';es_ES = 'No se puede bloquear el objeto para cambiar la principal cuenta bancaria.';es_CO = 'No se puede bloquear el objeto para cambiar la principal cuenta bancaria.';tr = 'Ana banka hesabını değiştirmek için nesne kilitlenemiyor.';it = 'L''oggetto non può essere bloccato per cambiare il conto bancario principale.';de = 'Das Objekt zum Ändern des Hauptbankkontos kann nicht gesperrt werden.'", Metadata.DefaultLanguage.LanguageCode);
		WriteLogEvent(MessageText, EventLogLevel.Warning,, OwnerObject, ErrorDescription());
		
	EndTry;
	
	// If lockig was successful edit bank account by default of counterparty / company
	If OwnerSuccesfullyLocked Then
		OwnerObject.BankAccountByDefault = ParametersStructure.NewMainAccount;
		OwnerObject.Write();
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.SearchAndDeleteDuplicates

&AtClient
Procedure MergeSelected(Command)
	FindAndDeleteDuplicatesDuplicatesClient.MergeSelectedItems(Items.List);
EndProcedure

&AtClient
Procedure ShowUsage(Command)
	FindAndDeleteDuplicatesDuplicatesClient.ShowUsageInstances(Items.List);
EndProcedure

// End StandardSubsystems.SearchAndDeleteDuplicates

#EndRegion

