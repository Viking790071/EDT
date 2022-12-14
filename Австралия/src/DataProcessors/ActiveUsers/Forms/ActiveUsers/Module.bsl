#Region Variables

&AtClient
Var AdministrationParameters, PromptForIBAdministrationParameters;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Parameters.Property("NotifyOnClose", NotifyOnClose);
	
	InfobaseSessionNumber = InfoBaseSessionNumber();
	ConditionalAppearance.Items[0].Filter.Items[0].RightValue = InfobaseSessionNumber;
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		SessionWithoutSeparators = ModuleSaaS.SessionWithoutSeparators();
	Else
		SessionWithoutSeparators = True;
	EndIf;
	
	If Common.FileInfobase()
		Or Not ((Not SessionWithoutSeparators AND Users.IsFullUser())
		Or Users.IsFullUser(, True)) Then
		
		Items.TerminateSession.Visible = False;
		Items.TerminateSessionContext.Visible = False;
		
	EndIf;
	
	If Common.SeparatedDataUsageAvailable() Then
		Items.UserListDataSeparation.Visible = False;
	EndIf;
	
	SortColumnName = "WorkStart";
	SortDirection = "Asc";
	
	FillConnectionFilterSelectionList();
	If Parameters.Property("ApplicationNameFilter") Then
		If Items.ApplicationNameFilter.ChoiceList.FindByValue(Parameters.ApplicationNameFilter) <> Undefined Then
			ApplicationNameFilter = Parameters.ApplicationNameFilter;
		EndIf;
	EndIf;
	
	FillUserList();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	PromptForIBAdministrationParameters = True;
EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Exit Then
		Return;
	EndIf;
	If NotifyOnClose Then
		NotifyOnClose = False;
		NotifyChoice(Undefined);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ApplicationNameFilterOnChange(Item)
	FillList();
EndProcedure

#EndRegion

#Region EventHandlersOfUserListTableItems

&AtClient
Procedure UserListChoice(Item, RowSelected, Field, StandardProcessing)
	OpenUserFromList();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure TerminateSession(Command)
	
	SelectedLinesNumber = Items.UsersList.SelectedRows.Count();
	
	If SelectedLinesNumber = 0 Then
		ShowMessageBox(,NStr("ru = '???? ?????????????? ???????????????????????? ?????? ???????????????????? ??????????????.'; en = 'Users for ending sessions are not selected.'; pl = 'U??ytkownicy do zako??czenia sesji nie s?? wybrani.';es_ES = 'Usuarios para sesiones finales no se han seleccionado.';es_CO = 'Usuarios para sesiones finales no se han seleccionado.';tr = 'Oturumlar?? sonland??rmak i??in kullan??c??lar se??ilmez.';it = 'Nessun utente ?? selezionato per completare le sessioni.';de = 'Benutzer zum Beenden von Sitzungen sind nicht ausgew??hlt.'"));
		Return;
	ElsIf SelectedLinesNumber = 1 Then
		If Items.UsersList.CurrentData.Session = InfobaseSessionNumber Then
			ShowMessageBox(,NStr("ru = '???????????????????? ?????????????????? ?????????????? ??????????. ?????? ???????????? ???? ?????????????????? ?????????? ?????????????? ?????????????? ???????? ??????????????????.'; en = 'Cannot exit the current session. To exit the application, you can close its main window.'; pl = 'Nie mo??na zako??czy?? bie????cej sesji. Aby zamkn???? aplikacj??, zamknij g????wne okno aplikacji.';es_ES = 'Es imposible finalizar la sesi??n actual. Para salir de la aplicaci??n, cerrar la ventana principal de la aplicaci??n.';es_CO = 'Es imposible finalizar la sesi??n actual. Para salir de la aplicaci??n, cerrar la ventana principal de la aplicaci??n.';tr = 'Mevcut oturum kapat??lam??yor. Uygulamadan ????kmak i??in ana pencereyi kapat??n.';it = 'Impossibile uscire dalla sessione corrente. Per uscire dal programma ?? possibile chiudere la finestra principale.';de = 'Es ist unm??glich, die aktuelle Sitzung zu beenden. Schlie??en Sie das Hauptanwendungsfenster, um die Anwendung zu beenden.'"));
			Return;
		EndIf;
	EndIf;
	
	SessionNumbers = New Array;
	For Each RowID In Items.UsersList.SelectedRows Do
		SessionNumber = UsersList.FindByID(RowID).Session;
		If SessionNumber = InfobaseSessionNumber Then
			Continue;
		EndIf;
		SessionNumbers.Add(SessionNumber);
	EndDo;
	
	ClientRunParameters = StandardSubsystemsClient.ClientParametersOnStart();
	If ClientRunParameters.DataSeparationEnabled AND ClientRunParameters.SeparatedDataUsageAvailable Then
		
		StandardProcessing = True;
		NotificationAfterSessionTermination = New NotifyDescription(
			"AfterSessionTermination", ThisObject, New Structure("SessionNumbers", SessionNumbers));
		SaaSIntegrationClient.OnEndSession(ThisObject, SessionNumbers, StandardProcessing, NotificationAfterSessionTermination);
		
	Else
		If PromptForIBAdministrationParameters Then
			NotifyDescription = New NotifyDescription("TerminateSessionContinuation", ThisObject, SessionNumbers);
			FormHeader = NStr("ru = '???????????????????? ????????????'; en = 'Terminating session'; pl = 'Zako??czenie sesji';es_ES = 'Terminar la sesi??n';es_CO = 'Terminar la sesi??n';tr = 'Oturumu sonland??r';it = 'Chiusura sessione';de = 'Ende der Sitzung'");
			NoteLabel = NStr("ru = '?????? ???????????????????? ???????????? ???????????????????? ???????????? ??????????????????
				|?????????????????????????????????? ???????????????? ????????????????'; 
				|en = 'To sign out, enter parameters of
				|the server cluster administration'; 
				|pl = 'Aby zako??czy?? sesj??, nale??y wprowadzi?? ustawienia
				|administrowania klastrem serwera';
				|es_ES = 'Para finalizar la sesi??n, es necesario introducir los par??metros
				|de administraci??n del cl??ster del servidor';
				|es_CO = 'Para finalizar la sesi??n, es necesario introducir los par??metros
				|de administraci??n del cl??ster del servidor';
				|tr = 'Oturumu sonland??rmak i??in 
				|sunucu k??mesinin y??netim parametreleri girilmelidir';
				|it = 'Per disconnettersi, inserire i parametri
				|dell''amministrazione del cluster di server';
				|de = 'Um die Sitzung abzuschlie??en, m??ssen Sie die
				|Administrationsparameter des Server-Clusters eingeben'");
			IBConnectionsClient.ShowAdministrationParameters(NotifyDescription, False, True, AdministrationParameters, FormHeader, NoteLabel);
		Else
			TerminateSessionContinuation(AdministrationParameters, SessionNumbers);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshExecute()
	
	FillList();
	
EndProcedure

&AtClient
Procedure OpenEventLog()
	
	SelectedRows = Items.UsersList.SelectedRows;
	If SelectedRows.Count() = 0 Then
		ShowMessageBox(,NStr("ru = '???????????????? ?????????????????????????? ?????? ?????????????????? ?????????????? ??????????????????????.'; en = 'Select users to view the event log.'; pl = 'Wybierz u??ytkownik??w, aby wy??wietli?? dziennik wydarze??.';es_ES = 'Seleccionar los usuarios para ver el registro de eventos.';es_CO = 'Seleccionar los usuarios para ver el registro de eventos.';tr = 'Olay g??nl??????n?? g??r??nt??lemek i??in kullan??c??lar?? se??in.';it = 'Seleziona gli utenti per visualizzare il registro.';de = 'W??hlen Sie Benutzer aus, um das Ereignisprotokoll anzuzeigen.'"));
		Return;
	EndIf;
	
	FilterByUsers = New ValueList;
	For Each RowID In SelectedRows Do
		UserRow = UsersList.FindByID(RowID);
		Username = UserRow.UserName;
		If FilterByUsers.FindByValue(Username) = Undefined Then
			FilterByUsers.Add(UserRow.UserName, UserRow.UserName);
		EndIf;
	EndDo;
	
	OpenForm("DataProcessor.EventLog.Form", New Structure("User", FilterByUsers));
	
EndProcedure

&AtClient
Procedure SortAsc()
	
	SortByColumn("Asc");
	
EndProcedure

&AtClient
Procedure SortDesc()
	
	SortByColumn("Desc");
	
EndProcedure

&AtClient
Procedure OpenUser(Command)
	OpenUserFromList();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsersList.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("UsersList.Session");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Font", New Font(,, True));

EndProcedure

&AtClient
Procedure FillList()
	
	// Saving the current session data that will be used to restore the row position.
	CurrentSession = Undefined;
	CurrentData = Items.UsersList.CurrentData;
	
	If CurrentData <> Undefined Then
		CurrentSession = CurrentData.Session;
	EndIf;
	
	FillUserList();
	
	// Restoring the current row position based on the saved session data.
	If CurrentSession <> Undefined Then
		SearchStructure = New Structure;
		SearchStructure.Insert("Session", CurrentSession);
		FoundSessions = UsersList.FindRows(SearchStructure);
		If FoundSessions.Count() = 1 Then
			Items.UsersList.CurrentRow = FoundSessions[0].GetID();
			Items.UsersList.SelectedRows.Clear();
			Items.UsersList.SelectedRows.Add(Items.UsersList.CurrentRow);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SortByColumn(Direction)
	
	Column = Items.UsersList.CurrentItem;
	If Column = Undefined Then
		Return;
	EndIf;
	
	SortColumnName = Column.Name;
	SortDirection = Direction;
	
	FillList();
	
EndProcedure

&AtServer
Procedure FillConnectionFilterSelectionList()
	ApplicationNames = New Array;
	ApplicationNames.Add("1CV8");
	ApplicationNames.Add("1CV8C");
	ApplicationNames.Add("WebClient");
	ApplicationNames.Add("Designer");
	ApplicationNames.Add("COMConnection");
	ApplicationNames.Add("WSConnection");
	ApplicationNames.Add("BackgroundJob");
	ApplicationNames.Add("SystemBackgroundJob");
	ApplicationNames.Add("SrvrConsole");
	ApplicationNames.Add("COMConsole");
	ApplicationNames.Add("JobScheduler");
	ApplicationNames.Add("Debugger");
	ApplicationNames.Add("OpenIDProvider");
	ApplicationNames.Add("RAS");
	
	ChoiceList = Items.ApplicationNameFilter.ChoiceList;
	For Each ApplicationName In ApplicationNames Do
		ChoiceList.Add(ApplicationName, ApplicationPresentation(ApplicationName));
	EndDo;
EndProcedure

&AtServer
Procedure FillUserList()
	
	UsersList.Clear();
	
	If NOT Common.DataSeparationEnabled()
	 OR Common.SeparatedDataUsageAvailable() Then
		
		Users.FindAmbiguousIBUsers(Undefined);
	EndIf;
	
	InfobaseSessions = GetInfoBaseSessions();
	ActiveUserCount = InfobaseSessions.Count();
	
	FilterApplicationNames = ValueIsFilled(ApplicationNameFilter);
	If FilterApplicationNames Then
		ApplicationNames = StrSplit(ApplicationNameFilter, ",");
	EndIf;
	
	For Each IBSession In InfobaseSessions Do
		If FilterApplicationNames
			AND ApplicationNames.Find(IBSession.ApplicationName) = Undefined Then
			ActiveUserCount = ActiveUserCount - 1;
			Continue;
		EndIf;
		
		UserLine = UsersList.Add();
		
		UserLine.Application   = ApplicationPresentation(IBSession.ApplicationName);
		UserLine.WorkStart = IBSession.SessionStarted;
		UserLine.Computer    = IBSession.ComputerName;
		UserLine.Session        = IBSession.SessionNumber;
		UserLine.Connection   = IBSession.ConnectionNumber;
		
		If TypeOf(IBSession.User) = Type("InfoBaseUser")
		   AND ValueIsFilled(IBSession.User.Name) Then
			
			UserLine.User        = IBSession.User.Name;
			UserLine.UserName     = IBSession.User.Name;
			UserLine.UserRef  = FindRefByUserID(
				IBSession.User.UUID);
			
			If Common.DataSeparationEnabled() 
				AND Users.IsFullUser(, True) Then
				
				UserLine.DataSeparation = DataSeparationValuesToString(
					IBSession.User.DataSeparation);
			EndIf;
			
		ElsIf Common.DataSeparationEnabled()
		        AND Not Common.SeparatedDataUsageAvailable() Then
			
			UserLine.User       = Users.UnspecifiedUserFullName();
			UserLine.UserName    = "";
			UserLine.UserRef = Undefined;
		Else
			UnspecifiedProperties = UsersInternal.UnspecifiedUserProperties();
			UserLine.User       = UnspecifiedProperties.FullName;
			UserLine.UserName    = "";
			UserLine.UserRef = UnspecifiedProperties.Ref;
		EndIf;

		If IBSession.SessionNumber = InfobaseSessionNumber Then
			UserLine.UserPictureNumber = 0;
		Else
			UserLine.UserPictureNumber = 1;
		EndIf;
		
	EndDo;
	
	UsersList.Sort(SortColumnName + " " + SortDirection);
	
EndProcedure

&AtServer
Function DataSeparationValuesToString(DataSeparation)
	
	Result = "";
	Value = "";
	If DataSeparation.Property("DataArea", Value) Then
		Result = String(Value);
	EndIf;
	
	HasOtherSeparators = False;
	For each Separator In DataSeparation Do
		If Separator.Key = "DataArea" Then
			Continue;
		EndIf;
		If Not HasOtherSeparators Then
			If Not IsBlankString(Result) Then
				Result = Result + " ";
			EndIf;
			Result = Result + "(";
		EndIf;
		Result = Result + String(Separator.Value);
		HasOtherSeparators = True;
	EndDo;
	If HasOtherSeparators Then
		Result = Result + ")";
	EndIf;
	Return Result;
		
EndFunction

&AtServer
Function FindRefByUserID(ID)
	
	// Cannot access the separated catalog from a shared session.
	If Common.DataSeparationEnabled() 
		AND Not Common.SeparatedDataUsageAvailable() Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	
	QueryTextPattern = "SELECT
					|	Ref AS Ref
					|FROM
					|	%1
					|WHERE
					|	IBUserID = &ID";
					
	QueryByUsersText = StringFunctionsClientServer.SubstituteParametersToString(QueryTextPattern, Metadata.Catalogs.Users.FullName());
	
	ExternalUserQueryText = StringFunctionsClientServer.SubstituteParametersToString(QueryTextPattern, Metadata.Catalogs.ExternalUsers.FullName());
	
	Query.Text = QueryByUsersText;
	Query.Parameters.Insert("ID", ID);
	Result = Query.Execute();
	
	If NOT Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		Return Selection.Ref;
	EndIf;
	
	Query.Text = ExternalUserQueryText;
	Result = Query.Execute();
	
	If NOT Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		Return Selection.Ref;
	EndIf;
	
	Return Catalogs.Users.EmptyRef();
	
EndFunction

&AtClient
Procedure OpenUserFromList()
	
	CurrentData = Items.UsersList.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	User = CurrentData.UserRef;
	If ValueIsFilled(User) Then
		OpeningParameters = New Structure("Key", User);
		If TypeOf(User) = Type("CatalogRef.Users") Then
			OpenForm("Catalog.Users.Form.ItemForm", OpeningParameters);
		ElsIf TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
			OpenForm("Catalog.ExternalUsers.Form.ItemForm", OpeningParameters);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure TerminateSessionContinuation(Result, SessionsArray) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	AdministrationParameters = Result;
	
	SessionStructure = New Structure;
	SessionStructure.Insert("Property", "Number");
	SessionStructure.Insert("ComparisonType", ComparisonType.InList);
	SessionStructure.Insert("Value", SessionsArray);
	Filter = CommonClientServer.ValueInArray(SessionStructure);
	
	ClientConnectedOverWebServer = CommonClient.ClientConnectedOverWebServer();
	
	Try
		If ClientConnectedOverWebServer Then
			DeleteInfobaseSessionsAtServer(AdministrationParameters, Filter)
		Else
			ClusterAdministrationClientServer.DeleteInfobaseSessions(AdministrationParameters,, Filter);
		EndIf;
	Except
		PromptForIBAdministrationParameters = True;
		Raise;
	EndTry;
	
	PromptForIBAdministrationParameters = False;
	
	AfterSessionTermination(DialogReturnCode.OK, New Structure("SessionNumbers", SessionsArray));
	
EndProcedure

&AtClient
Procedure AfterSessionTermination(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		If AdditionalParameters.SessionNumbers.Count() > 1 Then
			
			NotificationText = NStr("ru = '???????????? %1 ??????????????????.'; en = 'Sessions %1 are ended.'; pl = 'Sesje %1 s?? zako??czone.';es_ES = 'Sesiones %1 se han finalizado.';es_CO = 'Sesiones %1 se han finalizado.';tr = 'Oturumlar %1 sonland??r??ld??.';it = 'Le sessioni %1 vengono terminate.';de = 'Sitzungen %1 sind beendet.'");
			SessionNumbers = StrConcat(AdditionalParameters.SessionNumbers, ",");
			NotificationText = StringFunctionsClientServer.SubstituteParametersToString(NotificationText, SessionNumbers);
			ShowUserNotification(NStr("ru = '???????????????????? ??????????????'; en = 'Terminating sessions'; pl = 'Zako??czenie sesji';es_ES = 'Finalizar las sesiones';es_CO = 'Finalizar las sesiones';tr = 'Oturumlar?? sonland??r';it = 'Terminando le sessioni';de = 'Sitzungen beenden'"),, NotificationText);
			
		Else
			
			NotificationText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '?????????? %1 ????????????????.'; en = 'Session %1 is terminated.'; pl = 'Sesja %1 zako??czona.';es_ES = 'Sesi??n %1 se ha finalizado.';es_CO = 'Sesi??n %1 se ha finalizado.';tr = 'Oturum %1 sonland??r??ld??.';it = 'La sessione %1 ?? terminata.';de = 'Sitzung %1 ist beendet.'"), AdditionalParameters.SessionNumbers[0]);
			ShowUserNotification(NStr("ru = '???????????????????? ????????????'; en = 'Terminating session'; pl = 'Zako??czenie sesji';es_ES = 'Terminar la sesi??n';es_CO = 'Terminar la sesi??n';tr = 'Oturumu sonland??r';it = 'Chiusura sessione';de = 'Ende der Sitzung'"),, NotificationText);
			
		EndIf;
		
		FillList();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteInfobaseSessionsAtServer(AdministrationParameters, Filter)
	
	ClusterAdministrationClientServer.DeleteInfobaseSessions(AdministrationParameters,, Filter);
	
EndProcedure

#EndRegion
